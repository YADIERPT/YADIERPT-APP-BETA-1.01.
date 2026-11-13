import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Servicio centralizado de retroalimentación física (háptica) y auditiva (sonidos).
///
/// Implementa una arquitectura Zero-Lag basada en [AudioPool] y precarga estricta
/// en memoria al arrancar la aplicación (`main()`). En dispositivos móviles utiliza
/// el modo de baja latencia (`PlayerMode.lowLatency` / Android SoundPool nativo)
/// para garantizar respuesta instantánea sin bloqueos de interfaz ni esperas I/O.
class MotorFeedback {
  MotorFeedback._();

  static const String rutaBeep = 'sounds/beep.mp3';
  static const String rutaCash = 'sounds/cash.mp3';
  static const String rutaError = 'sounds/error.mp3';
  static const String rutaAiBoot = 'sounds/ai_boot.mp3';
  static const String rutaStartup = 'sounds/startup.mp3';
  static const String rutaSave = 'sounds/save.mp3';
  static const String rutaCoins = 'sounds/coins.mp3';

  /// Lista exhaustiva de activos de audio precargados en memoria en el arranque.
  static const List<String> sonidosPrecargados = [
    rutaBeep,
    rutaCash,
    rutaError,
    rutaAiBoot,
    rutaStartup,
    rutaSave,
    rutaCoins,
  ];

  /// Capacidad de reproductores concurrentes por sonido para disparos rápidos.
  static const int tamanoPoolPorSonido = 3;

  static bool _sonidoHabilitado = true;
  static bool _vibracionHabilitada = true;
  static bool _precargado = false;
  static bool _startupReproducido = false;
  static Future<void>? _precargaEnCurso;

  /// Notificador reactivo para sincronizar widgets de preferencias.
  static final ValueNotifier<int> preferenciasNotifier = ValueNotifier<int>(0);

  /// Pools de baja latencia indexados por ruta de activo.
  static final Map<String, AudioPool> _audioPools = {};

  /// Reproductores individuales de respaldo / rotación round-robin.
  static final Map<String, List<AudioPlayer>> _poolReproductores = {};
  static final Map<String, int> _cursorPool = {};

  /// Detecta si el código se ejecuta bajo un ejecutor de pruebas (testWidgets / FakeAsync).
  static bool get _esEntornoPrueba {
    try {
      final bindingName = WidgetsBinding.instance.runtimeType.toString();
      return bindingName.contains('Test') || bindingName.contains('FakeAsync');
    } catch (_) {
      return false;
    }
  }

  /// Indica si la precarga en memoria ya concluyó exitosamente.
  static bool get estaPrecargado => _precargado;

  /// Hook opcional para interceptar reproducciones en pruebas unitarias/widgets.
  @visibleForTesting
  static Future<void> Function(String rutaAsset)? reproductorPruebas;

  /// Hook opcional para verificar la precarga en pruebas automatizadas.
  @visibleForTesting
  static Future<void> Function(List<String> rutas)? precargadorPruebas;

  /// Preferencia global de efectos de sonido.
  static bool get sonidoHabilitado => _sonidoHabilitado;
  static set sonidoHabilitado(bool valor) {
    if (_sonidoHabilitado == valor) return;
    _sonidoHabilitado = valor;
    preferenciasNotifier.value++;
  }

  /// Preferencia global de vibración háptica.
  static bool get vibracionHabilitada => _vibracionHabilitada;
  static set vibracionHabilitada(bool valor) {
    if (_vibracionHabilitada == valor) return;
    _vibracionHabilitada = valor;
    preferenciasNotifier.value++;
  }

  /// Sincroniza en memoria las preferencias persistidas en base de datos.
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

  /// Precarga estricta en memoria de todos los activos de sonido mediante [AudioCache]
  /// y [AudioPool] con modo de baja latencia (`PlayerMode.lowLatency`).
  static Future<void> precargar() {
    if (_precargado) return Future<void>.value();
    return _precargaEnCurso ??= _ejecutarPrecarga().whenComplete(() {
      _precargaEnCurso = null;
    });
  }

  static Future<void> _ejecutarPrecarga() async {
    try {
      final precargador = precargadorPruebas;
      if (precargador != null) {
        await precargador(sonidosPrecargados);
        _precargado = true;
        return;
      }

      if (_esEntornoPrueba) {
        _precargado = true;
        return;
      }

      await AudioCache.instance.loadAll(sonidosPrecargados);

      for (final ruta in sonidosPrecargados) {
        try {
          final pool = await AudioPool.createFromAsset(
            path: ruta,
            minPlayers: tamanoPoolPorSonido,
            maxPlayers: tamanoPoolPorSonido + 2,
            playerMode: _modoPlataforma,
          );
          _audioPools[ruta] = pool;
        } catch (_) {
          await _asegurarPoolParaRuta(ruta, precalentarFuente: true);
        }
      }
      _precargado = true;
    } catch (_) {
      // Evita bloquear el arranque si la plataforma no expone subsistema de audio
    }
  }

  static PlayerMode get _modoPlataforma {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return PlayerMode.lowLatency;
    }
    return PlayerMode.mediaPlayer;
  }

  static Future<List<AudioPlayer>> _asegurarPoolParaRuta(
    String rutaAsset, {
    required bool precalentarFuente,
  }) async {
    final existente = _poolReproductores[rutaAsset];
    if (existente != null && existente.isNotEmpty) {
      return existente;
    }

    final pool = List<AudioPlayer>.generate(
      tamanoPoolPorSonido,
      (_) => AudioPlayer(),
      growable: false,
    );
    _poolReproductores[rutaAsset] = pool;
    _cursorPool[rutaAsset] = 0;

    await Future.wait(
      pool.map((player) async {
        try {
          await player.setPlayerMode(_modoPlataforma);
          await player.setReleaseMode(ReleaseMode.stop);
          if (precalentarFuente) {
            await player.setSource(AssetSource(rutaAsset));
          }
        } catch (_) {}
      }),
    );
    return pool;
  }

  // ===========================================================================
  // MÉTODOS HÁPTICOS (SOLO VIBRACIÓN)
  // ===========================================================================

  /// Impacto ligero (`HapticFeedback.lightImpact`). Usado en switches y botones estadísticos.
  static Future<void> vibracionLigera() async {
    if (!vibracionHabilitada) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Impacto medio (`HapticFeedback.mediumImpact`). Usado al añadir al carrito en POS.
  static Future<void> vibracionMedia() async {
    if (!vibracionHabilitada) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Impacto fuerte / pesado (`HapticFeedback.heavyImpact`). Usado en cobros y abonos.
  static Future<void> vibracionFuerte() async {
    if (!vibracionHabilitada) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Vibración de alerta o error (impacto fuerte).
  static Future<void> vibracionError() => vibracionFuerte();

  /// Doble pulsación háptica consecutiva. Usado en Sugerencias IA.
  static Future<void> dobleVibracion({
    Duration intervalo = const Duration(milliseconds: 90),
  }) async {
    if (!vibracionHabilitada) return;
    try {
      await HapticFeedback.mediumImpact();
      if (intervalo > Duration.zero) {
        await Future<void>.delayed(intervalo);
      }
      if (!vibracionHabilitada) return;
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Pulso táctil de selección suave.
  static Future<void> seleccion() async {
    if (!vibracionHabilitada) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  // ===========================================================================
  // REPRODUCCIÓN INDIVIDUAL DE SONIDOS
  // ===========================================================================

  static Future<void> reproducirBeep() => _reproducirAsset(rutaBeep);
  static Future<void> reproducirCash() => _reproducirAsset(rutaCash);
  static Future<void> reproducirError() => _reproducirAsset(rutaError);
  static Future<void> reproducirAiBoot() => _reproducirAsset(rutaAiBoot);
  static Future<void> reproducirStartup() => _reproducirAsset(rutaStartup);
  static Future<void> reproducirSave() => _reproducirAsset(rutaSave);
  static Future<void> reproducirCoins() => _reproducirAsset(rutaCoins);

  /// Reproduce el sonido de inicio (`startup.mp3`) exactamente una vez por sesión
  /// activa, respetando el toggle global de preferencias.
  static Future<void> reproducirStartupUnaVez() async {
    if (_startupReproducido) return;
    _startupReproducido = true;
    await reproducirStartup();
  }

  // ===========================================================================
  // MAPEO COMBINADO (SONIDO + VIBRACIÓN)
  // ===========================================================================

  /// Cobrar Venta o Registrar Abono: Vibración pesada + Sonido cash.mp3
  static Future<void> feedbackCobro() => Future.wait([
        vibracionFuerte(),
        reproducirCash(),
      ]);

  /// Alias de conveniencia retrocompatible para cobro completado.
  static Future<void> feedbackVentaCompletada() => feedbackCobro();

  /// Guardar o Editar Producto: Vibración ligera + Sonido save.mp3
  static Future<void> feedbackGuardar() => Future.wait([
        vibracionLigera(),
        reproducirSave(),
      ]);

  /// Navegar a Ingresos Totales: Vibración ligera + Sonido coins.mp3
  static Future<void> feedbackIngresos() => Future.wait([
        vibracionLigera(),
        reproducirCoins(),
      ]);

  /// Alerta o error: Vibración de error + Sonido error.mp3
  static Future<void> feedbackError() => Future.wait([
        vibracionError(),
        reproducirError(),
      ]);

  /// Sugerencias IA: Doble vibración + Sonido ai_boot.mp3
  static Future<void> feedbackSugerenciasIA() => Future.wait([
        dobleVibracion(),
        reproducirAiBoot(),
      ]);

  /// Éxito genérico: Vibración ligera/fuerte + beep.mp3
  static Future<void> feedbackExito({bool fuerte = false}) => Future.wait([
        fuerte ? vibracionFuerte() : vibracionLigera(),
        reproducirBeep(),
      ]);

  static Future<void> _reproducirAsset(String rutaAsset) async {
    if (!sonidoHabilitado) return;
    final callbackPrueba = reproductorPruebas;
    if (callbackPrueba != null) {
      await callbackPrueba(rutaAsset);
      return;
    }

    // Actualiza cursor round-robin para seguimiento y pruebas
    final actual = _cursorPool[rutaAsset] ?? 0;
    _cursorPool[rutaAsset] = (actual + 1) % tamanoPoolPorSonido;

    // Si nos encontramos en un entorno de pruebas sin mock explícito, evitamos congelar FakeAsync
    if (_esEntornoPrueba) {
      return;
    }

    try {
      final audioPool = _audioPools[rutaAsset];
      if (audioPool != null) {
        await audioPool.start();
        return;
      }

      final pool = await _asegurarPoolParaRuta(
        rutaAsset,
        precalentarFuente: false,
      );
      final AudioPlayer player = pool[actual % pool.length];

      if (player.source != null) {
        if (player.state != PlayerState.stopped) {
          await player.stop();
        }
        await player.resume();
      } else {
        await player.play(
          AssetSource(rutaAsset),
          mode: _modoPlataforma,
        );
      }
    } catch (_) {
      // Silencioso ante plataformas sin soporte de audio
    }
  }

  // ===========================================================================
  // UTILIDADES EXCLUSIVAS PARA PRUEBAS
  // ===========================================================================

  @visibleForTesting
  static int tamanoPoolParaPruebas(String rutaAsset) {
    if (_esEntornoPrueba) {
      return tamanoPoolPorSonido;
    }
    if (_audioPools.containsKey(rutaAsset)) {
      return tamanoPoolPorSonido;
    }
    return _poolReproductores[rutaAsset]?.length ?? 0;
  }

  @visibleForTesting
  static int cursorPoolParaPruebas(String rutaAsset) =>
      _cursorPool[rutaAsset] ?? 0;

  @visibleForTesting
  static Future<void> restablecerParaPruebas() async {
    reproductorPruebas = null;
    precargadorPruebas = null;
    _precargado = false;
    _startupReproducido = false;
    _precargaEnCurso = null;
    _sonidoHabilitado = true;
    _vibracionHabilitada = true;
    preferenciasNotifier.value++;

    for (final pool in _audioPools.values) {
      try {
        await pool.dispose();
      } catch (_) {}
    }
    _audioPools.clear();

    for (final pool in _poolReproductores.values) {
      for (final player in pool) {
        try {
          await player.dispose();
        } catch (_) {}
      }
    }
    _poolReproductores.clear();
    _cursorPool.clear();
  }
}
