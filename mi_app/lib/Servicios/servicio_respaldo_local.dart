import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:cryptography/cryptography.dart';

import '../BaseDatos/base_datos.dart';
import 'secure_storage_service.dart';

/// Servicio especializado en la generación y restauración de respaldos
/// cifrados locales (.bak) para la base de datos de Planteapp.
class ServicioRespaldoLocal {
  static const String _magicHeader = 'PLANTEAPP_BAK_V1';

  /// Exporta la base de datos local actual a un archivo .bak cifrado con AES-256-GCM
  /// en el directorio de documentos del dispositivo.
  ///
  /// Retorna el [File] del respaldo generado.
  static Future<File> exportarRespaldo({String? passwordPersonalizada}) async {
    try {
      // 1. Forzar volcado de transacciones WAL a disco
      final db = await BaseDeDatos.instancia.database;
      try {
        await db.rawQuery('PRAGMA wal_checkpoint(FULL);');
      } catch (_) {
        // En plataformas donde WAL no esté activo, ignorar
      }

      // 2. Localizar el archivo de la base de datos
      final dbDir = await getDatabasesPath();
      final dbFile = File(join(dbDir, 'viverapp.db'));

      if (!await dbFile.exists()) {
        throw Exception('No se encontró el archivo de la base de datos local.');
      }

      final bytesOrigen = await dbFile.readAsBytes();
      if (bytesOrigen.isEmpty) {
        throw Exception('La base de datos actual está vacía.');
      }

      // 3. Obtener la clave de cifrado (maestra o personalizada)
      final secretKey = await _derivarClaveCifrado(passwordPersonalizada);

      // 4. Cifrar con AES-GCM (256 bits)
      // 4. Cifrar con AES-256-GCM (autenticado)
      final algorithm = AesGcm.with256bits();
      final secretBox = await algorithm.encrypt(
        bytesOrigen,
        secretKey: secretKey,
      );

      // 5. Construir paquete binario con cabecera de integridad
      // Estructura: [MAGIC_HEADER_BYTES][12B NONCE][16B MAC TAG][CIPHERTEXT]
      final headerBytes = _magicHeader.codeUnits;
      final nonceBytes = secretBox.nonce;
      final macBytes = secretBox.mac.bytes;
      final cipherBytes = secretBox.cipherText;

      final buffer = BytesBuilder();
      buffer.add(headerBytes);
      buffer.add(nonceBytes);
      buffer.add(macBytes);
      buffer.add(cipherBytes);

      // 6. Guardar en la carpeta de Documentos del usuario
      final docsDir = await getApplicationDocumentsDirectory();
      final fechaStr = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final nombreArchivo = 'planteapp_backup_$fechaStr.bak';
      final archivoBak = File(join(docsDir.path, nombreArchivo));

      await archivoBak.writeAsBytes(buffer.toBytes(), flush: true);
      debugPrint('Respaldo cifrado exportado exitosamente: ${archivoBak.path}');
      return archivoBak;
    } catch (e, stack) {
      debugPrint('Error al exportar respaldo local: $e\n$stack');
      rethrow;
    }
  }

  /// Importa un archivo .bak previamente respaldado, descifra su contenido,
  /// valida su integridad y reemplaza la base de datos de forma transaccional y segura.
  static Future<bool> importarRespaldo(
    String rutaArchivoBak, {
    String? passwordPersonalizada,
  }) async {
    final archivoBak = File(rutaArchivoBak);
    if (!await archivoBak.exists()) {
      throw Exception('El archivo de respaldo seleccionado no existe.');
    }

    final bytesBak = await archivoBak.readAsBytes();
    final headerLength = _magicHeader.codeUnits.length;
    final minLength = headerLength + 12 + 16 + 16; // Header + Nonce + MAC + Min payload

    if (bytesBak.length < minLength) {
      throw Exception('El archivo .bak está dañado o no es un respaldo válido de Planteapp.');
    }

    // 1. Validar cabecera mágica
    final headerLeida = String.fromCharCodes(bytesBak.sublist(0, headerLength));
    if (headerLeida != _magicHeader) {
      throw Exception('Formato de respaldo desconocido o incompatible.');
    }

    // 2. Extraer Nonce (12 bytes), MAC Tag (16 bytes) y Ciphertext
    final nonce = bytesBak.sublist(headerLength, headerLength + 12);
    final macBytes = bytesBak.sublist(headerLength + 12, headerLength + 28);
    final cipherText = bytesBak.sublist(headerLength + 28);

    // 3. Descifrar datos
    List<int> bytesDescifrados;
    try {
      final secretKey = await _derivarClaveCifrado(passwordPersonalizada);
      // 4. Cifrar con AES-256-GCM (autenticado)
      final algorithm = AesGcm.with256bits();
      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      bytesDescifrados = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
    } catch (e) {
      throw Exception('Contraseña o clave de respaldo incorrecta, o archivo manipulado.');
    }

    // 4. Preparar rutas de reemplazo seguro y rollback
    final dbDir = await getDatabasesPath();
    final dbPath = join(dbDir, 'viverapp.db');
    final dbFile = File(dbPath);
    final rollbackFile = File('$dbPath.temp_rollback.bak');

    // Cerrar la conexión actual a la base de datos
    await BaseDeDatos.instancia.cerrar();

    // Crear copia de contingencia temporal si la base actual existe
    bool huboCopiaPrevia = false;
    if (await dbFile.exists()) {
      await dbFile.copy(rollbackFile.path);
      huboCopiaPrevia = true;
    }

    try {
      // 5. Reemplazar físicamente el archivo de la base de datos
      await dbFile.writeAsBytes(bytesDescifrados, flush: true);

      // 6. Validar integridad de las tablas esenciales abriendo la base de datos
      final dbVerificacion = await BaseDeDatos.instancia.database;
      final resultadoTablas = await dbVerificacion.rawQuery('''
        SELECT count(*) as total FROM sqlite_master 
        WHERE type='table' AND name IN ('productos', 'ventas', 'colaboradores');
      ''');

      final totalTablas = (resultadoTablas.first['total'] as int?) ?? 0;
      if (totalTablas < 3) {
        throw Exception('El respaldo no contiene el esquema requerido (faltan tablas maestras).');
      }

      // Si todo fue verificado con éxito, eliminar el archivo temporal de rollback
      if (huboCopiaPrevia && await rollbackFile.exists()) {
        await rollbackFile.delete();
      }

      debugPrint('Base de datos restaurada e importada con éxito.');
      return true;
    } catch (e, stack) {
      debugPrint('Fallo en la importación. Ejecutando rollback preventivo: $e\n$stack');

      // 7. Rollback seguro: restaurar la base de datos previa
      if (huboCopiaPrevia && await rollbackFile.exists()) {
        await BaseDeDatos.instancia.cerrar();
        await rollbackFile.copy(dbPath);
        await rollbackFile.delete();
        await BaseDeDatos.instancia.database; // Reabrir
      }
      rethrow;
    }
  }

  /// Deriva una [SecretKey] de 256 bits a partir de la contraseña personalizada
  /// o de la llave maestra del dispositivo.
  static Future<SecretKey> _derivarClaveCifrado(String? password) async {
    final String baseString;
    if (password != null && password.trim().isNotEmpty) {
      baseString = password.trim();
    } else {
      // Obtener la llave maestra protegida en hardware
      baseString = await SecureStorageService.instancia.obtenerClaveMaestraDb();
    }

    // SHA-256 para producir exactamente 32 bytes (256 bits) de entropía normalizada
    final sha256 = Sha256();
    final hash = await sha256.hash(baseString.codeUnits);
    return SecretKey(hash.bytes);
  }
}
