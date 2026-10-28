import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppSvgIcons {
  // Hoja / Planta botánica
  static const String planta = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 22v-8"/>
  <path d="M12 14c-4.418 0-8-3.582-8-8 4.418 0 8 3.582 8 8z"/>
  <path d="M12 14c0-4.418 3.582-8 8-8 0 4.418-3.582 8-8 8z"/>
</svg>
''';

  // Maceta / Artículo de vivero
  static const String articulo = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M5 4h14l-1.5 12.5a2 2 0 0 1-2 1.5H8.5a2 2 0 0 1-2-1.5L5 4z"/>
  <path d="M3 4h18v2H3z"/>
  <path d="M9 18v2a1 1 0 0 0 1 1h4a1 1 0 0 0 1-1v-2"/>
</svg>
''';

  // Alerta Crítica (Triángulo con exclamación)
  static const String alertaCritica = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/>
  <line x1="12" y1="9" x2="12" y2="13"/>
  <line x1="12" y1="17" x2="12.01" y2="17"/>
</svg>
''';

  // Alerta Moderada / Reloj de reorden
  static const String alertaModerada = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="12" r="10"/>
  <polyline points="12 6 12 12 16 14"/>
</svg>
''';

  // Destellos IA / Asistente inteligente
  static const String iaChispas = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/>
  <path d="M5 3v4"/>
  <path d="M19 17v4"/>
  <path d="M3 5h4"/>
  <path d="M17 19h4"/>
</svg>
''';

  // Tendencia al alza
  static const String tendenciaAlza = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/>
  <polyline points="17 6 23 6 23 12"/>
</svg>
''';

  // Baja rotación / Reloj de arena
  static const String bajaRotacion = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M5 22h14"/>
  <path d="M5 2h14"/>
  <path d="M17 22v-4.172a2 2 0 0 0-.586-1.414L12 12l-4.414 4.414A2 2 0 0 0 7 17.828V22"/>
  <path d="M7 2v4.172a2 2 0 0 0 .586 1.414L12 12l4.414-4.414A2 2 0 0 0 17 6.172V2"/>
</svg>
''';

  // Checkmark verificado
  static const String check = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
  <polyline points="20 6 9 17 4 12"/>
</svg>
''';

  // Carrito de compras / Reorden
  static const String carrito = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="8" cy="21" r="1"/>
  <circle cx="19" cy="21" r="1"/>
  <path d="M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57l1.65-7.43H5.12"/>
</svg>
''';

  // Camión de abastecimiento / Proveedor
  static const String camionEnvio = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <rect x="1" y="3" width="15" height="13"/>
  <polygon points="16 8 20 8 23 11 23 16 16 16 16 8"/>
  <circle cx="5.5" cy="18.5" r="2.5"/>
  <circle cx="18.5" cy="18.5" r="2.5"/>
</svg>
''';

  // Monedas / Inversión y ganancia
  static const String monedas = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="8" cy="8" r="7"/>
  <path d="M19.5 9.5a7 7 0 0 1 0 10"/>
  <path d="M8 5v6"/>
  <path d="M6 7h4"/>
  <path d="M6 9h4"/>
</svg>
''';

  // Papelera / Descartar
  static const String papelera = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <polyline points="3 6 5 6 21 6"/>
  <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
</svg>
''';
}

/// Widget reutilizable para pintar íconos vectoriales SVG limpios y nítidos.
class SvgIconWidget extends StatelessWidget {
  final String svgString;
  final double size;
  final Color? color;

  const SvgIconWidget(
    this.svgString, {
    super.key,
    this.size = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      svgString,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
