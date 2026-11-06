import 'package:flutter/material.dart';
import '../../Tema/app_theme.dart';

/// Variantes de visualización del logotipo de la aplicación.
enum AppLogoVariant {
  /// Modo compacto para encabezados, AppBar o barras de navegación (32x32 a 40x40).
  compact,

  /// Modo centrado y destacado para Splash Screen, pantalla de inicio y autenticación (Login).
  splash,
}

/// Widget modular y reutilizable para el logotipo de Planteapp / Biznaga Kíix.
/// Diseñado con soporte nativo para Modo Oscuro (tonos no saturados y descansados),
/// y blindado contra desbordamientos visuales (Layout Overflow).
class AppLogo extends StatelessWidget {
  final AppLogoVariant variant;
  final double size;
  final bool showAppName;
  final String appName;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Constructor general
  const AppLogo({
    super.key,
    this.variant = AppLogoVariant.compact,
    this.size = 36.0,
    this.showAppName = false,
    this.appName = 'Planteapp',
    this.subtitle,
    this.onTap,
  });

  /// Constructor optimizado para la esquina superior izquierda (AppBar / Barra de navegación)
  const AppLogo.compact({
    super.key,
    this.size = 36.0,
    this.showAppName = false,
    this.appName = 'Planteapp',
    this.subtitle,
    this.onTap,
  }) : variant = AppLogoVariant.compact;

  /// Constructor optimizado para la pantalla de bienvenida / Login / Splash
  const AppLogo.splash({
    super.key,
    this.size = 104.0,
    this.showAppName = true,
    this.appName = 'Planteapp',
    this.subtitle = 'Terminal de Punto de Venta • Iniciar Sesión',
    this.onTap,
  }) : variant = AppLogoVariant.splash;

  /// Rutas de activos declaradas en pubspec.yaml
  static const String assetEmblem = 'assets/images/logo_emblem.jpg';
  static const String assetLogoFull = 'assets/images/logo.jpg';

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark;

    if (variant == AppLogoVariant.compact) {
      return _buildCompactHeader(context, isDark);
    } else {
      return _buildSplash(context, isDark);
    }
  }

  /// Construye el logotipo para la barra superior / AppBar asegurando que no se desborde
  Widget _buildCompactHeader(BuildContext context, bool isDark) {
    final badge = _buildEmblemBadge(
      badgeSize: size,
      isDark: isDark,
      useFullLogo: false,
      padding: EdgeInsets.all(size * 0.08),
    );

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        badge,
        if (showAppName) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ],
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size * 0.3),
        child: content,
      );
    }

    return content;
  }

  /// Construye el logotipo centrado para la pantalla de inicio y Login
  Widget _buildSplash(BuildContext context, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Emblema principal con contenedor relajado para modo oscuro
        _buildEmblemBadge(
          badgeSize: size,
          isDark: isDark,
          useFullLogo: false,
          padding: EdgeInsets.all(size * 0.06),
          hasShadow: true,
        ),
        if (showAppName) ...[
          const SizedBox(height: 16),
          Text(
            appName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  /// Genera la insignia circular con la imagen, bordes armoniosos y filtro para modo oscuro
  Widget _buildEmblemBadge({
    required double badgeSize,
    required bool isDark,
    required bool useFullLogo,
    required EdgeInsets padding,
    bool hasShadow = false,
  }) {
    // Paleta de fondo y bordes adaptados: tonos orgánicos relajados sin saturación excesiva
    final Color backgroundColor = isDark
        ? const Color(0xFF222B24) // Verde bosque carbón tenue
        : const Color(0xFFF7F4EE); // Blanco marfil orgánico suave

    final Color borderColor = isDark
        ? const Color(0xFF334237) // Borde verde musgo desaturado
        : const Color(0xFFE5DFD4); // Borde cálido sutil

    return Container(
      width: badgeSize,
      height: badgeSize,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: isDark
                      ? const Color(0x59000000)
                      : const Color(0x0F000000),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: isDark
            ? ColorFiltered(
                // Modula suavemente la luminosidad del blanco para que no deslumbre en la noche
                colorFilter: const ColorFilter.mode(
                  Color(0xFFE2E6E2),
                  BlendMode.modulate,
                ),
                child: _buildImage(useFullLogo, badgeSize),
              )
            : _buildImage(useFullLogo, badgeSize),
      ),
    );
  }

  Widget _buildImage(bool useFullLogo, double badgeSize) {
    return Image.asset(
      useFullLogo ? assetLogoFull : assetEmblem,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        // Fallback seguro en caso de que el recurso aún no esté empaquetado
        return Center(
          child: Icon(
            Icons.local_florist_rounded,
            color: AppColors.primary,
            size: badgeSize * 0.5,
          ),
        );
      },
    );
  }
}

