import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../Constantes/limites.dart';

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

  /// Sanitiza una cadena numérica eliminando comas de miles y espacios antes de convertirla a double.
  ///
  /// Evita FormatException cuando un TextField contiene números formateados como "18,805.50".
  ///
  /// Ejemplo:
  /// ```dart
  /// Formateador.parsearMoneda("18,805.50") // -> 18805.50
  /// ```
  static double parsearMoneda(String? texto, {double valorPorDefecto = 0.0}) {
    if (texto == null || texto.trim().isEmpty) return valorPorDefecto;
    final String limpio = texto.replaceAll(',', '').trim();
    return double.tryParse(limpio) ?? valorPorDefecto;
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

/// Formateador de texto dinámico para campos monetarios que aplica separación
/// de miles con coma (,) en tiempo real conforme el usuario escribe, permitiendo
/// hasta 2 posiciones decimales y conservando la posición correcta del cursor.
class FormateadorMilesMonetario extends TextInputFormatter {
  final double? max;
  static final NumberFormat _formatter = NumberFormat('#,##0', 'en_US');

  FormateadorMilesMonetario({this.max = LimitesApp.maxMontoMonetario});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    TextEditingValue valorModificado = newValue;

    // Si el usuario intentó borrar una coma con Backspace, eliminamos el dígito previo a la coma
    if (oldValue.text.length - newValue.text.length == 1 &&
        oldValue.selection.baseOffset > 0 &&
        oldValue.selection.baseOffset <= oldValue.text.length &&
        oldValue.text[oldValue.selection.baseOffset - 1] == ',') {
      final int posBorrar = oldValue.selection.baseOffset - 2;
      if (posBorrar >= 0) {
        final String textoAjustado = oldValue.text.substring(0, posBorrar) +
            oldValue.text.substring(posBorrar + 1);
        final int cursorAjustado = posBorrar;
        valorModificado = TextEditingValue(
          text: textoAjustado,
          selection: TextSelection.collapsed(offset: cursorAjustado),
        );
      }
    }

    // Normalizar comas a fin de validar los caracteres numéricos
    String clean = valorModificado.text.replaceAll(',', '').trim();
    if (clean.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Si escribe solo el punto decimal, asistimos completando a '0.'
    if (clean == '.') {
      return const TextEditingValue(
        text: '0.',
        selection: TextSelection.collapsed(offset: 2),
      );
    }

    // Validar: solo dígitos y máximo un punto con hasta 2 decimales
    final regex = RegExp(r'^\d*(\.\d{0,2})?$');
    if (!regex.hasMatch(clean)) {
      return oldValue;
    }

    // Validar límite superior si aplica
    final double? valorNumerico = double.tryParse(clean);
    if (valorNumerico != null && max != null && valorNumerico > max!) {
      return oldValue;
    }

    // Separar en parte entera y parte decimal
    final bool tienePunto = clean.contains('.');
    final List<String> partes = clean.split('.');
    final String parteEntera = partes[0];
    final String parteDecimal = partes.length > 1 ? partes[1] : '';

    String enteraFormateada = '';
    if (parteEntera.isNotEmpty) {
      final int? numEntero = int.tryParse(parteEntera);
      if (numEntero != null) {
        enteraFormateada = _formatter.format(numEntero);
      } else {
        enteraFormateada = parteEntera;
      }
    } else if (tienePunto) {
      enteraFormateada = '0';
    }

    final String textoFormateado =
        tienePunto ? '$enteraFormateada.$parteDecimal' : enteraFormateada;

    // Calcular la posición exacta del cursor compensando las comas insertadas
    final int rawOffset = valorModificado.selection.baseOffset;
    int digitosPrevios = 0;
    for (int i = 0; i < rawOffset && i < valorModificado.text.length; i++) {
      if (valorModificado.text[i] != ',') {
        digitosPrevios++;
      }
    }

    int nuevoCursor = 0;
    int digitosContados = 0;
    while (nuevoCursor < textoFormateado.length && digitosContados < digitosPrevios) {
      if (textoFormateado[nuevoCursor] != ',') {
        digitosContados++;
      }
      nuevoCursor++;
    }

    return TextEditingValue(
      text: textoFormateado,
      selection: TextSelection.collapsed(offset: nuevoCursor),
    );
  }
}

/// Alias alternativo para compatibilidad y semántica técnica
typedef CustomCurrencyFormatter = FormateadorMilesMonetario;


