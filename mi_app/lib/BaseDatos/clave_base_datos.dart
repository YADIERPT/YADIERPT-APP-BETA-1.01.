import '../Servicios/secure_storage_service.dart';

/// Proveedor de credenciales y clave maestra para SQLCipher AES-256.
///
/// Protege la base de datos local `viverapp.db` contra extracción física
/// y lectura forense en texto plano en almacenamiento local (100% offline).
class ClaveBaseDatos {
  static const String _masterPassphrase =
      'Planteapp_AES256_SQLCipher_LocalVault_2026_Secure';

  /// Retorna la frase de paso maestra por defecto para compatibilidad.
  static String get claveMaestra => _masterPassphrase;

  /// Obtiene de forma segura la frase de paso maestra persistida en el
  /// Keystore / Keychain mediante [SecureStorageService], o su fallback seguro.
  static Future<String> obtenerClaveSegura() async {
    return await SecureStorageService.instancia.obtenerClaveMaestraDb();
  }
}

