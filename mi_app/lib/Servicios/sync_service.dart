import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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

/// Resultado detallado de una operación de descarga (PULL) incremental.
class SyncPullResult {
  final bool exitoso;
  final int totalDescargados;
  final Map<String, int> descargadosPorTabla;
  final String? lastSyncTimestamp;
  final String? error;

  const SyncPullResult({
    required this.exitoso,
    this.totalDescargados = 0,
    this.descargadosPorTabla = const {},
    this.lastSyncTimestamp,
    this.error,
  });

  @override
  String toString() =>
      'SyncPullResult(exitoso: $exitoso, totalDescargados: $totalDescargados, porTabla: $descargadosPorTabla, cursor: $lastSyncTimestamp, error: $error)';
}

/// Configuración de sincronización por tabla.
class _TablaSyncConfig {
  final String nombreLocal;
  final String nombreRemoto;
  final String campoId;
  final Map<String, dynamic> Function(Map<String, dynamic> local)? transformadorPush;

  const _TablaSyncConfig({
    required this.nombreLocal,
    required this.nombreRemoto,
    this.campoId = 'id',
    this.transformadorPush,
  });
}

/// Servicio integral de sincronización Offline-First (Fase 2: Push Batching & Fase 3: Pull Incremental & Upsert).
class SyncService {
  static final SyncService instancia = SyncService._();
  SyncService._();

  /// Tamaño predeterminado de cada lote HTTP para evitar sobrecargar la conexión
  static const int batchSizePredeterminado = 50;

  bool _sincronizando = false;
  bool get sincronizando => _sincronizando;

  /// Orden relacional estricto para sincronización:
  /// 1. Empleados / Colaboradores (sin dependencias)
  /// 2. Productos (sin dependencias)
  /// 3. Ventas (depende de colaboradores)
  /// 4. Tickets / Artículos de Venta (depende de ventas y productos)
  static const List<_TablaSyncConfig> _tablasConfig = [
    _TablaSyncConfig(
      nombreLocal: 'colaboradores',
      nombreRemoto: 'colaboradores',
      campoId: 'id',
      transformadorPush: _mapearColaboradorASupabase,
    ),
    _TablaSyncConfig(
      nombreLocal: 'productos',
      nombreRemoto: 'productos',
      campoId: 'id',
      transformadorPush: _mapearProductoASupabase,
    ),
    _TablaSyncConfig(
      nombreLocal: 'ventas',
      nombreRemoto: 'ventas',
      campoId: 'id',
      transformadorPush: _mapearVentaASupabase,
    ),
    _TablaSyncConfig(
      nombreLocal: 'articulos_venta',
      nombreRemoto: 'articulos_venta',
      campoId: 'uuid',
      transformadorPush: _mapearArticuloVentaASupabase,
    ),
  ];

  // ===========================================================================
  // FASE 2: PUSH (Subida de cambios locales en lotes)
  // ===========================================================================

  /// Sube todos los cambios pendientes locales hacia Supabase en lotes controlados.
  ///
  /// Solo actualiza `is_synced = 1` si la respuesta de Supabase es exitosa.
  Future<SyncPushResult> pushLocalChanges({
    SupabaseClient? clientOverride,
    Future<void> Function(String tabla, List<Map<String, dynamic>> registros)? upsertHandlerOverride,
    Database? dbOverride,
    int batchSize = batchSizePredeterminado,
  }) async {
    if (_sincronizando) {
      debugPrint('SyncService [PUSH]: Sincronización en curso omitida.');
      return const SyncPushResult(
        exitoso: false,
        error: 'Ya existe una sincronización en progreso.',
      );
    }

    _sincronizando = true;
    int totalSubidos = 0;
    final Map<String, int> subidosPorTabla = {};

    try {
      // 1. Validar cliente de Supabase
      SupabaseClient? client;
      if (upsertHandlerOverride == null) {
        client = clientOverride ??
            (ServicioSupabase.instancia.estaInicializado
                ? ServicioSupabase.instancia.client
                : (kIsWeb || Supabase.instance.isInitialized ? Supabase.instance.client : null));

        if (client == null) {
          debugPrint('SyncService [PUSH]: Supabase no está inicializado. Operando en modo local.');
          return const SyncPushResult(
            exitoso: true,
            totalSubidos: 0,
            error: 'Modo local activo (sin conexión a Supabase configurada).',
          );
        }

        // 2. Validar conectividad de red
        if (clientOverride == null) {
          final hayRed = await ServicioConectividad.instancia.tieneConexion();
          if (!hayRed) {
            debugPrint('SyncService [PUSH]: Sin conexión a internet. Se reintentará más tarde.');
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
            'SyncService [PUSH]: Subiendo ${registrosPendientes.length} registros pendientes de $tablaLocalReal...');

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

            final payload = config.transformadorPush != null
                ? config.transformadorPush!(fila)
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
                'SyncService [PUSH]: Lote de ${lotePayloads.length} registros en ${config.nombreRemoto} sincronizado con éxito.');
          } catch (e) {
            debugPrint(
                'SyncService [PUSH]: Error al subir lote de $tablaLocalReal a Supabase: $e');
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

      debugPrint('SyncService [PUSH]: Push completado con éxito. Total registros subidos: $totalSubidos');
      return SyncPushResult(
        exitoso: true,
        totalSubidos: totalSubidos,
        subidosPorTabla: subidosPorTabla,
      );
    } catch (e) {
      debugPrint('SyncService [PUSH]: Fallo inesperado en pushLocalChanges: $e');
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

  // ===========================================================================
  // FASE 3: PULL (Descarga incremental y Upsert masivo)
  // ===========================================================================

  /// Descarga cambios desde la nube hacia SQLite aplicando las reglas:
  /// 1. Consulta el cursor local `last_sync_timestamp`.
  /// 2. Pide a Supabase únicamente registros con `updated_at > last_sync_timestamp`.
  /// 3. Ejecuta Upsert masivo en SQLite (`INSERT OR REPLACE`) evitando duplicados.
  /// 4. Asigna `is_synced = 1` a todos los registros descargados.
  /// 5. Actualiza `last_sync_timestamp` con la hora UTC actual tras completar con éxito.
  Future<SyncPullResult> pullCloudChanges({
    SupabaseClient? clientOverride,
    Future<List<Map<String, dynamic>>> Function(String tabla, String? lastSyncTimestamp)? pullHandlerOverride,
    Database? dbOverride,
  }) async {
    if (_sincronizando) {
      debugPrint('SyncService [PULL]: Sincronización en curso omitida.');
      return const SyncPullResult(
        exitoso: false,
        error: 'Ya existe una sincronización en progreso.',
      );
    }

    _sincronizando = true;
    int totalDescargados = 0;
    final Map<String, int> descargadosPorTabla = {};

    try {
      // 1. Validar cliente de Supabase
      SupabaseClient? client;
      if (pullHandlerOverride == null) {
        client = clientOverride ??
            (ServicioSupabase.instancia.estaInicializado
                ? ServicioSupabase.instancia.client
                : (kIsWeb || Supabase.instance.isInitialized ? Supabase.instance.client : null));

        if (client == null) {
          debugPrint('SyncService [PULL]: Supabase no está inicializado. Operando en modo local.');
          return const SyncPullResult(
            exitoso: true,
            totalDescargados: 0,
            error: 'Modo local activo (sin cliente Supabase configurado).',
          );
        }

        // 2. Validar conectividad de red
        if (clientOverride == null) {
          final hayRed = await ServicioConectividad.instancia.tieneConexion();
          if (!hayRed) {
            debugPrint('SyncService [PULL]: Sin conexión a internet disponible.');
            return const SyncPullResult(
              exitoso: false,
              totalDescargados: 0,
              error: 'Sin conexión a internet.',
            );
          }
        }
      }

      // 3. Conexión a SQLite y lectura del cursor local last_sync_timestamp
      final db = dbOverride ?? (await BaseDeDatos.instancia.database);
      final String? lastSyncTimestamp = await obtenerLastSyncTimestamp(db: db);
      debugPrint('SyncService [PULL]: Iniciando descarga incremental con cursor: $lastSyncTimestamp');

      // 4. Procesar cada tabla respetando el orden relacional
      for (final config in _tablasConfig) {
        final tablaLocalReal = await _determinarTablaLocal(db, config.nombreLocal);
        if (tablaLocalReal == null) continue;

        // 5. Consultar registros remotos donde updated_at > last_sync_timestamp
        final List<Map<String, dynamic>> registrosRemotos;
        if (pullHandlerOverride != null) {
          registrosRemotos = await pullHandlerOverride(config.nombreRemoto, lastSyncTimestamp);
        } else {
          var query = client!.from(config.nombreRemoto).select();
          if (lastSyncTimestamp != null && lastSyncTimestamp.isNotEmpty) {
            query = query.gt('updated_at', lastSyncTimestamp);
          }
          final respuesta = await query.order('updated_at', ascending: true);
          registrosRemotos = List<Map<String, dynamic>>.from(respuesta);
        }

        if (registrosRemotos.isEmpty) {
          descargadosPorTabla[tablaLocalReal] = 0;
          continue;
        }

        debugPrint(
            'SyncService [PULL]: Descargando ${registrosRemotos.length} registros remotos para $tablaLocalReal...');

        // 6. ¡CRÍTICO - Cero Duplicados!: Upsert masivo mediante INSERT OR REPLACE en una sola transacción
        int insertadosTabla = 0;
        await db.transaction((txn) async {
          final batch = txn.batch();

          for (final remoto in registrosRemotos) {
            final filaLocal = await _mapearSupabaseALocal(
              tabla: tablaLocalReal,
              remoto: remoto,
              txn: txn,
            );

            // Regla obligatoria: Todo dato confirmado desde la nube se marca con is_synced = 1
            filaLocal['is_synced'] = 1;
            filaLocal['sync_estado'] = 'sincronizado';

            // Ejecuta en SQLite: INSERT OR REPLACE INTO <tabla> (...) VALUES (...)
            batch.insert(
              tablaLocalReal,
              filaLocal,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            insertadosTabla++;
          }

          // Ejecutar en lote optimizado dentro del motor SQLite C
          await batch.commit(noResult: true);
        });

        descargadosPorTabla[tablaLocalReal] = insertadosTabla;
        totalDescargados += insertadosTabla;
        debugPrint(
            'SyncService [PULL]: $insertadosTabla registros integrados en $tablaLocalReal sin duplicados.');
      }

      // 7. Al terminar con éxito todas las tablas, actualizar last_sync_timestamp con la hora UTC actual
      final nuevoTimestamp = DateTime.now().toUtc().toIso8601String();
      await actualizarLastSyncTimestamp(nuevoTimestamp, db: db);
      debugPrint('SyncService [PULL]: Descarga completada exitosamente. Nuevo cursor: $nuevoTimestamp');

      return SyncPullResult(
        exitoso: true,
        totalDescargados: totalDescargados,
        descargadosPorTabla: descargadosPorTabla,
        lastSyncTimestamp: nuevoTimestamp,
      );
    } catch (e) {
      debugPrint('SyncService [PULL]: Error durante la descarga: $e');
      return SyncPullResult(
        exitoso: false,
        totalDescargados: totalDescargados,
        descargadosPorTabla: descargadosPorTabla,
        error: e.toString(),
      );
    } finally {
      _sincronizando = false;
    }
  }

  // ===========================================================================
  // Control de Cursor de Sincronización (last_sync_timestamp)
  // ===========================================================================

  /// Lee el timestamp del último PULL exitoso desde SQLite (`config_sync`)
  Future<String?> obtenerLastSyncTimestamp({Database? db}) async {
    try {
      final database = db ?? (await BaseDeDatos.instancia.database);
      await _asegurarColumnaLastSyncTimestamp(database);
      final res = await database.query('config_sync', where: 'id = 1');
      if (res.isNotEmpty) {
        return res.first['last_sync_timestamp']?.toString() ??
            res.first['ultima_sync_exitosa']?.toString();
      }
    } catch (e) {
      debugPrint('SyncService: Error al leer last_sync_timestamp: $e');
    }
    return null;
  }

  /// Actualiza atómicamente el `last_sync_timestamp` tras una descarga exitosa
  Future<void> actualizarLastSyncTimestamp(String timestamp, {Database? db}) async {
    try {
      final database = db ?? (await BaseDeDatos.instancia.database);
      await _asegurarColumnaLastSyncTimestamp(database);
      await database.update(
        'config_sync',
        {
          'last_sync_timestamp': timestamp,
          'ultima_sync_exitosa': timestamp,
        },
        where: 'id = 1',
      );
    } catch (e) {
      debugPrint('SyncService: Error al actualizar last_sync_timestamp: $e');
    }
  }

  static Future<void> _asegurarColumnaLastSyncTimestamp(Database db) async {
    try {
      await db.execute('ALTER TABLE config_sync ADD COLUMN last_sync_timestamp TEXT');
    } catch (_) {
      // La columna ya existe
    }
  }

  /// Verifica si la tabla existe en la base de datos local (soporta alias defensivos)
  Future<String?> _determinarTablaLocal(Database db, String tablaPreferida) async {
    final res = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tablaPreferida],
    );
    if (res.isNotEmpty) return tablaPreferida;

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
  // Mapeadores Supabase (PostgreSQL) -> SQLite Local (PULL)
  // ===========================================================================

  static Future<Map<String, dynamic>> _mapearSupabaseALocal({
    required String tabla,
    required Map<String, dynamic> remoto,
    required DatabaseExecutor txn,
  }) async {
    switch (tabla) {
      case 'productos':
        return _mapearSupabaseAProductoLocal(remoto, txn);
      case 'ventas':
        return _mapearSupabaseAVentaLocal(remoto, txn);
      case 'articulos_venta':
      case 'tickets':
        return _mapearSupabaseAArticuloVentaLocal(remoto, txn);
      case 'colaboradores':
      case 'empleados':
        return _mapearSupabaseAColaboradorLocal(remoto, txn);
      default:
        final copia = Map<String, dynamic>.from(remoto);
        copia['is_synced'] = 1;
        copia['sync_estado'] = 'sincronizado';
        return copia;
    }
  }

  static Future<Map<String, dynamic>> _mapearSupabaseAProductoLocal(
    Map<String, dynamic> remoto,
    DatabaseExecutor txn,
  ) async {
    final String uuid = remoto['uuid']?.toString() ?? remoto['id']?.toString() ?? const Uuid().v4();
    String idLocal = remoto['codigo_local']?.toString() ?? remoto['id']?.toString() ?? uuid;

    // Preservar la clave primaria local id si el producto ya existía con este UUID
    final existente = await txn.query(
      'productos',
      columns: ['id'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (existente.isNotEmpty) {
      idLocal = existente.first['id'].toString();
    }

    final String imgUrl = remoto['imagen_url']?.toString() ?? '';
    final String thumbUrl = remoto['miniatura_url']?.toString() ?? '';
    String imagenesStr = '';
    if (imgUrl.isNotEmpty && thumbUrl.isNotEmpty && imgUrl != thumbUrl) {
      imagenesStr = '$imgUrl,$thumbUrl';
    } else if (imgUrl.isNotEmpty) {
      imagenesStr = imgUrl;
    } else if (thumbUrl.isNotEmpty) {
      imagenesStr = thumbUrl;
    }

    return {
      'id': idLocal,
      'uuid': uuid,
      'nombre': remoto['nombre']?.toString() ?? '',
      'notas': remoto['notas_botanicas']?.toString() ?? remoto['notas']?.toString() ?? '',
      'precioVenta': (remoto['precio_venta'] ?? remoto['precioVenta'] as num?)?.toDouble() ?? 0.0,
      'costo': (remoto['costo'] as num?)?.toDouble() ?? 0.0,
      'cantidadEnInventario': (remoto['stock'] ?? remoto['cantidadEnInventario'] as num?)?.toInt() ?? 0,
      'umbralStockCritico': (remoto['umbral_stock_critico'] ?? remoto['umbralStockCritico'] as num?)?.toInt() ?? 5,
      'tipo': remoto['tipo']?.toString() ?? 'planta',
      'imagenes': imagenesStr,
      'activo': (remoto['activo'] == true || remoto['activo'] == 1) && remoto['deleted_at'] == null ? 1 : 0,
      'is_synced': 1,
      'sync_estado': 'sincronizado',
      'updated_at': remoto['updated_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': remoto['deleted_at']?.toString(),
    };
  }

  static Future<Map<String, dynamic>> _mapearSupabaseAVentaLocal(
    Map<String, dynamic> remoto,
    DatabaseExecutor txn,
  ) async {
    final String uuid = remoto['uuid']?.toString() ?? remoto['id']?.toString() ?? const Uuid().v4();
    String idLocal = remoto['folio_local']?.toString() ?? remoto['id']?.toString() ?? uuid;

    final existente = await txn.query(
      'ventas',
      columns: ['id'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (existente.isNotEmpty) {
      idLocal = existente.first['id'].toString();
    }

    return {
      'id': idLocal,
      'uuid': uuid,
      'colaborador_uuid': remoto['colaborador_uuid']?.toString(),
      'fecha': remoto['fecha']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      'estado': remoto['estado']?.toString() ?? 'completada',
      'porcentajeIva': (remoto['porcentaje_iva'] as num?)?.toDouble() ?? 0.16,
      'aplicarIva': (remoto['aplicar_iva'] == true || remoto['aplicar_iva'] == 1) ? 1 : 0,
      'cliente': remoto['cliente']?.toString() ?? 'Cliente Mostrador',
      'montoPagado': (remoto['monto_pagado'] as num?)?.toDouble() ?? 0.0,
      'notas': remoto['notas']?.toString() ?? '',
      'is_synced': 1,
      'sync_estado': 'sincronizado',
      'updated_at': remoto['updated_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': remoto['deleted_at']?.toString(),
    };
  }

  static Future<Map<String, dynamic>> _mapearSupabaseAArticuloVentaLocal(
    Map<String, dynamic> remoto,
    DatabaseExecutor txn,
  ) async {
    final String uuid = remoto['uuid']?.toString() ?? const Uuid().v4();

    // Resolver venta_id local si no viene explícito
    String ventaId = remoto['venta_id']?.toString() ?? '';
    if (ventaId.isEmpty && remoto['venta_uuid'] != null) {
      final v = await txn.query('ventas', columns: ['id'], where: 'uuid = ?', whereArgs: [remoto['venta_uuid']]);
      ventaId = v.isNotEmpty ? v.first['id'].toString() : remoto['venta_uuid'].toString();
    }

    // Resolver producto_id local si no viene explícito
    String productoId = remoto['producto_id']?.toString() ?? '';
    if (productoId.isEmpty && remoto['producto_uuid'] != null) {
      final p = await txn.query('productos', columns: ['id'], where: 'uuid = ?', whereArgs: [remoto['producto_uuid']]);
      productoId = p.isNotEmpty ? p.first['id'].toString() : remoto['producto_uuid'].toString();
    }

    final mapa = <String, dynamic>{
      'uuid': uuid,
      'venta_id': ventaId,
      'venta_uuid': remoto['venta_uuid']?.toString(),
      'producto_id': productoId,
      'producto_uuid': remoto['producto_uuid']?.toString(),
      'cantidad': (remoto['cantidad'] as num?)?.toInt() ?? 1,
      'precioUnitario': (remoto['precio_unitario'] ?? remoto['precioUnitario'] as num?)?.toDouble() ?? 0.0,
      'is_synced': 1,
      'sync_estado': 'sincronizado',
      'updated_at': remoto['updated_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': remoto['deleted_at']?.toString(),
    };

    // Preservar autoincrement ID existente para INSERT OR REPLACE
    final existente = await txn.query('articulos_venta', columns: ['id'], where: 'uuid = ?', whereArgs: [uuid], limit: 1);
    if (existente.isNotEmpty) {
      mapa['id'] = existente.first['id'];
    }

    return mapa;
  }

  static Future<Map<String, dynamic>> _mapearSupabaseAColaboradorLocal(
    Map<String, dynamic> remoto,
    DatabaseExecutor txn,
  ) async {
    final String uuid = remoto['uuid']?.toString() ?? remoto['id']?.toString() ?? const Uuid().v4();
    String idLocal = remoto['codigo_local']?.toString() ?? remoto['id']?.toString() ?? uuid;
    String clave = remoto['clave']?.toString() ?? '';

    final existente = await txn.query(
      'colaboradores',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (existente.isNotEmpty) {
      idLocal = existente.first['id'].toString();
      if (clave.isEmpty) {
        clave = existente.first['clave']?.toString() ?? '';
      }
    }

    final rolNorm = (remoto['rol']?.toString().toLowerCase().contains('due') == true)
        ? 'Dueño'
        : 'Empleado';

    return {
      'id': idLocal,
      'uuid': uuid,
      'nombre': remoto['nombre']?.toString() ?? '',
      'clave': clave,
      'rol': rolNorm,
      'auth_user_id': remoto['auth_user_id']?.toString(),
      'email': remoto['email']?.toString(),
      'is_synced': 1,
      'sync_estado': 'sincronizado',
      'updated_at': remoto['updated_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': remoto['deleted_at']?.toString(),
    };
  }

  // ===========================================================================
  // Mapeadores Locales (SQLite) -> Supabase (PUSH)
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
