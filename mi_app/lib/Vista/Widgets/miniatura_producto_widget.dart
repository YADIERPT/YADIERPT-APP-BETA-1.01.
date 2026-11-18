import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../Modelos/producto.dart';
import '../../Tema/app_theme.dart';
import '../../Tema/app_svg_icons.dart';

/// Componente unificado y de alto rendimiento para renderizar miniaturas de productos.
///
/// Previene condiciones de "Out of Memory" (OOM) y caídas de frames (Jank) aplicando:
/// 1. Decodificación restringida en heap a resolución miniatura (150px) mediante
///    `cacheWidth` y `cacheHeight` en imágenes locales y `memCacheWidth` / `memCacheHeight`
///    en `CachedNetworkImage`.
/// 2. Lectura de disco desacoplada del hilo de UI mediante `FutureBuilder` y `File.exists()`.
/// 3. Persistencia en caché local de URLs remotas (Supabase Storage) con `CachedNetworkImage`.
/// 4. Placeholder limpio con ícono botánico SVG mientras la imagen se resuelve de forma asíncrona.
class MiniaturaProductoWidget extends StatelessWidget {
  final Producto? producto;
  final String? rutaImagen;
  final bool esPlanta;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final int cacheWidth;
  final int cacheHeight;
  final Widget? placeholder;

  const MiniaturaProductoWidget({
    super.key,
    this.producto,
    this.rutaImagen,
    this.esPlanta = true,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.cacheWidth = 150,
    this.cacheHeight = 150,
    this.placeholder,
  });

  String? _resolverRuta() {
    if (rutaImagen != null && rutaImagen!.trim().isNotEmpty) {
      return rutaImagen!.trim();
    }
    if (producto != null && producto!.imagenes.isNotEmpty) {
      // Si el producto cuenta con miniatura generada en índice 1, priorizarla
      if (producto!.imagenes.length > 1 && producto!.imagenes[1].trim().isNotEmpty) {
        return producto!.imagenes[1].trim();
      }
      final primera = producto!.imagenes.first.trim();
      if (primera.isNotEmpty) return primera;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ruta = _resolverRuta();
    if (ruta == null || ruta.isEmpty) {
      return _envolverBorde(_buildPlaceholder(context));
    }

    // 1. Activo empaquetado local (assets/)
    if (ruta.startsWith('assets/')) {
      return _envolverBorde(
        Image.asset(
          ruta,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
        ),
      );
    }

    // 2. URL remota de Supabase Storage / Web (con caché en disco y decodificación limitada a 150px)
    if (ruta.startsWith('http://') || ruta.startsWith('https://')) {
      return _envolverBorde(
        CachedNetworkImage(
          imageUrl: ruta,
          width: width,
          height: height,
          fit: fit,
          memCacheWidth: cacheWidth,
          memCacheHeight: cacheHeight,
          maxWidthDiskCache: 600,
          maxHeightDiskCache: 600,
          placeholder: (context, url) => _buildPlaceholder(context, cargando: true),
          errorWidget: (context, url, error) => _buildPlaceholder(context),
        ),
      );
    }

    // 3. Archivo local en almacenamiento (con verificación asíncrona y límite de resolución de decodificación)
    final file = File(ruta);
    return _envolverBorde(
      FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildPlaceholder(context, cargando: true);
          }
          if (snapshot.hasData && snapshot.data == true) {
            return Image.file(
              file,
              width: width,
              height: height,
              fit: fit,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
            );
          }
          return _buildPlaceholder(context);
        },
      ),
    );
  }

  Widget _envolverBorde(Widget child) {
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }
    return child;
  }

  Widget _buildPlaceholder(BuildContext context, {bool cargando = false}) {
    if (placeholder != null) return placeholder!;

    final bool planta = producto?.esPlanta ?? esPlanta;
    final double iconSize = (width != null && width! < 45) ? 18.0 : 26.0;

    return Container(
      width: width,
      height: height,
      color: AppColors.secondarySurface,
      alignment: Alignment.center,
      child: cargando
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            )
          : SvgIconWidget(
              planta ? AppSvgIcons.planta : AppSvgIcons.articulo,
              size: iconSize,
              color: AppColors.primary,
            ),
    );
  }
}

