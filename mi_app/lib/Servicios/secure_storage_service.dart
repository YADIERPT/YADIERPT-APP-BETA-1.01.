import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  /// Frase de respaldo de alta entropía en caso de falla crítica del Keystore/Keychain.
  static const String _fallbackMasterKey =
      'Planteapp_AES256_SQLCipher_LocalVault_2026_Secure_Fallback';

  /// Caché en memoria para mantener consistencia en la sesión actual si el Keystore falla.
  String? _memoriaFallbackKey;

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

  /// Obtiene la llave maestra de cifrado para SQLCipher.
  ///
  /// Si la llave ya existe en el Keystore/Keychain, la retorna.
  /// Si es el primer arranque, genera una llave criptográficamente segura de 256 bits,
  /// la persiste en el almacenamiento seguro y la retorna.
  /// Si el hardware de seguridad falla o no está disponible, activa un fallback seguro
  /// para evitar que la aplicación falle o corrompa la base de datos.
  Future<String> obtenerClaveMaestraDb() async {
    try {
      final String? claveGuardada = await _storage.read(key: _keyMasterDb);

      if (claveGuardada != null && claveGuardada.trim().isNotEmpty) {
        return claveGuardada;
      }

      // Si no existe, generamos una nueva llave aleatoria de 256 bits (32 bytes)
      final nuevaClave = generarClaveAleatoriaSegura(32);
      await _storage.write(key: _keyMasterDb, value: nuevaClave);
      return nuevaClave;
    } on PlatformException catch (e) {
      debugPrint('Aviso de seguridad: Keystore/Keychain no disponible: ${e.code} - ${e.message}');
      return _obtenerFallbackSeguro();
    } catch (e) {
      debugPrint('Aviso de seguridad: Excepción al leer SecureStorage: $e');
      return _obtenerFallbackSeguro();
    }
  }

  /// Guarda explícitamente una llave maestra en el almacenamiento seguro.
  Future<bool> guardarClaveMaestraDb(String clave) async {
    try {
      await _storage.write(key: _keyMasterDb, value: clave);
      _memoriaFallbackKey = clave;
      return true;
    } on PlatformException catch (e) {
      debugPrint('Error en Keystore al escribir clave maestra: ${e.code}');
      _memoriaFallbackKey = clave;
      return false;
    } catch (e) {
      debugPrint('Error general al escribir clave maestra: $e');
      _memoriaFallbackKey = clave;
      return false;
    }
  }

  /// Elimina la llave maestra de la base de datos de forma segura (ej. para restablecimiento).
  Future<bool> eliminarClaveMaestraDb() async {
    try {
      await _storage.delete(key: _keyMasterDb);
      _memoriaFallbackKey = null;
      return true;
    } catch (e) {
      debugPrint('Error al eliminar clave maestra de SecureStorage: $e');
      _memoriaFallbackKey = null;
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
      _memoriaFallbackKey = null;
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

  /// Proporciona un fallback consistente durante el ciclo de vida de la aplicación
  /// si el subsistema de hardware biométrico/seguro del dispositivo no responde.
  String _obtenerFallbackSeguro() {
    _memoriaFallbackKey ??= _fallbackMasterKey;
    return _memoriaFallbackKey!;
  }
}
