import 'dart:io';
import 'package:flutter/material.dart';

import '../../Modelos/producto.dart';
import '../../Tema/app_theme.dart';
import '../../Tema/app_svg_icons.dart';
import '../../Servicios/servicio_almacenamiento_imagenes.dart';

/// Widget unificado y resiliente para la renderización de imágenes de productos botánicos (Fase 6).
///
/// Principios Offline-First:
/// 1. Prioriza activos locales empaquetados (`assets/`).
/// 2. Prioriza imágenes en caché local en disco (`imagenes_productos/`) para rendimiento instantáneo sin conexión.
/// 3. Si la imagen es una URL remota de Supabase Storage y aún no está en caché, la descarga y
///    resguarda en disco en segundo plano para que las consultas subsecuentes sean 100% offline.
/// 4. Degradación elegante a ícono botánico SVG temático en caso de ausencia de imagen o fallo de red.
class ImagenProductoWidget extends StatelessWidget {
  final Producto? producto;
  final List<String>? imagenes;
  final String? productoUuid;
  final bool esPlanta;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool usarMiniatura;
  final Widget? placeholder;

  const ImagenProductoWidget({
    super.key,
    this.producto,
    this.imagenes,
    this.productoUuid,
    this.esPlanta = true,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.usarMiniatura = true,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> listaImagenes = imagenes ?? producto?.imagenes ?? [];
    final String uuid = productoUuid ?? producto?.uuid ?? '';
    final bool planta = producto != null ? producto!.esPlanta : esPlanta;

    if (listaImagenes.isEmpty || listaImagenes.first.trim().isEmpty) {
      return _envolverConBorde(_construirPlaceholder(planta));
    }

    // Si se solicita miniatura y el producto tiene la versión reducida (índice 1)
    String rutaCandidata = listaImagenes.first.trim();
    if (usarMiniatura && listaImagenes.length > 1 && listaImagenes[1].trim().isNotEmpty) {
      rutaCandidata = listaImagenes[1].trim();
    }

    // 1. Activos locales del bundle (assets/)
    if (rutaCandidata.startsWith('assets/')) {
      return _envolverConBorde(
        Image.asset(
          rutaCandidata,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _construirPlaceholder(planta),
        ),
      );
    }

    // 1b. Consulta rápida síncrona en caché de disco (rendimiento instantáneo 60 FPS)
    if (uuid.isNotEmpty) {
      final archivoSincrono = ServicioAlmacenamientoImagenes.instancia
          .obtenerArchivoCacheSincrono(uuid, esMiniatura: usarMiniatura);
      if (archivoSincrono != null) {
        return _envolverConBorde(
          Image.file(
            archivoSincrono,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _construirPlaceholder(planta),
          ),
        );
      }
    }

    // 2. URLs remotas (Supabase Storage: http:// o https://)
    if (rutaCandidata.startsWith('http://') || rutaCandidata.startsWith('https://')) {
      return _envolverConBorde(
        FutureBuilder<File?>(
          future: ServicioAlmacenamientoImagenes.instancia.obtenerArchivoCache(
            uuid,
            esMiniatura: usarMiniatura,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _construirPlaceholder(planta);
            }

            final archivoCache = snapshot.data;
            if (archivoCache != null && archivoCache.existsSync() && archivoCache.lengthSync() > 0) {
              // Servido directamente desde caché local en disco (Offline-First)
              return Image.file(
                archivoCache,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (_, __, ___) => _construirPlaceholder(planta),
              );
            }

            // Descargar de Supabase Storage y guardar en caché local
            ServicioAlmacenamientoImagenes.instancia.cachearImagenRemota(
              url: rutaCandidata,
              productoUuid: uuid,
              esMiniatura: usarMiniatura,
            ).ignore();

            return Image.network(
              rutaCandidata,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => _construirPlaceholder(planta),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    }

    // 3. Archivo local en almacenamiento del dispositivo
    final archivoLocal = File(rutaCandidata);
    if (archivoLocal.existsSync() && archivoLocal.lengthSync() > 0) {
      return _envolverConBorde(
        Image.file(
          archivoLocal,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _construirPlaceholder(planta),
        ),
      );
    }

    // Fallback de contingencia: consultar caché por UUID
    return _envolverConBorde(
      FutureBuilder<File?>(
        future: ServicioAlmacenamientoImagenes.instancia.obtenerArchivoCache(
          uuid,
          esMiniatura: usarMiniatura,
        ),
        builder: (context, snapshot) {
          final archivo = snapshot.data;
          if (archivo != null && archivo.existsSync() && archivo.lengthSync() > 0) {
            return Image.file(
              archivo,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => _construirPlaceholder(planta),
            );
          }
          return _construirPlaceholder(planta);
        },
      ),
    );
  }

  Widget _envolverConBorde(Widget child) {
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }
    return child;
  }

  Widget _construirPlaceholder(bool esPlanta) {
    if (placeholder != null) return placeholder!;

    return Container(
      width: width,
      height: height,
      color: AppColors.secondarySurface,
      child: Center(
        child: SvgIconWidget(
          esPlanta ? AppSvgIcons.planta : AppSvgIcons.articulo,
          size: 32,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
