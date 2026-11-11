import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Servicio centralizado de retroalimentación física (háptica) y auditiva (sonidos).
///
/// Todas las acciones verifican las preferencias globales de usuario
/// ([sonidoHabilitado] y [vibracionHabilitada]) antes de ejecutarse.
class MotorFeedback {
  MotorFeedback._();

  static const String rutaBeep = 'sounds/beep.mp3';
  static const String rutaError = 'sounds/error.mp3';

  static bool _sonidoHabilitado = true;
  static bool _vibracionHabilitada = true;

  /// Notificador reactivo para sincronizar widgets de preferencias cuando
  /// cambian los interruptores globales.
  static final ValueNotifier<int> preferenciasNotifier = ValueNotifier<int>(0);

  static AudioPlayer? _reproductor;

  /// Hook opcional exclusivo para pruebas unitarias y de widgets.
  @visibleForTesting
  static Future<void> Function(String rutaAsset)? reproductorPruebas;

  /// Preferencia global actual para reproducción de efectos sonoros.
  static bool get sonidoHabilitado => _sonidoHabilitado;
  static set sonidoHabilitado(bool valor) {
    if (_sonidoHabilitado == valor) return;
    _sonidoHabilitado = valor;
    preferenciasNotifier.value++;
  }

  /// Preferencia global actual para retroalimentación háptica del sistema.
  static bool get vibracionHabilitada => _vibracionHabilitada;
  static set vibracionHabilitada(bool valor) {
    if (_vibracionHabilitada == valor) return;
    _vibracionHabilitada = valor;
    preferenciasNotifier.value++;
  }

  /// Sincroniza en memoria ambas preferencias desde la configuración persistida.
  static void sincronizarPreferencias({
    required bool sonidoHabilitado,
    required bool vibracionHabilitada,
  }) {
    final huboCambio = _sonidoHabilitado != sonidoHabilitado ||
        _vibracionHabilitada != vibracionHabilitada;
    _sonidoHabilitado = sonidoHabilitado;
    _vibracionHabilitada = vibracionHabilitada;
    if (huboCambio) {
      preferenciasNotifier.value++;
    }
  }

  /// Ejecuta una vibración sutil (impacto ligero) si [vibracionHabilitada] es `true`.
  static Future<void> vibracionLigera() async {
    if (!vibracionHabilitada) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Ejecuta una vibración intermedia si [vibracionHabilitada] es `true`.
  static Future<void> vibracionMedia() async {
    if (!vibracionHabilitada) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Ejecuta una vibración pronunciada (impacto fuerte) si [vibracionHabilitada] es `true`.
  static Future<void> vibracionFuerte() async {
    if (!vibracionHabilitada) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Reproduce un pulso táctil de selección si [vibracionHabilitada] es `true`.
  static Future<void> seleccion() async {
    if (!vibracionHabilitada) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Reproduce `assets/sounds/beep.mp3` (éxito / añadir) si [sonidoHabilitado] es `true`.
  static Future<void> reproducirBeep() => _reproducirAsset(rutaBeep);

  /// Reproduce `assets/sounds/error.mp3` (alerta / error) si [sonidoHabilitado] es `true`.
  static Future<void> reproducirError() => _reproducirAsset(rutaError);

  /// Combina vibración + sonido de éxito respetando cada interruptor de forma independiente.
  static Future<void> feedbackExito({bool fuerte = false}) async {
    await (fuerte ? vibracionFuerte() : vibracionLigera());
    await reproducirBeep();
  }

  /// Combina vibración fuerte + sonido de error respetando cada interruptor de forma independiente.
  static Future<void> feedbackError() async {
    await vibracionFuerte();
    await reproducirError();
  }

  static Future<void> _reproducirAsset(String rutaAsset) async {
    if (!sonidoHabilitado) return;
    final callbackPrueba = reproductorPruebas;
    if (callbackPrueba != null) {
      await callbackPrueba(rutaAsset);
      return;
    }
    try {
      final player = _reproductor ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource(rutaAsset));
    } catch (_) {
      // Evita interrumpir el flujo si el entorno (p. ej. pruebas sin canal nativo) no soporta audio.
    }
  }

  /// Restaura los valores por defecto y limpia recursos de audio en pruebas.
  @visibleForTesting
  static Future<void> restablecerParaPruebas() async {
    reproductorPruebas = null;
    _sonidoHabilitado = true;
    _vibracionHabilitada = true;
    preferenciasNotifier.value++;
    try {
      await _reproductor?.dispose();
    } catch (_) {}
    _reproductor = null;
  }
}

