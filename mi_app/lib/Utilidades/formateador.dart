import 'package:intl/intl.dart';

/// Helper centralizado y extensiones para estandarizar el formato numérico y monetario en Planteapp.
///
/// Garantiza que en cualquier dispositivo y sin importar el idioma del sistema operativo:
/// - Los millares se separen con coma (`,`).
/// - Los decimales se separen con punto (`.`).
/// - Las cantidades de dinero incluyan exactamente dos decimales (ej. `$ 1,500.50`).
class Formateador {
  // NumberFormat con locale estricto 'en_US' para garantizar coma (,) en miles y punto (.) en decimales
  static final NumberFormat _formatoDecimal = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _formatoEntero = NumberFormat('#,##0', 'en_US');

  /// Formatea una cantidad como moneda con dos decimales y separador de miles.
  ///
  /// Ejemplo:
  /// ```dart
  /// Formateador.moneda(1500.5) // -> "$ 1,500.50"
  /// Formateador.moneda(1500.5, conEspacio: false) // -> "$1,500.50"
  /// ```
  static String moneda(num? cantidad, {String simbolo = r'$', bool conEspacio = false}) {
    final double valor = (cantidad ?? 0.0).toDouble();
    final String numeroFormateado = _formatoDecimal.format(valor);
    return conEspacio ? '$simbolo $numeroFormateado' : '$simbolo$numeroFormateado';
  }

  /// Formatea un número con coma de miles y punto decimal, sin símbolo monetario.
  ///
  /// Ejemplo:
  /// ```dart
  /// Formateador.numero(12500.75) // -> "12,500.75"
  /// ```
  static String numero(num? cantidad) {
    final double valor = (cantidad ?? 0.0).toDouble();
    return _formatoDecimal.format(valor);
  }

  /// Formatea números enteros (stock, inventario, conteo de ventas) con separador de miles.
  ///
  /// Ejemplo:
  /// ```dart
  /// Formateador.entero(1250) // -> "1,250"
  /// ```
  static String entero(num? cantidad) {
    final int valor = (cantidad ?? 0).toInt();
    return _formatoEntero.format(valor);
  }

  /// Formatea porcentajes con un decimal.
  ///
  /// Ejemplo:
  /// ```dart
  /// Formateador.porcentaje(0.16) // -> "16.0%"
  /// ```
  static String porcentaje(num? valor) {
    final double p = (valor ?? 0.0).toDouble();
    final pct = p <= 1.0 ? p * 100 : p;
    return '${NumberFormat('#,##0.0', 'en_US').format(pct)}%';
  }
}

/// Extensiones de conveniencia sobre [num] para sintaxis fluida y legible en widgets de UI.
extension FormatoMonedaNumExtension on num {
  /// Retorna la cantidad formateada como moneda.
  ///
  /// Ejemplo:
  /// ```dart
  /// 1500.50.aMoneda() // -> "$1,500.50"
  /// 1500.50.aMoneda(conEspacio: true) // -> "$ 1,500.50"
  /// ```
  String aMoneda({String simbolo = r'$', bool conEspacio = false}) {
    return Formateador.moneda(this, simbolo: simbolo, conEspacio: conEspacio);
  }

  /// Retorna el número formateado con miles y decimales sin símbolo.
  ///
  /// Ejemplo:
  /// ```dart
  /// 1500.50.aNumero() // -> "1,500.50"
  /// ```
  String aNumero() {
    return Formateador.numero(this);
  }

  /// Retorna el número entero formateado con miles.
  ///
  /// Ejemplo:
  /// ```dart
  /// 1500.aEntero() // -> "1,500"
  /// ```
  String aEntero() {
    return Formateador.entero(this);
  }
}

/// Extensiones para manejar valores numéricos anulables [num?] de forma segura.
extension FormatoMonedaNullableNumExtension on num? {
  String aMoneda({String simbolo = r'$', bool conEspacio = false}) {
    return Formateador.moneda(this, simbolo: simbolo, conEspacio: conEspacio);
  }

  String aNumero() {
    return Formateador.numero(this);
  }

  String aEntero() {
    return Formateador.entero(this);
  }
}

