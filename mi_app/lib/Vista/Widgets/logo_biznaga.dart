import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../Tema/app_theme.dart';

/// Componente oficial adaptativo para el logotipo vectorial de Biznaga Kíix.
///
/// Evalúa reactivamente el brillo del tema actual mediante la extensión temática
/// [BotanicalThemeColors] o `Theme.of(context).brightness` y conmuta de manera atómica entre:
/// - `assets/images/logo_oscuro.svg` (modo nocturno / oscuro: tonos verde menta botánico)
/// - `assets/images/logo_claro.svg` (modo diurno / claro: tonos verde bosque profundo)
class LogoBiznaga extends StatelessWidget {
  /// Alto explícito del vector SVG
  final double? height;

  /// Ancho explícito del vector SVG
  final double? width;

  /// Atajo cuadrado para dimensionar alto y ancho simultáneamente
  final double? size;

  /// Modo de escalado de la caja
  final BoxFit fit;

  /// Alineación del vector dentro del contenedor
  final AlignmentGeometry alignment;

  /// Etiqueta de accesibilidad para lectores de pantalla
  final String semanticsLabel;

  const LogoBiznaga({
    super.key,
    this.height,
    this.width,
    this.size,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.semanticsLabel = 'Logotipo Oficial Biznaga Kíix',
  });

  /// Ruta al activo vector en modo claro
  static const String assetClaro = 'assets/images/logo_claro.svg';

  /// Ruta al activo vector en modo oscuro
  static const String assetOscuro = 'assets/images/logo_oscuro.svg';

  @override
  Widget build(BuildContext context) {
    final double? w = size ?? width;
    final double? h = size ?? height;

    // Detección declarativa y reactiva mediante BotanicalThemeColors o brillo nativo del contexto
    final botanical = Theme.of(context).extension<BotanicalThemeColors>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark ||
        (botanical != null && botanical.appBackground.computeLuminance() < 0.5);
    final String assetPath = isDark ? assetOscuro : assetClaro;

    return SvgPicture.asset(
      assetPath,
      key: ValueKey<String>(assetPath),
      width: w,
      height: h,
      fit: fit,
      alignment: alignment,
      semanticsLabel: semanticsLabel,
      placeholderBuilder: (BuildContext context) => SizedBox(
        width: w,
        height: h,
        child: const Center(
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
      ),
    );
  }
}

