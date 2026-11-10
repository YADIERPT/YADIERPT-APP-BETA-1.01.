import 'dart:async';
import 'package:flutter/foundation.dart';

/// Utilidad de optimización para demorar la ejecución de funciones de alto costo
/// (como filtrado de catálogos o llamadas a BD) hasta que el usuario termine de escribir.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Programa la ejecución de [action] trascurrido [delay].
  /// Cancela cualquier invocación pendiente anterior.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancela el temporizador activo sin ejecutar la acción.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Retorna verdadero si hay una acción programada pendiente de ejecución.
  bool get isActive => _timer?.isActive ?? false;

  /// Libera recursos.
  void dispose() {
    cancel();
  }
}

