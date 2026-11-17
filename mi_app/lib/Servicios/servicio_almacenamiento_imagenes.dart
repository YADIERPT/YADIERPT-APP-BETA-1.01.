import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../BaseDatos/base_datos.dart';
import 'servicio_conectividad.dart';
import 'servicio_supabase.dart';

/// Resultado del procesamiento y compresión de imagen de catálogo botánico.
class ImagenProcesada {
  final File archivoPrincipal;
  final File archivoMiniatura;
  final String? urlRemotaPrincipal;
  final String? urlRemotaMiniatura;

  ImagenProcesada({
    required this.archivoPrincipal,
    required this.archivoMiniatura,
    this.urlRemotaPrincipal,
    this.urlRemotaMiniatura,
  });
}

/// Servicio encargado del ciclo de vida de imágenes: compresión en dispositivo,
/// almacenamiento en caché local, cola outbox y sincronización con Supabase Storage (Fase 6).
class ServicioAlmacenamientoImagenes {
  static final ServicioAlmacenamientoImagenes instancia =
      ServicioAlmacenamientoImagenes._();
  ServicioAlmacenamientoImagenes._();

  static const String bucketProductos = 'productos';

  Directory? _mockDirectorio;
  Directory? _directorioCacheMemoria;
  SupabaseClient? _mockClient;

  @visibleForTesting
  void setMockClient(SupabaseClient? client) {
    _mockClient = client;
  }

  @visibleForTesting
  void setMockDirectorio(Directory? dir) {
    _mockDirectorio = dir;
    _directorioCacheMemoria = dir;
  }

  SupabaseClient? get _client => _mockClient ?? ServicioSupabase.instancia.client;

  /// Obtiene o crea el directorio local de almacenamiento en caché para imágenes de plantas
  Future<Directory> obtenerDirectorioImagenesLocal() async {
    if (_mockDirectorio != null) {
      if (!await _mockDirectorio!.exists()) {
        await _mockDirectorio!.create(recursive: true);
      }
      _directorioCacheMemoria = _mockDirectorio;
      return _mockDirectorio!;
    }

    if (_directorioCacheMemoria != null && await _directorioCacheMemoria!.exists()) {
      return _directorioCacheMemoria!;
    }

    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = Directory.systemTemp;
    }
    final dir = Directory(p.join(baseDir.path, 'imagenes_productos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _directorioCacheMemoria = dir;
    return dir;
  }

  /// Retorna la ruta esperada del archivo en el caché local sin bloquear con llamadas de disco
  Future<String> obtenerRutaEsperadaLocal(
    String productoUuid, {
    bool esMiniatura = false,
  }) async {
    final dir = await obtenerDirectorioImagenesLocal();
    final extension = esMiniatura ? '_thumb.webp' : '_principal.webp';
    return p.join(dir.path, '$productoUuid$extension');
  }

  /// Retorna el archivo en caché de forma síncrona si el directorio base ya está resuelto en memoria
  File? obtenerArchivoCacheSincrono(
    String productoUuid, {
    bool esMiniatura = false,
  }) {
    final dir = _mockDirectorio ?? _directorioCacheMemoria;
    if (dir == null) return null;
    final extension = esMiniatura ? '_thumb.webp' : '_principal.webp';
    final archivo = File(p.join(dir.path, '$productoUuid$extension'));
    if (archivo.existsSync() && archivo.lengthSync() > 0) {
      return archivo;
    }
    return null;
  }

  /// Retorna el archivo en caché si existe en el sistema de archivos local
  Future<File?> obtenerArchivoCache(
    String productoUuid, {
    bool esMiniatura = false,
  }) async {
    final sincrono = obtenerArchivoCacheSincrono(productoUuid, esMiniatura: esMiniatura);
    if (sincrono != null) return sincrono;

    final ruta = await obtenerRutaEsperadaLocal(productoUuid, esMiniatura: esMiniatura);
    final archivo = File(ruta);
    if (await archivo.exists() && await archivo.length() > 0) {
      return archivo;
    }
    return null;
  }

  /// Comprime una imagen original local produciendo la versión principal (800-1000px)
  /// y una miniatura (300px) en formato WebP.
  /// Cumple estrictamente el Criterio de Aceptación de la Fase 6.
  Future<ImagenProcesada> procesarYGuardarLocal({
    required File archivoOriginal,
    required String productoUuid,
  }) async {
    final dir = await obtenerDirectorioImagenesLocal();
    final rutaPrincipal = p.join(dir.path, '${productoUuid}_principal.webp');
    final rutaMiniatura = p.join(dir.path, '${productoUuid}_thumb.webp');

    File principal;
    File miniatura;

    try {
      // 1. Compresión imagen principal: máx 1000px, 80% calidad, formato WebP
      final resultPrincipal = await FlutterImageCompress.compressAndGetFile(
        archivoOriginal.absolute.path,
        rutaPrincipal,
        minWidth: 1000,
        minHeight: 1000,
        quality: 80,
        format: CompressFormat.webp,
      );

      // 2. Compresión miniatura: máx 300px, 75% calidad, formato WebP
      final resultMiniatura = await FlutterImageCompress.compressAndGetFile(
        archivoOriginal.absolute.path,
        rutaMiniatura,
        minWidth: 300,
        minHeight: 300,
        quality: 75,
        format: CompressFormat.webp,
      );

      principal = resultPrincipal != null ? File(resultPrincipal.path) : archivoOriginal;
      miniatura = resultMiniatura != null ? File(resultMiniatura.path) : archivoOriginal;
    } catch (e) {
      debugPrint(
        'Aviso en compresión de imagen ($e). Usando archivo original con copia segura.',
      );
      if (archivoOriginal.path != rutaPrincipal) {
        principal = await archivoOriginal.copy(rutaPrincipal);
      } else {
        principal = archivoOriginal;
      }
      if (archivoOriginal.path != rutaMiniatura) {
        miniatura = await archivoOriginal.copy(rutaMiniatura);
      } else {
        miniatura = archivoOriginal;
      }
    }

    return ImagenProcesada(
      archivoPrincipal: principal,
      archivoMiniatura: miniatura,
    );
  }

  /// Procesa una imagen nueva para un producto: comprime en local (principal y miniatura),
  /// resguarda en el caché local permanente y encola para subida asíncrona a Supabase Storage (Offline-First).
  Future<List<String>> prepararImagenParaProducto({
    required String rutaOriginal,
    required String productoUuid,
  }) async {
    if (rutaOriginal.startsWith('assets/')) {
      return [rutaOriginal];
    }
    if (rutaOriginal.contains('${productoUuid}_principal.webp')) {
      final rutaThumb = await obtenerRutaEsperadaLocal(productoUuid, esMiniatura: true);
      return File(rutaThumb).existsSync()
          ? [rutaOriginal, rutaThumb]
          : [rutaOriginal];
    }
    final file = File(rutaOriginal);
    if (!file.existsSync()) {
      return [rutaOriginal];
    }
    try {
      final procesada = await procesarYGuardarLocal(
        archivoOriginal: file,
        productoUuid: productoUuid,
      );
      await encolarSubida(
        productoUuid: productoUuid,
        rutaPrincipal: procesada.archivoPrincipal.path,
        rutaMiniatura: procesada.archivoMiniatura.path,
      );
      return [
        procesada.archivoPrincipal.path,
        procesada.archivoMiniatura.path,
      ];
    } catch (e) {
      debugPrint('Aviso al preparar imagen de producto: $e');
      return [rutaOriginal];
    }
  }

  /// Sube la imagen principal y su miniatura a Supabase Storage (Bucket 'productos').
  /// Retorna las URLs públicas generadas.
  Future<ImagenProcesada> subirAStorage({
    required File archivoPrincipal,
    required File archivoMiniatura,
    required String productoUuid,
    SupabaseClient? clientOverride,
  }) async {
    final client = clientOverride ?? _client;
    if (client == null) {
      return ImagenProcesada(
        archivoPrincipal: archivoPrincipal,
        archivoMiniatura: archivoMiniatura,
      );
    }

    String? urlPrincipal;
    String? urlMiniatura;

    try {
      final storage = client.storage.from(bucketProductos);

      final pathPrincipal = '$productoUuid/principal.webp';
      await storage.upload(
        pathPrincipal,
        archivoPrincipal,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/webp'),
      );
      urlPrincipal = storage.getPublicUrl(pathPrincipal);

      final pathMiniatura = '$productoUuid/miniatura.webp';
      await storage.upload(
        pathMiniatura,
        archivoMiniatura,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/webp'),
      );
      urlMiniatura = storage.getPublicUrl(pathMiniatura);
    } catch (e) {
      debugPrint('Aviso al subir imagen a Supabase Storage: $e. Permanecerá en caché local.');
    }

    return ImagenProcesada(
      archivoPrincipal: archivoPrincipal,
      archivoMiniatura: archivoMiniatura,
      urlRemotaPrincipal: urlPrincipal,
      urlRemotaMiniatura: urlMiniatura,
    );
  }

  /// Encola una imagen en cola_imagenes para subida asíncrona (Offline-First)
  Future<void> encolarSubida({
    required String productoUuid,
    required String rutaPrincipal,
    required String rutaMiniatura,
  }) async {
    try {
      final db = await BaseDeDatos.instancia.database;
      await db.insert('cola_imagenes', {
        'producto_uuid': productoUuid,
        'ruta_local_principal': rutaPrincipal,
        'ruta_local_miniatura': rutaMiniatura,
        'intentos': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      // Disparar procesamiento silencioso en segundo plano si hay red
      procesarColaSubida().ignore();
    } catch (e) {
      debugPrint('Aviso al encolar imagen en cola_imagenes: $e');
    }
  }

  /// Procesa los elementos pendientes en la cola outbox de imágenes hacia Supabase Storage.
  Future<int> procesarColaSubida({SupabaseClient? clientOverride}) async {
    final client = clientOverride ?? _client;
    if (client == null) {
      return 0; // Modo local puro
    }

    final conectado = await ServicioConectividad.instancia.tieneConexion();
    if (!conectado) {
      return 0; // Sin red, conserva en cola
    }

    final db = await BaseDeDatos.instancia.database;
    final pendientes = await db.query(
      'cola_imagenes',
      orderBy: 'created_at ASC',
      limit: 15,
    );

    if (pendientes.isEmpty) return 0;

    int subidasExitosas = 0;

    for (final item in pendientes) {
      final id = item['id'] as int;
      final productoUuid = item['producto_uuid'] as String;
      final rutaPrincipal = item['ruta_local_principal'] as String;
      final rutaMiniatura = item['ruta_local_miniatura'] as String;
      final intentos = (item['intentos'] as num?)?.toInt() ?? 0;

      final filePrincipal = File(rutaPrincipal);
      final fileMiniatura = File(rutaMiniatura);

      if (!filePrincipal.existsSync()) {
        // Si el archivo físico ya no existe en el almacenamiento, retirar de la cola
        await db.delete('cola_imagenes', where: 'id = ?', whereArgs: [id]);
        continue;
      }

      try {
        final procesada = await subirAStorage(
          archivoPrincipal: filePrincipal,
          archivoMiniatura: fileMiniatura.existsSync() ? fileMiniatura : filePrincipal,
          productoUuid: productoUuid,
          clientOverride: client,
        );

        if (procesada.urlRemotaPrincipal != null) {
          // 1. Actualizar URLs remotas en Supabase tabla productos
          try {
            await client.from('productos').update({
              'imagen_url': procesada.urlRemotaPrincipal,
              'miniatura_url': procesada.urlRemotaMiniatura ?? procesada.urlRemotaPrincipal,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }).eq('uuid', productoUuid);
          } catch (e) {
            debugPrint('Aviso al actualizar URLs remotas del producto: $e');
          }

          // 2. Retirar de la cola outbox
          await db.delete('cola_imagenes', where: 'id = ?', whereArgs: [id]);
          subidasExitosas++;
        } else {
          await db.update(
            'cola_imagenes',
            {
              'intentos': intentos + 1,
              'ultimo_error': 'No se obtuvieron URLs remotas de Storage',
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      } catch (e) {
        await db.update(
          'cola_imagenes',
          {
            'intentos': intentos + 1,
            'ultimo_error': e.toString(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }

    return subidasExitosas;
  }

  /// Descarga una imagen remota y la resguarda en el almacenamiento local para consultas 100% offline
  Future<File?> cachearImagenRemota({
    required String url,
    required String productoUuid,
    bool esMiniatura = false,
  }) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;

    try {
      final dir = await obtenerDirectorioImagenesLocal();
      final extension = esMiniatura ? '_thumb.webp' : '_principal.webp';
      final archivoDestino = File(p.join(dir.path, '$productoUuid$extension'));

      if (await archivoDestino.exists() && await archivoDestino.length() > 0) {
        return archivoDestino;
      }

      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        await archivoDestino.writeAsBytes(bytes);
        return archivoDestino;
      }
    } catch (e) {
      debugPrint('Aviso al cachear imagen remota: $e');
    }
    return null;
  }
}
