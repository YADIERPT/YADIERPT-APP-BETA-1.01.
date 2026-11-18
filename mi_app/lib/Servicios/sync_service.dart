import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../BaseDatos/base_datos.dart';
import 'servicio_supabase.dart';
import 'servicio_conectividad.dart';

/// Resultado detallado de una operación de subida (PUSH) por lotes.
class SyncPushResult {
  final bool exitoso;
  final int totalSubidos;
  final Map<String, int> subidosPorTabla;
  final String? error;

  const SyncPushResult({
    required this.exitoso,
    this.totalSubidos = 0,
    this.subidosPorTabla = const {},
    this.error,
  });

  @override
  String toString() =>
      'SyncPushResult(exitoso: $exitoso, totalSubidos: $totalSubidos, porTabla: $subidosPorTabla, error: $error)';
}

/// Configuración de sincronización por tabla.
class _TablaSyncConfig {
  final String nombreLocal;
  final String nombreRemoto;
  final String campoId;
  final Map<String, dynamic> Function(Map<String, dynamic> local)? transformador;

  const _TablaSyncConfig({
    required this.nombreLocal,
    required this.nombreRemoto,
    this.campoId = 'id',
    this.transformador,
  });
}

/// Servicio de sincronización (Fase 2: Push Batching).
///
/// Responsable de consultar los registros locales pendientes (`is_synced == 0`),
/// dividirlos en lotes (Batches) y enviarlos a Supabase mediante `upsert`.
/// Solo marca `is_synced = 1` en SQLite cuando la subida es confirmada exitosamente.
class SyncService {
  static final SyncService instancia = SyncService._();
  SyncService._();

  /// Tamaño predeterminado de cada lote HTTP para evitar sobrecargar la conexión
  static const int batchSizePredeterminado = 50;

  bool _sincronizando = false;
  bool get sincronizando => _sincronizando;

  /// Orden relacional estricto para inserciones (Push):
  /// 1. Empleados / Colaboradores (sin dependencias)
  /// 2. Productos (sin dependencias)
  /// 3. Ventas (depende de colaboradores)
  /// 4. Tickets / Artículos de Venta (depende de ventas y productos)
  static const List<_TablaSyncConfig> _tablasConfig = [
    _TablaSyncConfig(
      nombreLocal: 'colaboradores',
      nombreRemoto: 'colaboradores',
      campoId: 'id',
      transformador: _mapearColaboradorASupabase,
    ),
    _TablaSyncConfig(
      nombreLocal: 'productos',
      nombreRemoto: 'productos',
      campoId: 'id',
      transformador: _mapearProductoASupabase,
    ),
    _TablaSyncConfig(
      nombreLocal: 'ventas',
      nombreRemoto: 'ventas',
      campoId: 'id',
      transformador: _mapearVentaASupabase,
    ),
    _TablaSyncConfig(
      nombreLocal: 'articulos_venta',
      nombreRemoto: 'articulos_venta',
      campoId: 'uuid',
      transformador: _mapearArticuloVentaASupabase,
    ),
  ];

  /// Sube todos los cambios pendientes locales hacia Supabase en lotes controlados.
  ///
  /// Parámetros opcionales:
  /// - [clientOverride]: Inyección de cliente Supabase (para pruebas o sesiones específicas).
  /// - [upsertHandlerOverride]: Inyección opcional del despachador remoto para pruebas unitarias sin red.
  /// - [dbOverride]: Inyección de base de datos SQLite (para pruebas unitarias).
  /// - [batchSize]: Tamaño de lote personalizado (por defecto 50).
  Future<SyncPushResult> pushLocalChanges({
    SupabaseClient? clientOverride,
    Future<void> Function(String tabla, List<Map<String, dynamic>> registros)? upsertHandlerOverride,
    Database? dbOverride,
    int batchSize = batchSizePredeterminado,
  }) async {
    if (_sincronizando) {
      debugPrint('SyncService: Sincronización en curso omitida.');
      return const SyncPushResult(
        exitoso: false,
        error: 'Ya existe una sincronización en progreso.',
      );
    }

    _sincronizando = true;
    int totalSubidos = 0;
    final Map<String, int> subidosPorTabla = {};

    try {
      // 1. Validar cliente de Supabase (a menos que se use un mock de upsert en pruebas)
      SupabaseClient? client;
      if (upsertHandlerOverride == null) {
        client = clientOverride ??
            (ServicioSupabase.instancia.estaInicializado
                ? ServicioSupabase.instancia.client
                : (kIsWeb || Supabase.instance.isInitialized ? Supabase.instance.client : null));

        if (client == null) {
          debugPrint('SyncService: Supabase no está inicializado. Operando en modo local.');
          return const SyncPushResult(
            exitoso: true,
            totalSubidos: 0,
            error: 'Modo local activo (sin conexión a Supabase configurada).',
          );
        }

        // 2. Validar conectividad de red si no es un cliente inyectado para pruebas
        if (clientOverride == null) {
          final hayRed = await ServicioConectividad.instancia.tieneConexion();
          if (!hayRed) {
            debugPrint('SyncService: Sin conexión a internet. Se reintentará más tarde.');
            return const SyncPushResult(
              exitoso: false,
              totalSubidos: 0,
              error: 'Sin conexión a internet.',
            );
          }
        }
      }

      // 3. Conexión local a SQLite
      final db = dbOverride ?? (await BaseDeDatos.instancia.database);

      // 4. Procesar cada tabla respetando el orden relacional
      for (final config in _tablasConfig) {
        final tablaLocalReal = await _determinarTablaLocal(db, config.nombreLocal);
        if (tablaLocalReal == null) continue;

        // Consultar registros locales donde is_synced == 0
        final registrosPendientes = await db.query(
          tablaLocalReal,
          where: 'is_synced = ?',
          whereArgs: [0],
        );

        if (registrosPendientes.isEmpty) continue;

        debugPrint(
            'SyncService: Subiendo ${registrosPendientes.length} registros pendientes de $tablaLocalReal...');

        int subidosTabla = 0;

        // 5. Agrupar en lotes (Batches)
        for (var i = 0; i < registrosPendientes.length; i += batchSize) {
          final fin = (i + batchSize < registrosPendientes.length)
              ? i + batchSize
              : registrosPendientes.length;
          final lote = registrosPendientes.sublist(i, fin);

          final List<Map<String, dynamic>> lotePayloads = [];
          final List<dynamic> idsParaMarcar = [];

          for (final fila in lote) {
            final idValor = fila[config.campoId] ?? fila['id'] ?? fila['uuid'];
            if (idValor == null) continue;

            final payload = config.transformador != null
                ? config.transformador!(fila)
                : _limpiarPayloadGenerico(fila);

            lotePayloads.add(payload);
            idsParaMarcar.add(idValor);
          }

          if (lotePayloads.isEmpty) continue;

          try {
            // 6. Subir lote a Supabase mediante upsert
            if (upsertHandlerOverride != null) {
              await upsertHandlerOverride(config.nombreRemoto, lotePayloads);
            } else {
              await client!
                  .from(config.nombreRemoto)
                  .upsert(lotePayloads);
            }

            // 7. ¡CRÍTICO! Solo si Supabase responde exitosamente, marcar is_synced = 1 en SQLite
            await db.transaction((txn) async {
              for (final id in idsParaMarcar) {
                await txn.update(
                  tablaLocalReal,
                  {
                    'is_synced': 1,
                    'sync_estado': 'sincronizado',
                  },
                  where: '${config.campoId} = ?',
                  whereArgs: [id],
                );
              }
            });

            subidosTabla += lotePayloads.length;
            totalSubidos += lotePayloads.length;
            debugPrint(
                'SyncService: Lote de ${lotePayloads.length} registros en ${config.nombreRemoto} sincronizado con éxito.');
          } catch (e) {
            debugPrint(
                'SyncService: Error al subir lote de $tablaLocalReal a Supabase: $e');
            // Si falla la petición HTTP, NO actualizamos is_synced y permitimos reintento posterior
            return SyncPushResult(
              exitoso: false,
              totalSubidos: totalSubidos,
              subidosPorTabla: subidosPorTabla,
              error: 'Error al subir $tablaLocalReal: $e',
            );
          }
        }

        subidosPorTabla[tablaLocalReal] = subidosTabla;
      }

      debugPrint('SyncService: Push completado con éxito. Total registros subidos: $totalSubidos');
      return SyncPushResult(
        exitoso: true,
        totalSubidos: totalSubidos,
        subidosPorTabla: subidosPorTabla,
      );
    } catch (e) {
      debugPrint('SyncService: Fallo inesperado en pushLocalChanges: $e');
      return SyncPushResult(
        exitoso: false,
        totalSubidos: totalSubidos,
        subidosPorTabla: subidosPorTabla,
        error: e.toString(),
      );
    } finally {
      _sincronizando = false;
    }
  }

  /// Verifica si la tabla existe en la base de datos local (soporta alias comunes)
  Future<String?> _determinarTablaLocal(Database db, String tablaPreferida) async {
    final res = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tablaPreferida],
    );
    if (res.isNotEmpty) return tablaPreferida;

    // Alias defensivos: empleados -> colaboradores, tickets -> articulos_venta
    if (tablaPreferida == 'colaboradores') {
      final resEmp = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='empleados'",
      );
      if (resEmp.isNotEmpty) return 'empleados';
    } else if (tablaPreferida == 'articulos_venta') {
      final resTick = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='tickets'",
      );
      if (resTick.isNotEmpty) return 'tickets';
    }

    return null;
  }

  // ===========================================================================
  // Transformadores de Esquema Local (SQLite) -> Supabase (PostgreSQL)
  // ===========================================================================

  static Map<String, dynamic> _mapearProductoASupabase(Map<String, dynamic> local) {
    return {
      'uuid': local['uuid'] ?? local['id'],
      'codigo_local': local['id'],
      'nombre': local['nombre'],
      'tipo': local['tipo'] ?? 'planta',
      'notas_botanicas': local['notas'] ?? '',
      'precio_venta': local['precioVenta'],
      'costo': local['costo'],
      'stock': local['cantidadEnInventario'] ?? 0,
      'umbral_stock_critico': local['umbralStockCritico'] ?? 5,
      'activo': local['activo'] == 1 || local['activo'] == true,
      'imagen_url': local['imagenes'] != null && local['imagenes'].toString().isNotEmpty
          ? local['imagenes'].toString().split(',').first
          : null,
      'miniatura_url': local['imagenes'] != null &&
              local['imagenes'].toString().split(',').length > 1
          ? local['imagenes'].toString().split(',')[1]
          : (local['imagenes'] != null && local['imagenes'].toString().isNotEmpty
              ? local['imagenes'].toString().split(',').first
              : null),
      'updated_at': local['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': local['deleted_at'],
    };
  }

  static Map<String, dynamic> _mapearVentaASupabase(Map<String, dynamic> local) {
    final bool aplicarIva = local['aplicarIva'] == 1 || local['aplicarIva'] == true;
    final double pctIva = (local['porcentajeIva'] as num?)?.toDouble() ?? 0.16;
    return {
      'uuid': local['uuid'] ?? local['id'],
      'folio_local': local['id'],
      'colaborador_uuid': local['colaborador_uuid'],
      'fecha': local['fecha'],
      'estado': local['estado'],
      'forma_pago': 'Efectivo',
      'cliente': local['cliente'] ?? 'Cliente Mostrador',
      'porcentaje_iva': pctIva,
      'aplicar_iva': aplicarIva,
      'monto_pagado': local['montoPagado'] ?? 0.0,
      'notas': local['notas'] ?? '',
      'updated_at': local['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': local['deleted_at'],
    };
  }

  static Map<String, dynamic> _mapearArticuloVentaASupabase(Map<String, dynamic> local) {
    return {
      'uuid': local['uuid'] ?? local['id']?.toString(),
      'venta_uuid': local['venta_uuid'],
      'producto_uuid': local['producto_uuid'],
      'cantidad': local['cantidad'],
      'precio_unitario': local['precioUnitario'],
      'updated_at': local['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': local['deleted_at'],
    };
  }

  static Map<String, dynamic> _mapearColaboradorASupabase(Map<String, dynamic> local) {
    final String rolNorm = local['rol']?.toString().toLowerCase().contains('due') == true
        ? 'dueno'
        : 'empleado';
    return {
      'uuid': local['uuid'] ?? local['id'],
      'codigo_local': local['id'],
      'nombre': local['nombre'],
      'rol': rolNorm,
      'auth_user_id': local['auth_user_id'],
      'activo': local['activo'] == null || local['activo'] == 1,
      'updated_at': local['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': local['deleted_at'],
    };
  }

  static Map<String, dynamic> _limpiarPayloadGenerico(Map<String, dynamic> local) {
    final copia = Map<String, dynamic>.from(local);
    copia.remove('is_synced');
    copia.remove('sync_estado');
    return copia;
  }
}
