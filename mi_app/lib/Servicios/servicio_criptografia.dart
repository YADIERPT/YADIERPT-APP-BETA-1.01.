import 'dart:convert';
import 'package:crypto/crypto.dart' as legacy_crypto;
import 'package:cryptography/cryptography.dart';

/// Servicio de seguridad y derivación de claves criptográficas (KDF).
///
/// Implementa PBKDF2-HMAC-SHA256 con 100,000 iteraciones (estándar OWASP 2026)
/// para proteger las contraseñas de los colaboradores del vivero contra
/// ataques de fuerza bruta, tablas arcoíris y hardware acelerado (ASIC/GPU).
class ServicioCriptografia {
  static const int iteracionesEstandar = 100000;
  static const int longitudBits = 256;

  static final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iteracionesEstandar,
    bits: longitudBits,
  );

  /// Genera un hash seguro con formato modular KDF:
  /// `$pbkdf2$100000$<salt>$<hexHash>`
  static Future<String> hashearClavePbkdf2(String clave, String salt) async {
    final secretKey = SecretKey(utf8.encode(clave));
    final nonce = utf8.encode('planteapp_kdf_salt_$salt');
    final derivedKey = await _kdf.deriveKey(
      secretKey: secretKey,
      nonce: nonce,
    );
    final bytes = await derivedKey.extractBytes();
    final hexString =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '\$pbkdf2\$$iteracionesEstandar\$$salt\$$hexString';
  }

  /// Verifica si una [claveIngresada] coincide con el [hashAlmacenado].
  ///
  /// Soporta:
  /// 1. Hashes modernos PBKDF2 (`$pbkdf2$...`)
  /// 2. Hashes legados SHA-256 (`$salt:vivero_salt_2026:$clave`)
  /// 3. Texto plano legado (para migración transparente inmediata)
  static Future<bool> verificarClave({
    required String claveIngresada,
    required String hashAlmacenado,
    required String salt,
  }) async {
    // 1. Verificación PBKDF2 moderno
    if (hashAlmacenado.startsWith('\$pbkdf2\$')) {
      final partes = hashAlmacenado.split('\$');
      // Partes esperadas: ['', 'pbkdf2', '100000', salt, hexHash]
      if (partes.length >= 5) {
        final iteraciones =
            int.tryParse(partes[2]) ?? iteracionesEstandar;
        final saltOriginal = partes[3];
        final hashEsperado = partes[4];

        final kdfInstancia = Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: iteraciones,
          bits: longitudBits,
        );

        final secretKey = SecretKey(utf8.encode(claveIngresada));
        final nonce = utf8.encode('planteapp_kdf_salt_$saltOriginal');
        final derivedKey = await kdfInstancia.deriveKey(
          secretKey: secretKey,
          nonce: nonce,
        );
        final bytes = await derivedKey.extractBytes();
        final hexCalculado =
            bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

        return hexCalculado == hashEsperado;
      }
    }

    // 2. Retrocompatibilidad con SHA-256 legado
    final legacySha = legacy_crypto.sha256
        .convert(utf8.encode('$salt:vivero_salt_2026:$claveIngresada'))
        .toString();
    if (hashAlmacenado == legacySha) {
      return true;
    }

    // 3. Retrocompatibilidad con texto plano legado
    if (hashAlmacenado == claveIngresada) {
      return true;
    }

    return false;
  }
}

