import '../Modelos/configuracion.dart';
import '../BaseDatos/base_datos.dart';

class ControladorPerfil {
  ConfiguracionPerfil _configuracion = ConfiguracionPerfil();

  ConfiguracionPerfil get configuracion => _configuracion;

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
    final db = await BaseDeDatos.instancia.database;
    await db.update(
      'configuracion',
      _configuracion.toMap(),
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}
