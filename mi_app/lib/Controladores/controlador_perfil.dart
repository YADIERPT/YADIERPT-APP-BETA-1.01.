import '../Modelos/configuracion.dart';
import '../BaseDatos/base_datos.dart';

import '../Servicios/motor_feedback.dart';

class ControladorPerfil {
  ConfiguracionPerfil _configuracion = ConfiguracionPerfil();
  final bool persistirEnBd;

  ControladorPerfil({this.persistirEnBd = true});

  ConfiguracionPerfil get configuracion => _configuracion;
  bool get sonidoHabilitado => _configuracion.sonidoHabilitado;
  bool get vibracionHabilitada => _configuracion.vibracionHabilitada;

  Future<void> cargarConfiguracion() async {
    final db = await BaseDeDatos.instancia.database;
    final mapas = await db.query(
      'configuracion',
      where: 'id = ?',
      whereArgs: [1],
    );

    if (mapas.isNotEmpty) {
      _configuracion = ConfiguracionPerfil.fromMap(mapas.first);
    } else {
      _configuracion = ConfiguracionPerfil();
      await _guardarConfiguracion();
    }
    MotorFeedback.sincronizarPreferencias(
      sonidoHabilitado: _configuracion.sonidoHabilitado,
      vibracionHabilitada: _configuracion.vibracionHabilitada,
    );
  }

  /// Activa o desactiva los efectos de sonido globalmente y persiste la preferencia.
  Future<void> actualizarSonidoHabilitado(bool habilitado) async {
    _configuracion.sonidoHabilitado = habilitado;
    MotorFeedback.sonidoHabilitado = habilitado;
    await _guardarConfiguracionSafely();
  }

  /// Activa o desactiva la vibración del sistema globalmente y persiste la preferencia.
  Future<void> actualizarVibracionHabilitada(bool habilitado) async {
    _configuracion.vibracionHabilitada = habilitado;
    MotorFeedback.vibracionHabilitada = habilitado;
    await _guardarConfiguracionSafely();
  }

  Future<void> _guardarConfiguracionSafely() async {
    try {
      await _guardarConfiguracion();
    } catch (_) {}
  }

  Future<void> alternarTema() async {
    final nuevoModo = _configuracion.modoTema == 1 ? 0 : 1;
    _configuracion.actualizarModoTema(nuevoModo);
    await _guardarConfiguracion();
  }

  Future<void> actualizarModoTema(int nuevoModo) async {
    _configuracion.actualizarModoTema(nuevoModo);
    await _guardarConfiguracion();
  }

  Future<void> alternarAplicarIva(bool activar) async {
    _configuracion.alternarAplicarIva(activar);
    await _guardarConfiguracion();
  }

  Future<void> actualizarTipoCambio(double nuevoCambio) async {
    _configuracion.actualizarTipoCambio(nuevoCambio);
    await _guardarConfiguracion();
  }

  Future<void> actualizarPorcentajeIva(double nuevoIva) async {
    _configuracion.actualizarIva(nuevoIva);
    await _guardarConfiguracion();
  }

  Future<void> _guardarConfiguracion() async {
    if (!persistirEnBd) return;
    final db = await BaseDeDatos.instancia.database;
    await db.update(
      'configuracion',
      _configuracion.toMap(),
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}
