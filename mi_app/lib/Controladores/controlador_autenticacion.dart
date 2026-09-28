import 'package:sqflite/sqflite.dart';

import '../Modelos/colaborador.dart';
import '../BaseDatos/base_datos.dart';

class ControladorAutenticacion {
  Colaborador? _usuarioActual;

  Colaborador? get usuarioActual => _usuarioActual;

  Future<void> cargarUsuariosPorDefecto() async {
    final db = await BaseDeDatos.instancia.database;
    final conteo = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM colaboradores'),
    );
    if (conteo == null || conteo == 0) {
      final admin = Colaborador(
        id: 'VO-4092',
        nombre: 'Admin Vivero',
        clave: '123456',
        rol: 'admin',
      );
      await registrarColaborador(admin);
    }
  }

  Future<void> registrarColaborador(Colaborador nuevo) async {
    final db = await BaseDeDatos.instancia.database;
    await db.insert('colaboradores', nuevo.toMap());
  }

  Future<bool> iniciarSesion(String id, String clave) async {
    final db = await BaseDeDatos.instancia.database;
    final resultados = await db.query(
      'colaboradores',
      where: 'id = ? AND clave = ?',
      whereArgs: [id, clave],
    );

    if (resultados.isNotEmpty) {
      _usuarioActual = Colaborador.fromMap(resultados.first);
      return true;
    }

    return false;
  }

  Future<List<Colaborador>> obtenerColaboradores() async {
    final db = await BaseDeDatos.instancia.database;
    final resultados = await db.query('colaboradores');
    return resultados.map((mapa) => Colaborador.fromMap(mapa)).toList();
  }

  Future<void> cambiarClave(String id, String nuevaClave) async {
    final db = await BaseDeDatos.instancia.database;
    await db.update(
      'colaboradores',
      {'clave': nuevaClave},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (_usuarioActual != null && _usuarioActual!.id == id) {
      _usuarioActual = Colaborador(
        id: _usuarioActual!.id,
        nombre: _usuarioActual!.nombre,
        clave: nuevaClave,
        rol: _usuarioActual!.rol,
      );
    }
  }

  void cerrarSesion() {
    _usuarioActual = null;
  }
}
