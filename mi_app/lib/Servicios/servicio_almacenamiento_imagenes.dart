import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
/// almacenamiento en caché local y sincronización con Supabase Storage.
class ServicioAlmacenamientoImagenes {
  static final ServicioAlmacenamientoImagenes instancia =
      ServicioAlmacenamientoImagenes._();
  ServicioAlmacenamientoImagenes._();

  static const String bucketProductos = 'productos';

  /// Obtiene o crea el directorio local de almacenamiento en caché para imágenes de plantas
  Future<Directory> obtenerDirectorioImagenesLocal() async {
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
    return dir;
  }

  /// Comprime una imagen original local produciendo la versión principal (800-1000px)
  /// y una miniatura (300px) en formato WebP o JPEG.
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
      debugPrint('Aviso en compresión de imagen ($e). Usando archivo original con copia segura.');
      principal = await archivoOriginal.copy(rutaPrincipal);
      miniatura = await archivoOriginal.copy(rutaMiniatura);
    }

    return ImagenProcesada(
      archivoPrincipal: principal,
      archivoMiniatura: miniatura,
    );
  }

  /// Sube la imagen principal y su miniatura a Supabase Storage (Bucket 'productos').
  /// Retorna las URLs públicas o firmadas resultantes.
  Future<ImagenProcesada> subirAStorage({
    required File archivoPrincipal,
    required File archivoMiniatura,
    required String productoUuid,
  }) async {
    final client = ServicioSupabase.instancia.client;
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
}
