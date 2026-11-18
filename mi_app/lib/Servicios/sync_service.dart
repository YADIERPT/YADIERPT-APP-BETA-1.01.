import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
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

/// Resultado detallado de la sincronización de imágenes físicas hacia Storage.
class SyncImagesResult {
  final bool exitoso;
  final int totalImagenesSubidas;
  final List<String> urlsGeneradas;
  final String? error;

  const SyncImagesResult({
    required this.exitoso,
    this.totalImagenesSubidas = 0,
    this.urlsGeneradas = const [],
    this.error,
  });

  @override
  String toString() =>
      'SyncImagesResult(exitoso: $exitoso, totalImagenesSubidas: $totalImagenesSubidas, error: $error)';
}

/// Resultado integral del ciclo secuencial de sincronización (Push -> Storage -> Pull).
class SyncCycleResult {
  final bool exitoso;
  final SyncPushResult pushResult;
  final SyncImagesResult imagesResult;
  final SyncPullResult pullResult;
  final String? error;

  const SyncCycleResult({
    required this.exitoso,
    required this.pushResult,
    required this.imagesResult,
    required this.pullResult,
    this.error,
  });

  @override
  String toString() =>
      'SyncCycleResult(exitoso: $exitoso, push: $pushResult, images: $imagesResult, pull: $pullResult, error: $error)';
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

/// Servicio integral de sincronización Offline-First:
/// - Fase 2: Push Batching (Subida de cambios locales).
/// - Fase 3: Pull Incremental & Upsert Masivo (Cero Duplicados con cursor).
/// - Fase 4: Storage Sync (Subida y compresión de archivos físicos a Supabase Storage).
class SyncService {
  static final SyncService instancia = SyncService._();
  SyncService._();

  /// Nombre del bucket predeterminado en Supabase Storage
  static const String bucketImagenesProductos = 'productos';

  /// Tamaño predeterminado de cada lote HTTP para evitar sobrecargar la conexión
  static const int batchSizePredeterminado = 50;

  bool _sincronizando = false;
  bool get sincronizando => _sincronizando;

  /// Orden relacional estricto para sincronización:
  /// 1. Empleados / Colaboradores (sin dependencias)
  /// 2. Productos (sin dependencias)
  /// 3. Cortes de Caja (cajeros y turnos de caja)
  /// 4. Ventas (depende de colaboradores)
  /// 5. Tickets / Artículos de Venta (depende de ventas y productos)
  /// 6. Movimientos de Inventario (depende de productos y ventas)
  /// 7. Deudores (depende de ventas)
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
      nombreLocal: 'cortes_caja',
      nombreRemoto: 'cortes_caja',
      campoId: 'id',
      transformadorPush: _mapearCorteCajaASupabase,
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
    _TablaSyncConfig(
      nombreLocal: 'movimientos_inventario',
      nombreRemoto: 'movimientos_inventario',
      campoId: 'uuid',
      transformadorPush: _mapearMovimientoInventarioASupabase,
    ),
    _TablaSyncConfig(
      nombreLocal: 'deudores',
      nombreRemoto: 'deudores',
      campoId: 'id',
      transformadorPush: _mapearDeudorASupabase,
    ),
  ];

  // ===========================================================================
  // CICLO INTEGRAL SECUENCIAL (Push -> Storage Sync -> Pull)
  // ===========================================================================

  /// Ejecuta el ciclo completo de sincronización secuencial en el orden:
  /// 1. `pushLocalChanges()`: Sube registros de datos locales pendientes (`is_synced == 0`).
  /// 2. `syncImages()`: Comprime y sube archivos físicos locales a Supabase Storage.
  /// 3. `pullCloudChanges()`: Descarga mutaciones de la nube aplicando cursor y Upsert masivo.
  Future<SyncCycleResult> syncAll({
    SupabaseClient? clientOverride,
    Database? dbOverride,
  }) async {
    final resPush = await pushLocalChanges(
      clientOverride: clientOverride,
      dbOverride: dbOverride,
    );
    final resImages = await syncImages(
      clientOverride: clientOverride,
      dbOverride: dbOverride,
    );
    final resPull = await pullCloudChanges(
      clientOverride: clientOverride,
      dbOverride: dbOverride,
    );

    final bool exito = resPush.exitoso && resImages.exitoso && resPull.exitoso;
    final String? error = resPush.error ?? resImages.error ?? resPull.error;

    return SyncCycleResult(
      exitoso: exito,
      pushResult: resPush,
      imagesResult: resImages,
      pullResult: resPull,
      error: error,
    );
  }

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

        // 5. Consultar registros remotos donde updated_at >= last_sync_timestamp
        final List<Map<String, dynamic>> registrosRemotos;
        if (pullHandlerOverride != null) {
          registrosRemotos = await pullHandlerOverride(config.nombreRemoto, lastSyncTimestamp);
        } else {
          var query = client!.from(config.nombreRemoto).select();
          if (lastSyncTimestamp != null && lastSyncTimestamp.isNotEmpty) {
            query = query.gte('updated_at', lastSyncTimestamp);
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
  // FASE 4: STORAGE SYNC (Sincronización de Archivos Físicos a Supabase Storage)
  // ===========================================================================

  /// Sincroniza archivos físicos de imágenes locales hacia Supabase Storage.
  ///
  /// 1. Busca productos con rutas locales de imagen en SQLite (que no contengan URLs web de Supabase/HTTP).
  /// 2. Si la imagen es pesada (> 300 KB), aplica compresión WebP antes de subirla.
  /// 3. Sube el archivo físico al bucket de Supabase Storage ('productos').
  /// 4. Reemplaza la ruta local por la URL pública web devuelta por Supabase.
  /// 5. Marca el registro en SQLite con `is_synced = 0` y `sync_estado = 'pendiente'`
  ///    para que el método `pushLocalChanges()` sincronice la fila actualizada en la base remota.
  Future<SyncImagesResult> syncImages({
    SupabaseClient? clientOverride,
    Future<String> Function(String bucket, String remotePath, File file)? storageUploaderOverride,
    Database? dbOverride,
    String bucket = bucketImagenesProductos,
    int umbralCompresionBytes = 300 * 1024, // 300 KB
  }) async {
    int subidas = 0;
    final List<String> urlsGeneradas = [];

    try {
      // 1. Validar cliente de Supabase (a menos que haya mock en pruebas)
      SupabaseClient? client;
      if (storageUploaderOverride == null) {
        client = clientOverride ??
            (ServicioSupabase.instancia.estaInicializado
                ? ServicioSupabase.instancia.client
                : (kIsWeb || Supabase.instance.isInitialized ? Supabase.instance.client : null));

        if (client == null) {
          debugPrint('SyncService [STORAGE]: Supabase no está inicializado. Modo local activo.');
          return const SyncImagesResult(
            exitoso: true,
            totalImagenesSubidas: 0,
            error: 'Modo local activo (sin conexión a Supabase).',
          );
        }

        // 2. Validar conectividad de red
        if (clientOverride == null) {
          final hayRed = await ServicioConectividad.instancia.tieneConexion();
          if (!hayRed) {
            debugPrint('SyncService [STORAGE]: Sin conexión a internet disponible.');
            return const SyncImagesResult(
              exitoso: false,
              totalImagenesSubidas: 0,
              error: 'Sin conexión a internet.',
            );
          }
        }
      }

      final db = dbOverride ?? (await BaseDeDatos.instancia.database);

      // 3. Buscar productos que tengan imágenes locales y no estén eliminados (Soft Delete)
      final productos = await db.query(
        'productos',
        columns: ['id', 'uuid', 'imagenes'],
        where: "imagenes IS NOT NULL AND imagenes != '' AND (deleted_at IS NULL OR deleted_at = '')",
      );

      if (productos.isEmpty) {
        return const SyncImagesResult(exitoso: true, totalImagenesSubidas: 0);
      }

      for (final prod in productos) {
        final String imagenesRaw = prod['imagenes']?.toString() ?? '';
        final String prodUuid = prod['uuid']?.toString() ?? prod['id']?.toString() ?? const Uuid().v4();
        final List<String> rutas = imagenesRaw.split(',');
        final List<String> rutasActualizadas = [];
        bool huboCambios = false;

        for (final ruta in rutas) {
          final rutaLimpia = ruta.trim();
          if (rutaLimpia.isEmpty) continue;

          // Si ya es una URL web o asset de la app, conservar intacta
          if (_esUrlRemotaOAsset(rutaLimpia)) {
            rutasActualizadas.add(rutaLimpia);
            continue;
          }

          final archivoLocal = File(rutaLimpia);
          if (!archivoLocal.existsSync()) {
            debugPrint('SyncService [STORAGE]: El archivo local $rutaLimpia no existe en disco. Omitiendo.');
            rutasActualizadas.add(rutaLimpia);
            continue;
          }

          // 4. Compresión inteligente previa a la subida si es pesada (> 300 KB)
          final File archivoASubir = await _comprimirSiEsPesada(
            archivoLocal,
            umbralBytes: umbralCompresionBytes,
          );

          try {
            // 5. Subir archivo a Supabase Storage
            final String remotePath = '$prodUuid/${DateTime.now().millisecondsSinceEpoch}_${p.basenameWithoutExtension(archivoLocal.path)}.webp';
            final String publicUrl;

            if (storageUploaderOverride != null) {
              publicUrl = await storageUploaderOverride(bucket, remotePath, archivoASubir);
            } else {
              final storage = client!.storage.from(bucket);
              await storage.upload(
                remotePath,
                archivoASubir,
                fileOptions: const FileOptions(upsert: true, contentType: 'image/webp'),
              );
              publicUrl = storage.getPublicUrl(remotePath);
            }

            rutasActualizadas.add(publicUrl);
            urlsGeneradas.add(publicUrl);
            subidas++;
            huboCambios = true;
            debugPrint('SyncService [STORAGE]: Imagen de producto $prodUuid subida exitosamente: $publicUrl');
          } catch (e) {
            debugPrint('SyncService [STORAGE]: Error al subir imagen $rutaLimpia: $e');
            // Si falla la subida de esta imagen, conservamos la ruta local para el próximo reintento
            rutasActualizadas.add(rutaLimpia);
          }
        }

        // 6. Si se subió alguna imagen, actualizar el producto en SQLite y marcar is_synced = 0
        if (huboCambios) {
          await db.update(
            'productos',
            {
              'imagenes': rutasActualizadas.join(','),
              'is_synced': 0, // ¡CRÍTICO! Marcar 0 para que pushLocalChanges() actualice la fila en la BD remota
              'sync_estado': 'pendiente',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [prod['id']],
          );
        }
      }

      return SyncImagesResult(
        exitoso: true,
        totalImagenesSubidas: subidas,
        urlsGeneradas: urlsGeneradas,
      );
    } catch (e) {
      debugPrint('SyncService [STORAGE]: Error en syncImages: $e');
      return SyncImagesResult(
        exitoso: false,
        totalImagenesSubidas: subidas,
        urlsGeneradas: urlsGeneradas,
        error: e.toString(),
      );
    }
  }

  /// Verifica si una ruta es ya una URL web o un asset bundle empaquetado
  static bool _esUrlRemotaOAsset(String ruta) {
    final lower = ruta.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('assets/');
  }

  /// Comprime ligeramente una imagen si supera el umbral establecido (por defecto 300 KB).
  /// Convierte a formato WebP optimizado al 80% de calidad.
  static Future<File> _comprimirSiEsPesada(
    File original, {
    required int umbralBytes,
  }) async {
    try {
      final int longitud = await original.length();
      if (longitud <= umbralBytes) {
        return original;
      }

      final tempDir = Directory.systemTemp;
      final targetPath = p.join(
        tempDir.path,
        'opt_${DateTime.now().millisecondsSinceEpoch}_${p.basenameWithoutExtension(original.path)}.webp',
      );

      final resultado = await FlutterImageCompress.compressAndGetFile(
        original.absolute.path,
        targetPath,
        minWidth: 1024,
        minHeight: 1024,
        quality: 80,
        format: CompressFormat.webp,
      );

      if (resultado != null) {
        return File(resultado.path);
      }
    } catch (e) {
      debugPrint('SyncService [STORAGE]: Aviso en compresión ($e). Utilizando archivo original.');
    }
    return original;
  }

  // ===========================================================================
  // Control de Cursor de Sincronización (last_sync_timestamp)
  // ===========================================================================

  /// Clave estandarizada en SharedPreferences para el cursor de sincronización
  static const String keyPrefLastSyncTimestamp = 'last_sync_timestamp';

  /// Lee la fecha de la última sincronización (`last_sync_timestamp`) desde `SharedPreferences`
  /// con fallback robusto a la tabla local `config_sync` de SQLite.
  Future<String?> obtenerLastSyncTimestamp({Database? db}) async {
    // 1. Intentar leer desde SharedPreferences (Fase 3)
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getString(keyPrefLastSyncTimestamp);
      if (ts != null && ts.isNotEmpty) {
        return ts;
      }
    } catch (e) {
      debugPrint('SyncService: Lectura de SharedPreferences omitida o en entorno de pruebas: $e');
    }

    // 2. Respaldo / Fallback en SQLite (config_sync)
    try {
      final database = db ?? (await BaseDeDatos.instancia.database);
      await _asegurarColumnaLastSyncTimestamp(database);
      final res = await database.query('config_sync', where: 'id = 1');
      if (res.isNotEmpty) {
        return res.first['last_sync_timestamp']?.toString() ??
            res.first['ultima_sync_exitosa']?.toString();
      }
    } catch (e) {
      debugPrint('SyncService: Error al leer last_sync_timestamp de SQLite: $e');
    }
    return null;
  }

  /// Actualiza atómicamente el `last_sync_timestamp` tanto en `SharedPreferences`
  /// como en SQLite tras una descarga exitosa.
  Future<void> actualizarLastSyncTimestamp(String timestamp, {Database? db}) async {
    // 1. Guardar en SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyPrefLastSyncTimestamp, timestamp);
    } catch (e) {
      debugPrint('SyncService: Guardado en SharedPreferences omitido o en entorno de pruebas: $e');
    }

    // 2. Guardar en SQLite (config_sync) para redundancia local
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
      debugPrint('SyncService: Error al actualizar last_sync_timestamp en SQLite: $e');
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
      case 'cortes_caja':
        return _mapearSupabaseACorteCajaLocal(remoto, txn);
      case 'movimientos_inventario':
        return _mapearSupabaseAMovimientoInventarioLocal(remoto, txn);
      case 'deudores':
        return _mapearSupabaseADeudorLocal(remoto, txn);
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
      'created_at': remoto['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
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
      'created_at': remoto['created_at']?.toString() ?? remoto['fecha']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
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
      'id': uuid,
      'uuid': uuid,
      'venta_id': ventaId,
      'venta_uuid': remoto['venta_uuid']?.toString(),
      'producto_id': productoId,
      'producto_uuid': remoto['producto_uuid']?.toString(),
      'cantidad': (remoto['cantidad'] as num?)?.toInt() ?? 1,
      'precioUnitario': (remoto['precio_unitario'] ?? remoto['precioUnitario'] as num?)?.toDouble() ?? 0.0,
      'is_synced': 1,
      'sync_estado': 'sincronizado',
      'created_at': remoto['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      'updated_at': remoto['updated_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': remoto['deleted_at']?.toString(),
    };

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
      'created_at': remoto['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      'updated_at': remoto['updated_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': remoto['deleted_at']?.toString(),
    };
  }

  static Future<Map<String, dynamic>> _mapearSupabaseAMovimientoInventarioLocal(
    Map<String, dynamic> remoto,
    DatabaseExecutor txn,
  ) async {
    final String uuid = remoto['uuid']?.toString() ?? const Uuid().v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return {
      'uuid': uuid,
      'producto_uuid': remoto['producto_uuid']?.toString() ?? '',
      'tipo': remoto['tipo']?.toString() ?? 'ajuste',
      'cantidad': (remoto['cantidad'] as num?)?.toInt() ?? 0,
      'referencia_uuid': remoto['referencia_uuid']?.toString(),
      'motivo': remoto['motivo']?.toString(),
      'colaborador_uuid': remoto['colaborador_uuid']?.toString(),
      'dispositivo_id': remoto['dispositivo_id']?.toString(),
      'is_synced': 1,
      'sync_estado': 'sincronizado',
      'created_at': remoto['created_at']?.toString() ?? nowIso,
      'updated_at': remoto['updated_at']?.toString() ?? nowIso,
    };
  }

  static Future<Map<String, dynamic>> _mapearSupabaseACorteCajaLocal(
    Map<String, dynamic> remoto,
    DatabaseExecutor txn,
  ) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final uuid = remoto['uuid']?.toString() ?? remoto['id']?.toString() ?? const Uuid().v4();
    final idLocal = remoto['codigo_local']?.toString() ?? remoto['id']?.toString() ?? uuid;
    return {
      'id': idLocal,
      'uuid': uuid,
      'colaborador_uuid': remoto['colaborador_uuid']?.toString() ?? '',
      'dispositivo_id': remoto['dispositivo_id']?.toString() ?? 'pos-remoto',
      'monto_apertura': (remoto['monto_apertura'] as num?)?.toDouble() ?? 0.0,
      'monto_ventas_efectivo': (remoto['monto_ventas_efectivo'] as num?)?.toDouble() ?? 0.0,
      'monto_abonos_efectivo': (remoto['monto_abonos_efectivo'] as num?)?.toDouble() ?? 0.0,
      'monto_egresos': (remoto['monto_egresos'] as num?)?.toDouble() ?? 0.0,
      'monto_esperado': (remoto['monto_esperado'] as num?)?.toDouble() ?? 0.0,
      'monto_real': (remoto['monto_real'] as num?)?.toDouble() ?? 0.0,
      'diferencia': (remoto['diferencia'] as num?)?.toDouble() ?? 0.0,
      'estado': remoto['estado']?.toString() ?? 'ABIERTA',
      'notas': remoto['notas']?.toString() ?? '',
      'fecha_apertura': remoto['fecha_apertura']?.toString() ?? nowIso,
      'fecha_cierre': remoto['fecha_cierre']?.toString(),
      'is_synced': 1,
      'sync_estado': 'sincronizado',
      'created_at': remoto['created_at']?.toString() ?? nowIso,
      'updated_at': remoto['updated_at']?.toString() ?? nowIso,
      'deleted_at': remoto['deleted_at']?.toString(),
    };
  }

  static Future<Map<String, dynamic>> _mapearSupabaseADeudorLocal(
    Map<String, dynamic> remoto,
    DatabaseExecutor txn,
  ) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final uuid = remoto['uuid']?.toString() ?? remoto['id']?.toString() ?? const Uuid().v4();
    String idLocal = remoto['codigo_local']?.toString() ?? remoto['id']?.toString() ?? uuid;

    final existente = await txn.query(
      'deudores',
      columns: ['id'],
      where: 'id = ? OR uuid = ?',
      whereArgs: [uuid, uuid],
      limit: 1,
    );
    if (existente.isNotEmpty) {
      idLocal = existente.first['id'].toString();
    }

    final ventaUuid = remoto['venta_uuid']?.toString();
    String ventaId = ventaUuid ?? '';
    if (ventaUuid != null && ventaUuid.isNotEmpty) {
      final v = await txn.query('ventas', columns: ['id'], where: 'uuid = ? OR id = ?', whereArgs: [ventaUuid, ventaUuid]);
      if (v.isNotEmpty) {
        ventaId = v.first['id'].toString();
      }
    }

    return {
      'id': idLocal,
      'uuid': uuid,
      'venta_id': ventaId.isNotEmpty ? ventaId : (remoto['venta_id']?.toString() ?? ''),
      'cliente': remoto['nombre_cliente'] ?? remoto['cliente'] ?? 'Cliente Mostrador',
      'telefono': remoto['telefono'] ?? '',
      'montoTotal': (remoto['monto_total'] ?? remoto['montoTotal'] as num?)?.toDouble() ?? 0.0,
      'montoPagado': (remoto['monto_pagado'] ?? remoto['montoPagado'] as num?)?.toDouble() ?? 0.0,
      'saldoPendiente': (remoto['saldo_pendiente'] ?? remoto['saldoPendiente'] as num?)?.toDouble() ?? 0.0,
      'estado': remoto['estado']?.toString() ?? 'PENDIENTE',
      'fechaRegistro': remoto['created_at']?.toString() ?? remoto['fechaRegistro']?.toString() ?? nowIso,
      'fechaLimite': remoto['fecha_limite']?.toString() ?? remoto['fechaLimite']?.toString(),
      'is_synced': 1,
      'sync_estado': 'sincronizado',
      'created_at': remoto['created_at']?.toString() ?? nowIso,
      'updated_at': remoto['updated_at']?.toString() ?? nowIso,
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
      'created_at': local['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
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
      'created_at': local['created_at'] ?? local['fecha'] ?? DateTime.now().toUtc().toIso8601String(),
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
      'created_at': local['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
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
      'created_at': local['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'updated_at': local['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': local['deleted_at'],
    };
  }

  static Map<String, dynamic> _mapearMovimientoInventarioASupabase(Map<String, dynamic> local) {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return {
      'uuid': local['uuid'],
      'producto_uuid': local['producto_uuid'],
      'tipo': local['tipo']?.toString() ?? 'ajuste',
      'cantidad': local['cantidad'] ?? 0,
      'referencia_uuid': local['referencia_uuid'],
      'motivo': local['motivo'],
      'colaborador_uuid': local['colaborador_uuid'],
      'dispositivo_id': local['dispositivo_id'],
      'created_at': local['created_at'] ?? nowIso,
      'updated_at': local['updated_at'] ?? local['created_at'] ?? nowIso,
    };
  }

  static Map<String, dynamic> _mapearCorteCajaASupabase(Map<String, dynamic> local) {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return {
      'uuid': local['uuid'] ?? local['id'],
      'codigo_local': local['id'],
      'colaborador_uuid': local['colaborador_uuid'],
      'dispositivo_id': local['dispositivo_id'] ?? 'pos-tablet',
      'monto_apertura': local['monto_apertura'] ?? 0.0,
      'monto_ventas_efectivo': local['monto_ventas_efectivo'] ?? 0.0,
      'monto_abonos_efectivo': local['monto_abonos_efectivo'] ?? 0.0,
      'monto_egresos': local['monto_egresos'] ?? 0.0,
      'monto_esperado': local['monto_esperado'] ?? 0.0,
      'monto_real': local['monto_real'] ?? 0.0,
      'diferencia': local['diferencia'] ?? 0.0,
      'estado': local['estado'] ?? 'ABIERTA',
      'notas': local['notas'] ?? '',
      'fecha_apertura': local['fecha_apertura'] ?? nowIso,
      'fecha_cierre': local['fecha_cierre'],
      'created_at': local['created_at'] ?? local['fecha_apertura'] ?? nowIso,
      'updated_at': local['updated_at'] ?? nowIso,
      'deleted_at': local['deleted_at'],
    };
  }

  static Map<String, dynamic> _mapearDeudorASupabase(Map<String, dynamic> local) {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return {
      'uuid': local['uuid'] ?? local['id'],
      'codigo_local': local['id'],
      'venta_uuid': local['venta_uuid'] ?? local['venta_id'],
      'nombre_cliente': local['cliente'] ?? 'Cliente Mostrador',
      'telefono': local['telefono'] ?? '',
      'monto_total': local['montoTotal'] ?? 0.0,
      'monto_pagado': local['montoPagado'] ?? 0.0,
      'saldo_pendiente': local['saldoPendiente'] ?? 0.0,
      'estado': local['estado'] ?? 'PENDIENTE',
      'fecha_limite': local['fechaLimite'],
      'created_at': local['created_at'] ?? local['fechaRegistro'] ?? nowIso,
      'updated_at': local['updated_at'] ?? nowIso,
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
