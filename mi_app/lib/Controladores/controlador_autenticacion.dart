import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../Modelos/colaborador.dart';
import '../BaseDatos/base_datos.dart';

class ControladorAutenticacion {
  Colaborador? _usuarioActual;

  Colaborador? get usuarioActual => _usuarioActual;

  static String hashearClave(String clave, String salt) {
    final bytes = utf8.encode('$salt:vivero_salt_2026:$clave');
    return sha256.convert(bytes).toString();
  }

  Future<void> cargarUsuariosPorDefecto() async {
    final db = await BaseDeDatos.instancia.database;
    final conteo = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM colaboradores'),
    );
    if (conteo == null || conteo == 0) {
      final admin = Colaborador(
        id: 'VO-4092',
        nombre: 'Admin Vivero',
        clave: hashearClave('123456', 'VO-4092'),
        rol: 'admin',
      );
      await registrarColaborador(admin, yaHasheada: true);
    }
  }

  Future<void> registrarColaborador(
    Colaborador nuevo, {
    bool yaHasheada = false,
  }) async {
    final db = await BaseDeDatos.instancia.database;
    final claveFinal =
        yaHasheada ? nuevo.clave : hashearClave(nuevo.clave, nuevo.id);
    final map = nuevo.toMap();
    map['clave'] = claveFinal;
    await db.insert('colaboradores', map);
  }

  Future<bool> iniciarSesion(String id, String clave) async {
    final db = await BaseDeDatos.instancia.database;
    final resultados = await db.query(
      'colaboradores',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (resultados.isNotEmpty) {
      final map = resultados.first;
      final claveAlmacenada = map['clave'] as String;
      final hashCalculado = hashearClave(clave, id);

      if (claveAlmacenada == hashCalculado) {
        _usuarioActual = Colaborador.fromMap(map);
        return true;
      } else if (claveAlmacenada == clave) {
        // Migración automática a hash seguro para usuarios heredados
        await db.update(
          'colaboradores',
          {'clave': hashCalculado},
          where: 'id = ?',
          whereArgs: [id],
        );
        _usuarioActual = Colaborador.fromMap({
          ...map,
          'clave': hashCalculado,
        });
        return true;
      }
    }

    return false;
  }

  Future<bool> iniciarSesionPorId(String id) async {
    final db = await BaseDeDatos.instancia.database;
    final resultados = await db.query(
      'colaboradores',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (resultados.isNotEmpty) {
      _usuarioActual = Colaborador.fromMap(resultados.first);
      return true;
    }

    return false;
  }

  bool verificarClave(Colaborador colaborador, String claveIngresada) {
    final hashCalculado = hashearClave(claveIngresada, colaborador.id);
    return colaborador.clave == hashCalculado ||
        colaborador.clave == claveIngresada;
  }

  Future<List<Colaborador>> obtenerColaboradores() async {
    final db = await BaseDeDatos.instancia.database;
    final resultados = await db.query('colaboradores');
    return resultados.map((mapa) => Colaborador.fromMap(mapa)).toList();
  }

  Future<void> cambiarClave(String id, String nuevaClave) async {
    final db = await BaseDeDatos.instancia.database;
    final claveHasheada = hashearClave(nuevaClave, id);
    await db.update(
      'colaboradores',
      {'clave': claveHasheada},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (_usuarioActual != null && _usuarioActual!.id == id) {
      _usuarioActual = Colaborador(
        id: _usuarioActual!.id,
        nombre: _usuarioActual!.nombre,
        clave: claveHasheada,
        rol: _usuarioActual!.rol,
      );
    }
  }

  void cerrarSesion() {
    _usuarioActual = null;
  }
}
