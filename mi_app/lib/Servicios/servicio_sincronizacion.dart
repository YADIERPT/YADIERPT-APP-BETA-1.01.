import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../BaseDatos/base_datos.dart';
import '../Constantes/limites.dart';
import 'servicio_supabase.dart';
import 'servicio_conectividad.dart';

/// Contrato para interactuar con la fuente remota de sincronización (Supabase u origen simulado).
abstract class FuenteRemotaSincronizacion {
  Future<void> upsertLote(String tabla, List<Map<String, dynamic>> registros);
  Future<List<Map<String, dynamic>>> consultarModificados({
    required String tabla,
    required String campoCursor,
    required String ultimoCursor,
    int limite = 100,
  });
}

/// Implementación oficial de la fuente remota basada en el cliente oficial de Supabase.
class FuenteRemotaSupabase implements FuenteRemotaSincronizacion {
  final SupabaseClient client;
  FuenteRemotaSupabase(this.client);

  @override
  Future<void> upsertLote(String tabla, List<Map<String, dynamic>> registros) async {
    await client.from(tabla).upsert(registros, onConflict: 'uuid');
  }

  @override
  Future<List<Map<String, dynamic>>> consultarModificados({
    required String tabla,
    required String campoCursor,
    required String ultimoCursor,
    int limite = 100,
  }) async {
    final res = await client
        .from(tabla)
        .select()
        .gt(campoCursor, ultimoCursor)
        .order(campoCursor, ascending: true)
        .limit(limite);
    return List<Map<String, dynamic>>.from(res);
  }
}

/// Resultado detallado de un ciclo de sincronización.
class ResultadoSincronizacion {
  final bool exitoso;
  final int registrosSubidos;
  final int registrosDescargados;
  final String? error;

  ResultadoSincronizacion({
    required this.exitoso,
    this.registrosSubidos = 0,
    this.registrosDescargados = 0,
    this.error,
  });

  @override
  String toString() =>
      'ResultadoSincronizacion(exitoso: $exitoso, subidos: $registrosSubidos, bajados: $registrosDescargados, error: $error)';
}

/// Motor de sincronización bidireccional (PUSH / PULL incremental) entre SQLite local y Supabase.
///
/// Arquitectura:
/// - Cada terminal siempre lee y escribe en su SQLite local con SQLCipher.
/// - PUSH: Despacha la cola de salida (Outbox) a Supabase por lotes respetando el orden relacional.
/// - PULL: Consulta de forma incremental mediante cursores `updated_at` y `created_at`.
/// - Idempotente: Las mutaciones se aplican con upsert por `uuid`.
/// - Append-Only: Ventas, abonos y movimientos de inventario convergen sin sobrescribir totales.
class ServicioSincronizacion {
  static final ServicioSincronizacion instancia = ServicioSincronizacion._();
  ServicioSincronizacion._();

  bool _enProceso = false;
  bool get enProceso => _enProceso;

  /// Orden estricto de dependencias relacionales para inserciones y subidas (PUSH)
  static const List<String> ordenTablas = [
    'colaboradores',
    'productos',
    'ventas',
    'articulos_venta',
    'deudores',
    'abonos_venta',
    'movimientos_inventario',
  ];

  /// Ejecuta un ciclo completo de sincronización (PUSH seguido de PULL).
  Future<ResultadoSincronizacion> sincronizar({
    SupabaseClient? clientOverride,
    FuenteRemotaSincronizacion? fuenteRemotaOverride,
    Database? dbOverride,
  }) async {
    if (_enProceso) {
      return ResultadoSincronizacion(
        exitoso: false,
        error: 'Sincronización en curso omitida.',
      );
    }

    final FuenteRemotaSincronizacion fuenteRemota;
    if (fuenteRemotaOverride != null) {
      fuenteRemota = fuenteRemotaOverride;
    } else {
      final client = clientOverride ?? ServicioSupabase.instancia.client;
      if (client == null) {
        return ResultadoSincronizacion(
          exitoso: true,
          error: 'Modo local puro activo. Sin servidor remoto configurado.',
        );
      }
      fuenteRemota = FuenteRemotaSupabase(client);
    }

    // Verificar conectividad a nivel de red si no estamos usando un mock inyectado
    if (clientOverride == null && fuenteRemotaOverride == null) {
      final hayRed = await ServicioConectividad.instancia.tieneConexion();
      if (!hayRed) {
        return ResultadoSincronizacion(
          exitoso: false,
          error: 'Sin conexión a internet disponible.',
        );
      }
    }

    _enProceso = true;
    int totalSubidos = 0;
    int totalDescargados = 0;

    try {
      final db = dbOverride ?? (await BaseDeDatos.instancia.database);
      final dispositivoId = await _obtenerDispositivoId(db);

      // 1. Fase PUSH: Vaciar cola de salida (Outbox) hacia Supabase
      final resPush = await _ejecutarPush(fuenteRemota, db, dispositivoId);
      totalSubidos = resPush.subidos;

      if (resPush.primerError != null) {
        return ResultadoSincronizacion(
          exitoso: false,
          registrosSubidos: totalSubidos,
          registrosDescargados: 0,
          error: resPush.primerError,
        );
      }

      // 2. Fase PULL: Descargar mutaciones remotas e integrar en SQLite local
      totalDescargados = await _ejecutarPull(fuenteRemota, db, dispositivoId);

      // 3. Registrar éxito y timestamp en config_sync
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await db.update(
        'config_sync',
        {'ultima_sync_exitosa': nowIso},
        where: 'id = 1',
      );

      return ResultadoSincronizacion(
        exitoso: true,
        registrosSubidos: totalSubidos,
        registrosDescargados: totalDescargados,
      );
    } catch (e) {
      debugPrint('Error durante la sincronización: $e');
      return ResultadoSincronizacion(
        exitoso: false,
        registrosSubidos: totalSubidos,
        registrosDescargados: totalDescargados,
        error: e.toString(),
      );
    } finally {
      _enProceso = false;
    }
  }

  // ===========================================================================
  // PUSH: Subida de Cambios Locales a Supabase
  // ===========================================================================

  Future<({int subidos, String? primerError})> _ejecutarPush(
    FuenteRemotaSincronizacion fuenteRemota,
    Database db,
    String dispositivoId,
  ) async {
    int subidos = 0;
    String? primerError;

    // A. Reconciliación preventiva: Si hay filas con sync_estado = 'pendiente'
    // que no estén en cola_sincronizacion, las insertamos en la cola para asegurar cobertura total.
    await _reconciliarFilasPendientesHaciaCola(db, dispositivoId);

    // B. Leer la cola de cambios ordenada cronológicamente
    final elementosCola = await db.query(
      'cola_sincronizacion',
      orderBy: 'created_at ASC',
      limit: 200,
    );

    if (elementosCola.isEmpty) {
      return (subidos: 0, primerError: null);
    }

    // Agrupar los elementos por tabla respetando el orden relacional
    final Map<String, List<Map<String, dynamic>>> porTabla = {};
    for (final elem in elementosCola) {
      final tabla = elem['tabla']?.toString() ?? '';
      if (!porTabla.containsKey(tabla)) {
        porTabla[tabla] = [];
      }
      porTabla[tabla]!.add(elem);
    }

    // Procesar cada tabla según el orden estricto de dependencias
    for (final tabla in ordenTablas) {
      final lista = porTabla[tabla];
      if (lista == null || lista.isEmpty) continue;

      for (var i = 0; i < lista.length; i += 50) {
        final end = (i + 50 < lista.length) ? i + 50 : lista.length;
        final loteCola = lista.sublist(i, end);

        final List<Map<String, dynamic>> payloadsParaSupabase = [];
        final List<int> idsColaExitosos = [];
        final List<String> uuidsExitosos = [];

        for (final item in loteCola) {
          final int idCola = (item['id'] as num).toInt();
          final String registroUuid = item['registro_uuid'].toString();
          try {
            Map<String, dynamic> payload = jsonDecode(item['payload_json'].toString());
            // Si el payload guardado en cola estaba vacío, lo reconstruimos desde la tabla local
            if (payload.isEmpty) {
              final local = await db.query(
                tabla,
                where: 'uuid = ?',
                whereArgs: [registroUuid],
              );
              if (local.isNotEmpty) {
                payload = _mapearFilaLocalASupabase(tabla, local.first, dispositivoId);
              }
            } else {
              payload = _mapearPayloadASupabase(tabla, payload, dispositivoId);
            }

            if (payload.isNotEmpty) {
              payloadsParaSupabase.add(payload);
              idsColaExitosos.add(idCola);
              uuidsExitosos.add(registroUuid);
            }
          } catch (e) {
            // Error de serialización, registrar en la cola
            await db.rawUpdate('''
              UPDATE cola_sincronizacion
              SET intentos = intentos + 1, ultimo_error = ?
              WHERE id = ?
            ''', [e.toString(), idCola]);
          }
        }

        if (payloadsParaSupabase.isNotEmpty) {
          try {
            // Envío idempotente con UPSERT por uuid
            await fuenteRemota.upsertLote(
              tabla,
              payloadsParaSupabase,
            );

            // Eliminar de la cola y marcar como sincronizado en la base local
            await db.transaction((txn) async {
              for (final idCola in idsColaExitosos) {
                await txn.delete('cola_sincronizacion', where: 'id = ?', whereArgs: [idCola]);
              }
              for (final u in uuidsExitosos) {
                await txn.update(
                  tabla,
                  {'sync_estado': 'sincronizado'},
                  where: 'uuid = ?',
                  whereArgs: [u],
                );
              }
            });

            subidos += payloadsParaSupabase.length;
          } catch (e) {
            primerError ??= e.toString();
            debugPrint('Fallo al subir lote a $tabla en Supabase: $e');
            // Incrementar intentos y guardar error en cada elemento del lote
            for (final idCola in idsColaExitosos) {
              await db.rawUpdate('''
                UPDATE cola_sincronizacion
                SET intentos = intentos + 1, ultimo_error = ?
                WHERE id = ?
              ''', [e.toString(), idCola]);
            }
          }
        }
      }
    }

    return (subidos: subidos, primerError: primerError);
  }

  // ===========================================================================
  // PULL: Descarga Incremental desde Supabase e Inserción en SQLite
  // ===========================================================================

  Future<int> _ejecutarPull(
    FuenteRemotaSincronizacion fuenteRemota,
    Database db,
    String dispositivoId,
  ) async {
    int descargados = 0;

    // 1. Obtener cursores actuales por tabla desde config_sync
    final configRes = await db.query('config_sync', where: 'id = 1');
    Map<String, dynamic> cursores = {};
    if (configRes.isNotEmpty && configRes.first['ultimo_pull_por_tabla'] != null) {
      try {
        cursores = jsonDecode(configRes.first['ultimo_pull_por_tabla'].toString());
      } catch (_) {}
    }

    // 2. Iterar por cada tabla en orden relacional
    for (final tabla in ordenTablas) {
      final String campoCursor = (tabla == 'movimientos_inventario') ? 'created_at' : 'updated_at';
      final String ultimoCursor = cursores[tabla]?.toString() ?? '1970-01-01T00:00:00Z';

      try {
        final List<Map<String, dynamic>> registrosRemotos = await fuenteRemota.consultarModificados(
          tabla: tabla,
          campoCursor: campoCursor,
          ultimoCursor: ultimoCursor,
          limite: 100,
        );

        if (registrosRemotos.isEmpty) continue;

        String maxCursorVisto = ultimoCursor;

        await db.transaction((txn) async {
          for (final reg in registrosRemotos) {
            if (reg is! Map<String, dynamic>) continue;

            final String uuid = reg['uuid']?.toString() ?? '';
            if (uuid.isEmpty) continue;

            final String cursorReg = reg[campoCursor]?.toString() ?? '';
            if (cursorReg.compareTo(maxCursorVisto) > 0) {
              maxCursorVisto = cursorReg;
            }

            // Aplicar el registro remoto en la base local con resolución de conflictos
            await _aplicarRegistroRemotoEnLocal(txn, tabla, reg);
            descargados++;
          }
        });

        // Actualizar el cursor de la tabla
        cursores[tabla] = maxCursorVisto;
        await db.update(
          'config_sync',
          {'ultimo_pull_por_tabla': jsonEncode(cursores)},
          where: 'id = 1',
        );
      } catch (e) {
        debugPrint('Aviso durante PULL en tabla $tabla: $e');
      }
    }

    return descargados;
  }

  // ===========================================================================
  // Resolución de Conflictos y Aplicación Local
  // ===========================================================================

  Future<void> _aplicarRegistroRemotoEnLocal(
    DatabaseExecutor txn,
    String tabla,
    Map<String, dynamic> remoto,
  ) async {
    final String uuid = remoto['uuid'].toString();

    // Consultar existencia local previa
    final locales = await txn.query(tabla, where: 'uuid = ?', whereArgs: [uuid]);

    switch (tabla) {
      case 'productos':
        final fila = _mapearSupabaseAProductoLocal(remoto);
        if (locales.isEmpty) {
          await txn.insert('productos', fila, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          // Last-Write-Wins basado en updated_at estrictamente más reciente
          final String localUpdated = locales.first['updated_at']?.toString() ?? '';
          final String remotoUpdated = remoto['updated_at']?.toString() ?? '';
          if (remotoUpdated.compareTo(localUpdated) > 0) {
            final updateFila = Map<String, dynamic>.from(fila);
            updateFila.remove('id'); // Preservar la clave primaria interna de SQLite
            await txn.update(
              'productos',
              updateFila,
              where: 'uuid = ?',
              whereArgs: [uuid],
            );
          }
        }
        break;

      case 'movimientos_inventario':
        if (locales.isEmpty) {
          final fila = _mapearSupabaseAMovimientoLocal(remoto);
          await txn.insert('movimientos_inventario', fila);

          // Regla clave: Al entrar un movimiento nuevo, recalcular el stock del producto
          final String prodUuid = remoto['producto_uuid']?.toString() ?? '';
          if (prodUuid.isNotEmpty) {
            final nuevoStock = await BaseDeDatos.instancia.calcularStockDesdeMovimientos(
              prodUuid,
              executor: txn,
            );
            await txn.update(
              'productos',
              {'cantidadEnInventario': nuevoStock},
              where: 'uuid = ?',
              whereArgs: [prodUuid],
            );
          }
        }
        break;

      case 'ventas':
        final fila = _mapearSupabaseAVentaLocal(remoto);
        if (locales.isEmpty) {
          await txn.insert('ventas', fila, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          final String localUpdated = locales.first['updated_at']?.toString() ?? '';
          final String remotoUpdated = remoto['updated_at']?.toString() ?? '';
          if (remotoUpdated.compareTo(localUpdated) > 0) {
            final updateFila = Map<String, dynamic>.from(fila);
            updateFila.remove('id'); // Preservar la clave primaria interna de SQLite
            await txn.update('ventas', updateFila, where: 'uuid = ?', whereArgs: [uuid]);
          }
        }
        break;

      case 'articulos_venta':
        if (locales.isEmpty) {
          final fila = _mapearSupabaseAArticuloLocal(txn, remoto);
          await txn.insert('articulos_venta', await fila, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        break;

      case 'deudores':
        final fila = _mapearSupabaseADeudorLocal(txn, remoto);
        final filaRes = await fila;
        if (locales.isEmpty) {
          await txn.insert('deudores', filaRes, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          final String localUpdated = locales.first['updated_at']?.toString() ?? '';
          final String remotoUpdated = remoto['updated_at']?.toString() ?? '';
          if (remotoUpdated.compareTo(localUpdated) > 0) {
            final updateFila = Map<String, dynamic>.from(filaRes);
            updateFila.remove('id'); // Preservar la clave primaria interna de SQLite
            await txn.update('deudores', updateFila, where: 'uuid = ?', whereArgs: [uuid]);
          }
        }
        break;

      case 'abonos_venta':
        if (locales.isEmpty) {
          final fila = _mapearSupabaseAAbonoLocal(txn, remoto);
          await txn.insert('abonos_venta', await fila, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        break;

      case 'colaboradores':
        final fila = _mapearSupabaseAColaboradorLocal(remoto);
        if (locales.isEmpty) {
          await txn.insert('colaboradores', fila, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          final String localUpdated = locales.first['updated_at']?.toString() ?? '';
          final String remotoUpdated = remoto['updated_at']?.toString() ?? '';
          if (remotoUpdated.compareTo(localUpdated) > 0) {
            final updateFila = Map<String, dynamic>.from(fila);
            updateFila.remove('id'); // Preservar la clave primaria interna de SQLite
            await txn.update('colaboradores', updateFila, where: 'uuid = ?', whereArgs: [uuid]);
          }
        }
        break;
    }
  }

  // ===========================================================================
  // Mapeadores de Esquema Local SQLite <-> Supabase PostgreSQL
  // ===========================================================================

  Map<String, dynamic> _mapearFilaLocalASupabase(
    String tabla,
    Map<String, dynamic> local,
    String dispositivoId,
  ) {
    switch (tabla) {
      case 'productos':
        return {
          'uuid': local['uuid'],
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
          'updated_at': local['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
          'deleted_at': local['deleted_at'],
        };

      case 'ventas':
        final bool aplicarIva = local['aplicarIva'] == 1 || local['aplicarIva'] == true;
        final double pctIva = (local['porcentajeIva'] as num?)?.toDouble() ?? 0.16;
        return {
          'uuid': local['uuid'],
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
          'dispositivo_id': local['dispositivo_id'] ?? dispositivoId,
          'updated_at': local['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
          'deleted_at': local['deleted_at'],
        };

      case 'articulos_venta':
        return {
          'uuid': local['uuid'],
          'venta_uuid': local['venta_uuid'],
          'producto_uuid': local['producto_uuid'],
          'cantidad': local['cantidad'],
          'precio_unitario': local['precioUnitario'],
          'updated_at': local['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
          'deleted_at': local['deleted_at'],
        };

      case 'deudores':
        return {
          'uuid': local['uuid'],
          'venta_uuid': local['venta_uuid'],
          'nombre_cliente': local['cliente'],
          'telefono': local['telefono'] ?? '',
          'monto_total': local['montoTotal'],
          'monto_pagado': local['montoPagado'],
          'saldo_pendiente': local['saldoPendiente'],
          'estado': local['estado'],
          'fecha_limite': local['fechaLimite'],
          'updated_at': local['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
          'deleted_at': local['deleted_at'],
        };

      case 'abonos_venta':
        return {
          'uuid': local['uuid'],
          'venta_uuid': local['venta_uuid'],
          'deudor_uuid': local['deudor_uuid'],
          'monto': local['monto'],
          'fecha': local['fecha'],
          'metodo_pago': local['metodoPago'] ?? 'Efectivo',
          'colaborador_uuid': local['colaborador_uuid'],
          'dispositivo_id': local['dispositivo_id'] ?? dispositivoId,
          'updated_at': local['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
          'deleted_at': local['deleted_at'],
        };

      case 'movimientos_inventario':
        return {
          'uuid': local['uuid'],
          'producto_uuid': local['producto_uuid'],
          'tipo': local['tipo'],
          'cantidad': local['cantidad'],
          'referencia_uuid': local['referencia_uuid'],
          'motivo': local['motivo'],
          'colaborador_uuid': local['colaborador_uuid'],
          'dispositivo_id': local['dispositivo_id'] ?? dispositivoId,
          'created_at': local['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
        };

      case 'colaboradores':
        final String rolNorm = local['rol']?.toString().toLowerCase().contains('due') == true
            ? 'dueno'
            : 'empleado';
        return {
          'uuid': local['uuid'],
          'codigo_local': local['id'],
          'nombre': local['nombre'],
          'rol': rolNorm,
          'activo': local['activo'] == null || local['activo'] == 1,
          'updated_at': local['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
          'deleted_at': local['deleted_at'],
        };

      default:
        return Map<String, dynamic>.from(local);
    }
  }

  Map<String, dynamic> _mapearPayloadASupabase(
    String tabla,
    Map<String, dynamic> payload,
    String dispositivoId,
  ) {
    return _mapearFilaLocalASupabase(tabla, payload, dispositivoId);
  }

  Map<String, dynamic> _mapearSupabaseAProductoLocal(Map<String, dynamic> remoto) {
    return {
      'id': remoto['codigo_local'] ?? remoto['uuid'].toString().substring(0, 8),
      'uuid': remoto['uuid'],
      'nombre': remoto['nombre'],
      'notas': remoto['notas_botanicas'] ?? '',
      'precioVenta': (remoto['precio_venta'] as num?)?.toDouble() ?? 0.0,
      'costo': (remoto['costo'] as num?)?.toDouble() ?? 0.0,
      'cantidadEnInventario': (remoto['stock'] as num?)?.toInt() ?? 0,
      'umbralStockCritico': (remoto['umbral_stock_critico'] as num?)?.toInt() ?? 5,
      'tipo': remoto['tipo'] ?? 'planta',
      'imagenes': remoto['imagen_url'] ?? '',
      'activo': (remoto['activo'] == true && remoto['deleted_at'] == null) ? 1 : 0,
      'updated_at': remoto['updated_at'],
      'deleted_at': remoto['deleted_at'],
      'sync_estado': 'sincronizado',
    };
  }

  Map<String, dynamic> _mapearSupabaseAMovimientoLocal(Map<String, dynamic> remoto) {
    return {
      'uuid': remoto['uuid'],
      'producto_uuid': remoto['producto_uuid'],
      'tipo': remoto['tipo'],
      'cantidad': (remoto['cantidad'] as num?)?.toInt() ?? 0,
      'referencia_uuid': remoto['referencia_uuid'],
      'motivo': remoto['motivo'],
      'colaborador_uuid': remoto['colaborador_uuid'],
      'dispositivo_id': remoto['dispositivo_id'],
      'sync_estado': 'sincronizado',
      'created_at': remoto['created_at'],
    };
  }

  Map<String, dynamic> _mapearSupabaseAVentaLocal(Map<String, dynamic> remoto) {
    return {
      'id': remoto['folio_local'] ?? remoto['uuid'].toString().substring(0, 8),
      'uuid': remoto['uuid'],
      'colaborador_uuid': remoto['colaborador_uuid'],
      'fecha': remoto['fecha'],
      'estado': remoto['estado'] ?? 'completada',
      'porcentajeIva': (remoto['porcentaje_iva'] as num?)?.toDouble() ?? 0.16,
      'aplicarIva': remoto['aplicar_iva'] == true ? 1 : 0,
      'cliente': remoto['cliente'] ?? 'Cliente Mostrador',
      'montoPagado': (remoto['monto_pagado'] as num?)?.toDouble() ?? 0.0,
      'notas': remoto['notas'] ?? '',
      'updated_at': remoto['updated_at'],
      'deleted_at': remoto['deleted_at'],
      'sync_estado': 'sincronizado',
      'dispositivo_id': remoto['dispositivo_id'],
    };
  }

  Future<Map<String, dynamic>> _mapearSupabaseAArticuloLocal(
    DatabaseExecutor txn,
    Map<String, dynamic> remoto,
  ) async {
    final ventaUuid = remoto['venta_uuid']?.toString();
    final prodUuid = remoto['producto_uuid']?.toString();

    // Resolver venta_id local y producto_id local si existen
    String ventaIdLocal = '';
    String prodIdLocal = '';

    if (ventaUuid != null) {
      final v = await txn.query('ventas', columns: ['id'], where: 'uuid = ?', whereArgs: [ventaUuid]);
      if (v.isNotEmpty) ventaIdLocal = v.first['id']?.toString() ?? '';
    }
    if (prodUuid != null) {
      final p = await txn.query('productos', columns: ['id'], where: 'uuid = ?', whereArgs: [prodUuid]);
      if (p.isNotEmpty) prodIdLocal = p.first['id']?.toString() ?? '';
    }

    return {
      'uuid': remoto['uuid'],
      'venta_id': ventaIdLocal.isNotEmpty ? ventaIdLocal : (ventaUuid ?? ''),
      'venta_uuid': ventaUuid,
      'producto_id': prodIdLocal.isNotEmpty ? prodIdLocal : (prodUuid ?? ''),
      'producto_uuid': prodUuid,
      'cantidad': (remoto['cantidad'] as num?)?.toInt() ?? 1,
      'precioUnitario': (remoto['precio_unitario'] as num?)?.toDouble() ?? 0.0,
      'updated_at': remoto['updated_at'],
      'deleted_at': remoto['deleted_at'],
      'sync_estado': 'sincronizado',
    };
  }

  Future<Map<String, dynamic>> _mapearSupabaseADeudorLocal(
    DatabaseExecutor txn,
    Map<String, dynamic> remoto,
  ) async {
    final ventaUuid = remoto['venta_uuid']?.toString();
    String ventaIdLocal = '';
    if (ventaUuid != null) {
      final v = await txn.query('ventas', columns: ['id'], where: 'uuid = ?', whereArgs: [ventaUuid]);
      if (v.isNotEmpty) ventaIdLocal = v.first['id']?.toString() ?? '';
    }

    return {
      'id': 'deu_${ventaIdLocal.isNotEmpty ? ventaIdLocal : ventaUuid}',
      'uuid': remoto['uuid'],
      'venta_id': ventaIdLocal.isNotEmpty ? ventaIdLocal : (ventaUuid ?? ''),
      'venta_uuid': ventaUuid,
      'cliente': remoto['nombre_cliente'] ?? 'Cliente Mostrador',
      'telefono': remoto['telefono'] ?? '',
      'montoTotal': (remoto['monto_total'] as num?)?.toDouble() ?? 0.0,
      'montoPagado': (remoto['monto_pagado'] as num?)?.toDouble() ?? 0.0,
      'saldoPendiente': (remoto['saldo_pendiente'] as num?)?.toDouble() ?? 0.0,
      'estado': remoto['estado'] ?? 'PENDIENTE',
      'fechaRegistro': remoto['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'fechaLimite': remoto['fecha_limite'],
      'updated_at': remoto['updated_at'],
      'deleted_at': remoto['deleted_at'],
      'sync_estado': 'sincronizado',
    };
  }

  Future<Map<String, dynamic>> _mapearSupabaseAAbonoLocal(
    DatabaseExecutor txn,
    Map<String, dynamic> remoto,
  ) async {
    final ventaUuid = remoto['venta_uuid']?.toString();
    String ventaIdLocal = '';
    if (ventaUuid != null) {
      final v = await txn.query('ventas', columns: ['id'], where: 'uuid = ?', whereArgs: [ventaUuid]);
      if (v.isNotEmpty) ventaIdLocal = v.first['id']?.toString() ?? '';
    }

    return {
      'id': remoto['uuid'].toString().substring(0, 12),
      'uuid': remoto['uuid'],
      'venta_id': ventaIdLocal.isNotEmpty ? ventaIdLocal : (ventaUuid ?? ''),
      'venta_uuid': ventaUuid,
      'deudor_uuid': remoto['deudor_uuid'],
      'colaborador_uuid': remoto['colaborador_uuid'],
      'monto': (remoto['monto'] as num?)?.toDouble() ?? 0.0,
      'fecha': remoto['fecha'],
      'metodoPago': remoto['metodo_pago'] ?? 'Efectivo',
      'updated_at': remoto['updated_at'],
      'deleted_at': remoto['deleted_at'],
      'sync_estado': 'sincronizado',
      'dispositivo_id': remoto['dispositivo_id'],
    };
  }

  Map<String, dynamic> _mapearSupabaseAColaboradorLocal(Map<String, dynamic> remoto) {
    return {
      'id': remoto['codigo_local'] ?? remoto['uuid'].toString().substring(0, 8),
      'uuid': remoto['uuid'],
      'nombre': remoto['nombre'],
      'clave': '', // Las claves no bajan de Supabase por seguridad PBKDF2 local
      'rol': remoto['rol'] == 'dueno' ? 'dueño' : 'empleado',
      'updated_at': remoto['updated_at'],
      'deleted_at': remoto['deleted_at'],
      'sync_estado': 'sincronizado',
    };
  }

  Future<void> _reconciliarFilasPendientesHaciaCola(
    Database db,
    String dispositivoId,
  ) async {
    for (final tabla in ordenTablas) {
      final pendientes = await db.query(
        tabla,
        where: "sync_estado = 'pendiente'",
        limit: 50,
      );
      for (final fila in pendientes) {
        final uuid = fila['uuid']?.toString();
        if (uuid == null || uuid.isEmpty) continue;

        // Verificar si ya existe en cola
        final existeEnCola = await db.query(
          'cola_sincronizacion',
          where: 'tabla = ? AND registro_uuid = ?',
          whereArgs: [tabla, uuid],
        );

        if (existeEnCola.isEmpty) {
          final payload = _mapearFilaLocalASupabase(tabla, fila, dispositivoId);
          await db.insert('cola_sincronizacion', {
            'tabla': tabla,
            'registro_uuid': uuid,
            'operacion': 'upsert',
            'payload_json': jsonEncode(payload),
            'intentos': 0,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      }
    }
  }

  Future<String> _obtenerDispositivoId(Database db) async {
    final res = await db.query('config_sync', where: 'id = 1');
    if (res.isNotEmpty && res.first['dispositivo_id'] != null) {
      return res.first['dispositivo_id'].toString();
    }
    return 'dispositivo-local';
  }
}
