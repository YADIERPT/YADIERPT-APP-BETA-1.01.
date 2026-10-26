import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'servicio_permisos.dart';
import '../Vista/camara_vista.dart';

/// Servicio centralizado para captura y selección de imágenes.
/// Previene fallos por OutOfMemory (OOM), excepciones no controladas de la cámara
/// y recupera datos perdidos en caso de destrucción de la Activity en Android.
class ServicioImagen {
  ServicioImagen._();
  static final ServicioImagen instancia = ServicioImagen._();

  final ImagePicker _picker = ImagePicker();

  /// Captura una foto desde la cámara de manera segura.
  /// En Android/iOS abre una pantalla interna de cámara (CamaraVista) para evitar que
  /// el sistema operativo suspenda la app o la destruya por falta de memoria.
  Future<String?> tomarFoto({
    BuildContext? context,
    int quality = 80,
    double maxWidth = 1200,
    double maxHeight = 1200,
  }) async {
    final bool permitido =
        await ServicioPermisos.instancia.solicitarPermisoCamara(context: context);
    if (!permitido) return null;

    // En dispositivos móviles se utiliza la cámara interna integrada (CamaraVista)
    // para evitar que el sistema operativo mate la app o provoque pantalla negra.
    if (context != null && context.mounted && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final String? ruta = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => const CamaraVista(),
          ),
        );
        if (ruta != null && ruta.isNotEmpty) {
          final file = File(ruta);
          if (await file.exists() && await file.length() > 0) {
            return ruta;
          }
        }
        return null;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Fallback a ImagePicker tras excepción en CamaraVista: $e');
        }
      }
    }

    return _obtenerImagen(
      source: ImageSource.camera,
      quality: quality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  /// Selecciona una foto desde la galería local del dispositivo.
  /// Solicita previamente los permisos de almacenamiento/fotos al usuario.
  Future<String?> seleccionarDeGaleria({
    BuildContext? context,
    int quality = 80,
    double maxWidth = 1200,
    double maxHeight = 1200,
  }) async {
    final bool permitido =
        await ServicioPermisos.instancia.solicitarPermisoGaleria(context: context);
    if (!permitido) return null;

    return _obtenerImagen(
      source: ImageSource.gallery,
      quality: quality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  Future<String?> _obtenerImagen({
    required ImageSource source,
    required int quality,
    required double maxWidth,
    required double maxHeight,
  }) async {
    try {
      // Breve pausa asíncrona para que Flutter termine de desmontar cualquier diálogo
      // o bottom-sheet antes de transferir el foco a la Activity nativa.
      await Future.delayed(const Duration(milliseconds: 120));

      final XFile? imagen = await _picker.pickImage(
        source: source,
        imageQuality: quality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      if (imagen != null && imagen.path.isNotEmpty) {
        final file = File(imagen.path);
        if (await file.exists() && await file.length() > 0) {
          return imagen.path;
        }
      }
    } catch (e, stack) {
      if (kDebugMode && e.runtimeType.toString() != 'MissingPluginException') {
        debugPrint('Error en ServicioImagen._obtenerImagen ($source): $e\n$stack');
      }
    }
    return null;
  }

  /// Recupera imágenes que quedaron pendientes si el sistema operativo Android
  /// destruyó la Activity de Flutter mientras la cámara estaba abierta.
  Future<String?> recuperarImagenPerdida() async {
    try {
      final LostDataResponse respuesta = await _picker.retrieveLostData();
      if (respuesta.isEmpty) {
        return null;
      }
      if (respuesta.file != null && respuesta.file!.path.isNotEmpty) {
        final file = File(respuesta.file!.path);
        if (await file.exists() && await file.length() > 0) {
          return respuesta.file!.path;
        }
      }
    } catch (e, stack) {
      if (kDebugMode && e.runtimeType.toString() != 'MissingPluginException') {
        debugPrint('Error en ServicioImagen.recuperarImagenPerdida: $e\n$stack');
      }
    }
    return null;
  }
}
