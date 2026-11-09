import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Excepción de seguridad lanzada cuando el subsistema de hardware seguro
/// (Android Keystore / iOS Keychain) no está disponible, reporta un error o falla
/// al recuperar la clave criptográfica maestra de la base de datos.
class KeystoreUnavailableException implements Exception {
  final String mensaje;
  final dynamic errorOriginal;

  const KeystoreUnavailableException([
    this.mensaje = 'El subsistema de hardware seguro (Keystore/Keychain) no está disponible o no responde.',
    this.errorOriginal,
  ]);

  @override
  String toString() =>
      'KeystoreUnavailableException: $mensaje${errorOriginal != null ? ' (Causa: $errorOriginal)' : ''}';
}

/// Servicio especializado en el almacenamiento seguro de credenciales y
/// llaves criptográficas utilizando el hardware de seguridad del dispositivo
/// (Android Keystore / iOS Keychain).
class SecureStorageService {
  static final SecureStorageService _instancia =
      SecureStorageService._interno();

  /// Acceso a la instancia Singleton del servicio.
  static SecureStorageService get instancia => _instancia;

  /// Constructor interno privado.
  SecureStorageService._interno();

  /// Llave utilizada para almacenar la frase de paso maestra de SQLCipher.
  static const String _keyMasterDb = 'planteapp_sqlcipher_master_key';

  /// Opciones de configuración segura para cada plataforma.
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      // Utiliza MasterKeys de Android Keystore con cifrado AES-256 GCM
      encryptedSharedPreferences: true,
      resetOnError: false,
    ),
    iOptions: IOSOptions(
      // Vinculado al dispositivo tras el primer desbloqueo
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );

  /// Obtiene la llave maestra de cifrado para SQLCipher desde el Keystore/Keychain.
  ///
  /// Si la llave ya existe en el Keystore/Keychain, la retorna.
  /// Si es el primer arranque, genera una llave criptográficamente segura de 256 bits,
  /// la persiste en el hardware de seguridad y la retorna.
  /// Si el hardware de seguridad falla o no está disponible, lanza [KeystoreUnavailableException].
  ///
  /// NUNCA se utiliza una clave fija de respaldo (fallback) para evitar corromper
  /// la cabecera cifrada de la base de datos SQLite con una clave incorrecta.
  Future<String> obtenerClaveMaestraDb() async {
    try {
      final String? claveGuardada = await _storage.read(key: _keyMasterDb);

      if (claveGuardada != null && claveGuardada.trim().isNotEmpty) {
        return claveGuardada;
      }

      // Si no existe, generamos una nueva llave aleatoria de 256 bits (32 bytes)
      final nuevaClave = generarClaveAleatoriaSegura(32);
      await _storage.write(key: _keyMasterDb, value: nuevaClave);

      // Verificación de integridad: comprobar que el Keystore realmente persistió la clave
      final verificacion = await _storage.read(key: _keyMasterDb);
      if (verificacion == null || verificacion.trim().isEmpty) {
        throw const KeystoreUnavailableException(
          'Fallo de integridad: No se pudo verificar la persistencia de la clave maestra en el Keystore.',
        );
      }

      return nuevaClave;
    } on PlatformException catch (e) {
      debugPrint('Error crítico en Keystore/Keychain: ${e.code} - ${e.message}');
      throw KeystoreUnavailableException(
        'El hardware de seguridad del dispositivo reportó un fallo (${e.code}): ${e.message}',
        e,
      );
    } catch (e) {
      debugPrint('Error crítico en SecureStorage: $e');
      if (e is KeystoreUnavailableException) rethrow;
      throw KeystoreUnavailableException(
        'No se pudo acceder a la clave maestra de la base de datos de forma segura.',
        e,
      );
    }
  }

  /// Guarda explícitamente una llave maestra en el almacenamiento seguro.
  Future<bool> guardarClaveMaestraDb(String clave) async {
    try {
      await _storage.write(key: _keyMasterDb, value: clave);
      return true;
    } on PlatformException catch (e) {
      debugPrint('Error en Keystore al escribir clave maestra: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('Error general al escribir clave maestra: $e');
      return false;
    }
  }

  /// Elimina la llave maestra de la base de datos de forma segura (ej. para restablecimiento).
  Future<bool> eliminarClaveMaestraDb() async {
    try {
      await _storage.delete(key: _keyMasterDb);
      return true;
    } catch (e) {
      debugPrint('Error al eliminar clave maestra de SecureStorage: $e');
      return false;
    }
  }

  /// Lee un valor genérico almacenado bajo la clave indicada.
  Future<String?> leer(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('Error al leer $key de SecureStorage: $e');
      return null;
    }
  }

  /// Escribe un valor genérico en el almacenamiento seguro.
  Future<bool> guardar(String key, String valor) async {
    try {
      await _storage.write(key: key, value: valor);
      return true;
    } catch (e) {
      debugPrint('Error al guardar $key en SecureStorage: $e');
      return false;
    }
  }

  /// Elimina un valor específico del almacenamiento seguro.
  Future<bool> eliminar(String key) async {
    try {
      await _storage.delete(key: key);
      return true;
    } catch (e) {
      debugPrint('Error al eliminar $key de SecureStorage: $e');
      return false;
    }
  }

  /// Elimina todas las llaves persistidas en el almacenamiento seguro.
  Future<bool> limpiarTodo() async {
    try {
      await _storage.deleteAll();
      return true;
    } catch (e) {
      debugPrint('Error al limpiar SecureStorage: $e');
      return false;
    }
  }

  /// Genera una cadena aleatoria de alta entropía con bytes criptográficamente seguros.
  ///
  /// Por defecto produce 32 bytes (256 bits), codificados en hexadecimal.
  String generarClaveAleatoriaSegura([int longitudBytes = 32]) {
    final random = Random.secure();
    final bytes = List<int>.generate(longitudBytes, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
