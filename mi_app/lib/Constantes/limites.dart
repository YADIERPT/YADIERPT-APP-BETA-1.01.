import 'package:flutter/services.dart';

/// Constantes globales de límites del sistema (montos, unidades, longitud de texto).
class LimitesApp {
  // Longitud de texto
  static const int maxLongitudNombreProducto = 40;

  // Montos monetarios y porcentajes
  static const double maxMontoMonetario = 99999.99;
  static const double maxPorcentajeIva = 100.0;

  // Unidades e inventario
  static const int maxUnidades = 9999;
  static const int maxStockUmbral = 9999;
}

/// Formateador para campos monetarios y con decimales (máximo 2 decimales, no negativos ni letras).
class FormateadorMonetario extends TextInputFormatter {
  final double max;
  FormateadorMonetario({this.max = LimitesApp.maxMontoMonetario});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Normalizar comas a puntos si el usuario las teclea o pega
    String texto = newValue.text.replaceAll(',', '.');

    // Solo permitir dígitos y hasta 2 decimales después del punto
    final regex = RegExp(r'^\d*(\.\d{0,2})?$');
    if (!regex.hasMatch(texto)) {
      return oldValue;
    }

    if (texto == '.') {
      return const TextEditingValue(
        text: '0.',
        selection: TextSelection.collapsed(offset: 2),
      );
    }

    final valor = double.tryParse(texto);
    if (valor == null || valor > max) {
      return oldValue;
    }

    if (texto != newValue.text) {
      return TextEditingValue(
        text: texto,
        selection: TextSelection.collapsed(offset: texto.length),
      );
    }

    return newValue;
  }
}

/// Formateador para campos de unidades enteras (solo dígitos 0-9, sin letras ni negativos).
class FormateadorEntero extends TextInputFormatter {
  final int max;
  FormateadorEntero({this.max = LimitesApp.maxUnidades});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Solo dígitos positivos
    final regex = RegExp(r'^\d+$');
    if (!regex.hasMatch(newValue.text)) {
      return oldValue;
    }

    final valor = int.tryParse(newValue.text);
    if (valor == null || valor > max) {
      return oldValue;
    }

    return newValue;
  }
}
