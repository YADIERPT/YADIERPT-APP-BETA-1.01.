import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../Modelos/colaborador.dart';
import '../BaseDatos/base_datos.dart';
import '../Servicios/servicio_criptografia.dart';
import '../Servicios/secure_storage_service.dart';

/// Alias semántico para el controlador de personal / colaboradores
typedef ControladorEmpleados = ControladorAutenticacion;

class ControladorAutenticacion extends ChangeNotifier {
  Colaborador? _usuarioActual;
  List<Colaborador> _colaboradores = [];

  /// Token de desafío biométrico efímero de un solo uso
  String? _tokenDesafioActivo;
  DateTime? _expiracionTokenDesafio;
  String? _usuarioDesafio;

  Colaborador? get usuarioActual => _usuarioActual;
  List<Colaborador> get colaboradores => _colaboradores;

  /// Emite un token criptográfico efímero de un solo uso (válido por 45 segundos)
  /// tras una validación exitosa de hardware biométrico.
  String generarTokenDesafioBiometrico(String usuarioId) {
    final token = ServicioCriptografia.generarClaveAleatoriaSegura(32);
    _tokenDesafioActivo = token;
    _usuarioDesafio = usuarioId;
    _expiracionTokenDesafio = DateTime.now().add(const Duration(seconds: 45));
    return token;
  }

  List<Colaborador>? _colaboradoresPrueba;

  /// Permite establecer el usuario actual en memoria (útil para pruebas unitarias y de widgets)
  void establecerUsuarioParaPruebas(Colaborador? colaborador) {
    _usuarioActual = colaborador;
    notifyListeners();
  }

  /// Permite inyectar colaboradores en memoria para pruebas unitarias y de widgets
  void establecerColaboradoresParaPruebas(List<Colaborador>? colaboradores) {
    _colaboradoresPrueba = colaboradores;
    if (colaboradores != null) {
      _colaboradores = List.from(colaboradores);
      notifyListeners();
    }
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

  Future<bool> registrarColaborador(
    Colaborador nuevo, {
    bool yaHasheada = false,
  }) async {
    try {
      final idSanitizado = nuevo.id.trim().toUpperCase();
      final nombreSanitizado = nuevo.nombre.trim();
      final claveLimpia = nuevo.clave.trim();

      if (idSanitizado.isEmpty || nombreSanitizado.isEmpty || claveLimpia.isEmpty) {
        throw ArgumentError('El ID, nombre y contraseña no pueden estar vacíos.');
      }

      // Motor criptográfico unificado: PBKDF2-HMAC-SHA256 (100k iteraciones)
      // Salt normalizado obligatoriamente en mayúsculas y sin espacios
      final String claveFinal;
      if (yaHasheada) {
        claveFinal = claveLimpia;
      } else {
        claveFinal = await hashearClaveKdf(claveLimpia, idSanitizado);
      }

      final colaboradorSanitizado = Colaborador(
        id: idSanitizado,
        nombre: nombreSanitizado,
        clave: claveFinal,
        rol: nuevo.rol,
      );

      final db = await BaseDeDatos.instancia.database;
      final map = colaboradorSanitizado.toMap();

      await db.insert(
        'colaboradores',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (_colaboradoresPrueba != null) {
        _colaboradoresPrueba!.removeWhere((c) => c.id.trim().toUpperCase() == idSanitizado);
        _colaboradoresPrueba!.add(colaboradorSanitizado);
      }

      await obtenerColaboradores();
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error crítico en registrarColaborador: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Alias semántico para la creación de empleados/usuarios solicitado por la administración.
  /// Aplica sanitización estricta: Trim y UpperCase en el ID antes de la inserción en SQLite.
  Future<bool> agregarEmpleado({
    required String id,
    required String nombre,
    required String clave,
    RolUsuario rol = RolUsuario.empleado,
  }) async {
    final idSanitizado = id.trim().toUpperCase();
    final nombreSanitizado = nombre.trim();
    final claveSanitizada = clave.trim();

    final nuevo = Colaborador(
      id: idSanitizado,
      nombre: nombreSanitizado,
      clave: claveSanitizada,
      rol: rol,
    );
    return await registrarColaborador(nuevo);
  }

  /// Inicia sesión verificando credenciales con sanitización Trim & UpperCase
  /// y consulta SQL insensible a mayúsculas mediante COLLATE NOCASE.
  Future<bool> iniciarSesion(String idONombre, String clave) async {
    final idSanitizado = idONombre.trim().toUpperCase();
    final nombreOriginalLimpio = idONombre.trim();
    final claveSanitizada = clave.trim();

    if (idSanitizado.isEmpty || claveSanitizada.isEmpty) {
      return false;
    }

    try {
      final List<Map<String, dynamic>> resultados;

      if (_colaboradoresPrueba != null) {
        resultados = _colaboradoresPrueba!
            .where((c) =>
                c.id.trim().toUpperCase() == idSanitizado ||
                c.nombre.trim().toUpperCase() == idSanitizado ||
                c.nombre.trim().toLowerCase() == nombreOriginalLimpio.toLowerCase())
            .map((c) => c.toMap())
            .toList();
      } else {
        final db = await BaseDeDatos.instancia.database;
        // Consulta SQL insensible a mayúsculas usando COLLATE NOCASE
        resultados = await db.rawQuery(
          'SELECT * FROM colaboradores WHERE id = ? COLLATE NOCASE OR nombre = ? COLLATE NOCASE',
          [idSanitizado, nombreOriginalLimpio],
        );
      }

      if (resultados.isNotEmpty) {
        final map = resultados.first;
        final claveAlmacenada = map['clave'] as String;
        // Salt exacto uniforme en mayúsculas extraído de la base de datos
        final saltReal = (map['id'] as String).trim().toUpperCase();

        // Motor criptográfico unificado: verificación PBKDF2 con el salt exacto del colaborador
        final esValida = await ServicioCriptografia.verificarClave(
          claveIngresada: claveSanitizada,
          hashAlmacenado: claveAlmacenada,
          salt: saltReal,
        );

        if (esValida) {
          // Si la clave no está en formato PBKDF2 moderno o el salt no estaba en mayúsculas, migrar automáticamente
          final partes = claveAlmacenada.startsWith('\$pbkdf2\$') ? claveAlmacenada.split('\$') : null;
          final bool requiereRehash = !claveAlmacenada.startsWith('\$pbkdf2\$') ||
              (partes != null && partes.length >= 5 && partes[3] != saltReal);

          if (requiereRehash) {
            final nuevoHash = await hashearClaveKdf(claveSanitizada, saltReal);
            if (_colaboradoresPrueba == null) {
              final db = await BaseDeDatos.instancia.database;
              await db.update(
                'colaboradores',
                {'id': saltReal, 'clave': nuevoHash},
                where: 'id = ? COLLATE NOCASE',
                whereArgs: [saltReal],
              );
            }
            _usuarioActual = Colaborador.fromMap({
              ...map,
              'id': saltReal,
              'clave': nuevoHash,
            });
          } else {
            _usuarioActual = Colaborador.fromMap({
              ...map,
              'id': saltReal,
            });
          }
          notifyListeners();
          return true;
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error en iniciarSesion: $e\n$stackTrace');
    }

    return false;
  }

  /// Inicia sesión por ID verificando obligatoriamente un [tokenVerificacion] válido.
  ///
  /// El token debe corresponder a:
  /// 1. Un desafío biométrico efímero no expirado generado por [generarTokenDesafioBiometrico].
  /// 2. O un token de sesión recordada persistido de forma segura en el Keystore.
  ///
  /// Impide el acceso no autenticado o el escalamiento arbitrario de privilegios.
  Future<bool> iniciarSesionPorId({
    required String id,
    required String tokenVerificacion,
  }) async {
    final ahora = DateTime.now();
    final idSanitizado = id.trim().toUpperCase();

    // 1. Verificación de token de desafío biométrico efímero
    final bool esTokenDesafioValido = _tokenDesafioActivo != null &&
        _usuarioDesafio?.trim().toUpperCase() == idSanitizado &&
        _tokenDesafioActivo == tokenVerificacion &&
        _expiracionTokenDesafio != null &&
        ahora.isBefore(_expiracionTokenDesafio!);

    // 2. Verificación de sesión recordada legítima en SecureStorage
    final secureStorage = SecureStorageService.instancia;
    final tokenAlmacenado =
        await secureStorage.leer('planteapp_token_sesion_recordada');
    final ultimoIdRecordado =
        await secureStorage.leer('planteapp_ultimo_usuario_id');
    final bool esSesionRecordadaValida = tokenAlmacenado != null &&
        tokenAlmacenado == tokenVerificacion &&
        ultimoIdRecordado?.trim().toUpperCase() == idSanitizado;

    if (!esTokenDesafioValido && !esSesionRecordadaValida) {
      debugPrint(
        'Alerta de seguridad: Intento de inicio de sesión no autorizado para el ID $idSanitizado (token no válido o expirado)',
      );
      return false;
    }

    // Invalida inmediatamente el token efímero de un solo uso para prevenir ataques de replay
    _tokenDesafioActivo = null;
    _expiracionTokenDesafio = null;
    _usuarioDesafio = null;

    try {
      if (_colaboradoresPrueba != null) {
        final colab = _colaboradoresPrueba!
            .where((c) => c.id.trim().toUpperCase() == idSanitizado)
            .firstOrNull;
        if (colab != null) {
          _usuarioActual = colab;
          notifyListeners();
          return true;
        }
      }

      final db = await BaseDeDatos.instancia.database;
      final resultados = await db.rawQuery(
        'SELECT * FROM colaboradores WHERE id = ? COLLATE NOCASE',
        [idSanitizado],
      );

      if (resultados.isNotEmpty) {
        _usuarioActual = Colaborador.fromMap(resultados.first);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Aviso en iniciarSesionPorId: $e');
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
    if (_colaboradoresPrueba != null) {
      _colaboradores = List.from(_colaboradoresPrueba!);
      notifyListeners();
      return _colaboradores;
    }
    final db = await BaseDeDatos.instancia.database;
    final resultados = await db.query('colaboradores', orderBy: 'nombre ASC');
    _colaboradores =
        resultados.map((mapa) => Colaborador.fromMap(mapa)).toList();
    notifyListeners();
    return _colaboradores;
  }

  /// Actualiza los datos de un empleado (nombre, rol y opcionalmente su clave hasheada).
  /// Aplica "Protección Anti-Degradación": Si el usuario con sesión activa es el Dueño,
  /// se impide que su rol sea degradado a empleado en SQLite y en memoria.
  Future<void> actualizarColaborador(
    Colaborador colaborador, {
    String? nuevaClave,
  }) async {
    // 1. Protección Anti-Degradación en Capa de Dominio / Negocio
    final idSanitizado = colaborador.id.trim().toUpperCase();
    RolUsuario rolAGuardar = colaborador.rol;
    if (_usuarioActual != null &&
        _usuarioActual!.id.trim().toUpperCase() == idSanitizado &&
        _usuarioActual!.rol.esDuena &&
        !colaborador.rol.esDuena) {
      debugPrint(
        'Seguridad RBAC: Intento de auto-degradación de rol bloqueado para ID ${colaborador.id}',
      );
      rolAGuardar = RolUsuario.duena;
    }

    final db = await BaseDeDatos.instancia.database;
    final map = <String, dynamic>{
      'id': idSanitizado,
      'nombre': colaborador.nombre.trim(),
      'rol': rolAGuardar.valor,
    };

    if (nuevaClave != null && nuevaClave.trim().isNotEmpty) {
      map['clave'] = await hashearClaveKdf(nuevaClave.trim(), idSanitizado);
    }

    await db.update(
      'colaboradores',
      map,
      where: 'id = ? COLLATE NOCASE',
      whereArgs: [idSanitizado],
    );

    if (_usuarioActual != null && _usuarioActual!.id.trim().toUpperCase() == idSanitizado) {
      _usuarioActual = _usuarioActual!.copyWith(
        id: idSanitizado,
        nombre: colaborador.nombre.trim(),
        rol: rolAGuardar,
        clave: map['clave'] as String? ?? _usuarioActual!.clave,
      );
    }

    if (_colaboradoresPrueba != null) {
      final index =
          _colaboradoresPrueba!.indexWhere((c) => c.id.trim().toUpperCase() == idSanitizado);
      if (index != -1) {
        _colaboradoresPrueba![index] = colaborador.copyWith(
          id: idSanitizado,
          nombre: colaborador.nombre.trim(),
          rol: rolAGuardar,
          clave: map['clave'] as String? ?? _colaboradoresPrueba![index].clave,
        );
      }
    }

    await obtenerColaboradores();
  }

  /// Elimina un colaborador del sistema en SQLite.
  /// Implementa "Protección Anti-Suicidio": Impide que el usuario en sesión activa se elimine a sí mismo.
  Future<bool> eliminarColaborador(String idColaborador) async {
    final idSanitizado = idColaborador.trim().toUpperCase();

    // 1. Protección Anti-Suicidio en capa de Dominio / Controlador
    if (_usuarioActual != null && _usuarioActual!.id.trim().toUpperCase() == idSanitizado) {
      debugPrint(
        'Seguridad RBAC: Intento de auto-eliminación bloqueado para ID $idColaborador',
      );
      throw Exception(
        'Operación no permitida: No puedes eliminar tu propia cuenta mientras tengas la sesión activa.',
      );
    }

    if (_colaboradoresPrueba != null) {
      final index =
          _colaboradoresPrueba!.indexWhere((c) => c.id.trim().toUpperCase() == idSanitizado);
      if (index != -1) {
        _colaboradoresPrueba!.removeAt(index);
        await obtenerColaboradores();
        return true;
      }
      return false;
    }

    final db = await BaseDeDatos.instancia.database;
    final eliminados = await db.delete(
      'colaboradores',
      where: 'id = ? COLLATE NOCASE',
      whereArgs: [idSanitizado],
    );

    if (eliminados > 0) {
      await obtenerColaboradores();
      return true;
    }
    return false;
  }

  /// Valida la clave de seguridad contra la cuenta de Dueña o Administrador activo en SQLite
  Future<bool> verificarClaveAdmin(String clave) async {
    if (clave.trim().isEmpty) return false;

    // 1. Si el usuario en sesión es Dueño, validamos directamente contra su credencial
    if (_usuarioActual != null && _usuarioActual!.rol.esDuena) {
      final esValida = await verificarClave(_usuarioActual!, clave.trim());
      if (esValida) return true;
    }

    // 2. Si no o si falla, buscar en SQLite cualquier cuenta con rol Dueño o Admin
    final db = await BaseDeDatos.instancia.database;
    final resultados = await db.query('colaboradores');

    for (var mapa in resultados) {
      final colab = Colaborador.fromMap(mapa);
      if (colab.rol.esDuena) {
        final esValida = await verificarClave(colab, clave.trim());
        if (esValida) return true;
      }
    }

    return false;
  }

  Future<void> cambiarClave(String id, String nuevaClave) async {
    final idSanitizado = id.trim().toUpperCase();
    final db = await BaseDeDatos.instancia.database;
    final claveHasheada = await hashearClaveKdf(nuevaClave.trim(), idSanitizado);
    await db.update(
      'colaboradores',
      {'clave': claveHasheada},
      where: 'id = ? COLLATE NOCASE',
      whereArgs: [idSanitizado],
    );
    if (_usuarioActual != null && _usuarioActual!.id.trim().toUpperCase() == idSanitizado) {
      _usuarioActual = _usuarioActual!.copyWith(clave: claveHasheada);
    }
  }

  void cerrarSesion() {
    _usuarioActual = null;
    _tokenDesafioActivo = null;
    _expiracionTokenDesafio = null;
    _usuarioDesafio = null;
    notifyListeners();
  }
}
