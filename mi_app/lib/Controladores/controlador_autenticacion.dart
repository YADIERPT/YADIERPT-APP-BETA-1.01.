import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../Modelos/colaborador.dart';
import '../BaseDatos/base_datos.dart';
import '../Servicios/servicio_criptografia.dart';

/// Alias semántico para el controlador de personal / colaboradores
typedef ControladorEmpleados = ControladorAutenticacion;

class ControladorAutenticacion extends ChangeNotifier {
  Colaborador? _usuarioActual;
  List<Colaborador> _colaboradores = [];

  Colaborador? get usuarioActual => _usuarioActual;
  List<Colaborador> get colaboradores => _colaboradores;

  /// Permite establecer el usuario actual en memoria (útil para pruebas unitarias y de widgets)
  void establecerUsuarioParaPruebas(Colaborador? colaborador) {
    _usuarioActual = colaborador;
    notifyListeners();
  }

  /// Método legado síncrono para hashes SHA-256 (mantenido para retrocompatibilidad)
  static String hashearClave(String clave, String salt) {
    final bytes = utf8.encode('$salt:vivero_salt_2026:$clave');
    return sha256.convert(bytes).toString();
  }

  /// Método moderno asíncrono basado en KDF PBKDF2-HMAC-SHA256 (100k iteraciones)
  static Future<String> hashearClaveKdf(String clave, String salt) async {
    return await ServicioCriptografia.hashearClavePbkdf2(clave, salt);
  }

  Future<void> cargarUsuariosPorDefecto() async {
    final db = await BaseDeDatos.instancia.database;
    final conteo = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM colaboradores'),
    );
    if (conteo == null || conteo == 0) {
      final claveSegura = await hashearClaveKdf('123456', 'VO-4092');
      final admin = Colaborador(
        id: 'VO-4092',
        nombre: 'Admin Vivero',
        clave: claveSegura,
        rol: RolUsuario.duena,
      );
      await registrarColaborador(admin, yaHasheada: true);
    }
  }

  Future<void> registrarColaborador(
    Colaborador nuevo, {
    bool yaHasheada = false,
  }) async {
    final db = await BaseDeDatos.instancia.database;
    final claveFinal = yaHasheada
        ? nuevo.clave
        : await hashearClaveKdf(nuevo.clave, nuevo.id);
    final map = nuevo.toMap();
    map['clave'] = claveFinal;
    await db.insert('colaboradores', map);
    await obtenerColaboradores();
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

      final esValida = await ServicioCriptografia.verificarClave(
        claveIngresada: clave,
        hashAlmacenado: claveAlmacenada,
        salt: id,
      );

      if (esValida) {
        // Si la clave no está en formato PBKDF2 moderno, migrar automáticamente
        if (!claveAlmacenada.startsWith('\$pbkdf2\$')) {
          final nuevoHash = await hashearClaveKdf(clave, id);
          await db.update(
            'colaboradores',
            {'clave': nuevoHash},
            where: 'id = ?',
            whereArgs: [id],
          );
          _usuarioActual = Colaborador.fromMap({
            ...map,
            'clave': nuevoHash,
          });
        } else {
          _usuarioActual = Colaborador.fromMap(map);
        }
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

  /// Verifica la clave contra el colaborador, soportando PBKDF2 y hashes legados
  Future<bool> verificarClave(
    Colaborador colaborador,
    String claveIngresada,
  ) async {
    return await ServicioCriptografia.verificarClave(
      claveIngresada: claveIngresada,
      hashAlmacenado: colaborador.clave,
      salt: colaborador.id,
    );
  }

  Future<List<Colaborador>> obtenerColaboradores() async {
    final db = await BaseDeDatos.instancia.database;
    final resultados = await db.query('colaboradores', orderBy: 'nombre ASC');
    _colaboradores =
        resultados.map((mapa) => Colaborador.fromMap(mapa)).toList();
    notifyListeners();
    return _colaboradores;
  }

  /// Actualiza los datos de un empleado (nombre, rol y opcionalmente su clave hasheada)
  Future<void> actualizarColaborador(
    Colaborador colaborador, {
    String? nuevaClave,
  }) async {
    final db = await BaseDeDatos.instancia.database;
    final map = <String, dynamic>{
      'nombre': colaborador.nombre,
      'rol': colaborador.rol.valor,
    };

    if (nuevaClave != null && nuevaClave.trim().isNotEmpty) {
      map['clave'] = await hashearClaveKdf(nuevaClave.trim(), colaborador.id);
    }

    await db.update(
      'colaboradores',
      map,
      where: 'id = ?',
      whereArgs: [colaborador.id],
    );

    if (_usuarioActual != null && _usuarioActual!.id == colaborador.id) {
      _usuarioActual = _usuarioActual!.copyWith(
        nombre: colaborador.nombre,
        rol: colaborador.rol,
        clave: map['clave'] as String? ?? _usuarioActual!.clave,
      );
    }

    await obtenerColaboradores();
  }

  /// Valida la clave de seguridad contra la cuenta de Dueña o Administrador activo en SQLite
  Future<bool> verificarClaveAdmin(String clave) async {
    if (clave.trim().isEmpty) return false;

    // 1. Si el usuario en sesión es Dueña o Gerente, validamos directamente contra su credencial
    if (_usuarioActual != null &&
        (_usuarioActual!.rol.esDuena || _usuarioActual!.rol.esGerente)) {
      final esValida = await verificarClave(_usuarioActual!, clave.trim());
      if (esValida) return true;
    }

    // 2. Si no o si falla, buscar en SQLite cualquier cuenta con rol Dueña o Admin
    final db = await BaseDeDatos.instancia.database;
    final resultados = await db.query('colaboradores');

    for (var mapa in resultados) {
      final colab = Colaborador.fromMap(mapa);
      if (colab.rol.esDuena || colab.rol.esGerente) {
        final esValida = await verificarClave(colab, clave.trim());
        if (esValida) return true;
      }
    }

    return false;
  }

  Future<void> cambiarClave(String id, String nuevaClave) async {
    final db = await BaseDeDatos.instancia.database;
    final claveHasheada = await hashearClaveKdf(nuevaClave, id);
    await db.update(
      'colaboradores',
      {'clave': claveHasheada},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (_usuarioActual != null && _usuarioActual!.id == id) {
      _usuarioActual = _usuarioActual!.copyWith(clave: claveHasheada);
    }
  }

  void cerrarSesion() {
    _usuarioActual = null;
  }
}
