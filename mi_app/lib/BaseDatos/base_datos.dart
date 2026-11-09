import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:path/path.dart';

import 'clave_base_datos.dart';

class BaseDeDatos {
  static final BaseDeDatos instancia = BaseDeDatos._init();
  static Database? _database;

  BaseDeDatos._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _inicializarDB('viverapp.db');
    return _database!;
  }

  Future<Database> _inicializarDB(String filePath) async {
    String path = filePath;
    final String password = await ClaveBaseDatos.obtenerClaveSegura();

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      path = filePath;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    } else {
      // Android / iOS: SQLCipher nativo AES-256
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
      await _migrarSiEsTextoPlano(path, password);
    }

    final Database dbInstancia;
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      dbInstancia = await sqlcipher.openDatabase(
        path,
        password: password,
        version: 13,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _crearEsquema,
        onUpgrade: _actualizarEsquema,
      );
    } else {
      dbInstancia = await openDatabase(
        path,
        version: 13,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _crearEsquema,
        onUpgrade: _actualizarEsquema,
      );
    }

    // Activación de concurrencia real mediante Write-Ahead Logging (WAL)
    // y optimización de durabilidad transaccional sin sacrificar integridad ACID.
    if (!kIsWeb) {
      try {
        await dbInstancia.execute('PRAGMA journal_mode = WAL');
        await dbInstancia.execute('PRAGMA synchronous = NORMAL');
      } catch (e) {
        debugPrint('Aviso al configurar WAL en SQLite: $e');
      }
    }

    return dbInstancia;
  }

  /// Migra una base de datos preexistente en texto plano hacia SQLCipher AES-256
  /// sin pérdida ni corrupción de inventario ni ventas históricas.
  Future<void> _migrarSiEsTextoPlano(String dbPath, String password) async {
    try {
      final file = File(dbPath);
      if (!await file.exists()) return;
      final length = await file.length();
      if (length < 16) return;

      // Leer cabecera mágica de SQLite: 'SQLite format 3\000'
      final handle = await file.open(mode: FileMode.read);
      final header = await handle.read(16);
      await handle.close();

      const sqliteHeader = [
        0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
        0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00
      ];

      bool esTextoPlano = true;
      for (int i = 0; i < 16; i++) {
        if (header[i] != sqliteHeader[i]) {
          esTextoPlano = false;
          break;
        }
      }

      if (!esTextoPlano) {
        // La base de datos ya está cifrada con SQLCipher
        return;
      }

      // 1. Respaldo preventivo antes de la migración
      final backupPath = '$dbPath.unencrypted.bak';
      await file.copy(backupPath);

      // 2. Archivo temporal de destino cifrado
      final encryptedPath = '$dbPath.encrypted.tmp';
      final encryptedFile = File(encryptedPath);
      if (await encryptedFile.exists()) {
        await encryptedFile.delete();
      }

      // 3. Exportación atómica mediante SQLCipher export
      final dbPlana = await openDatabase(dbPath);
      try {
        await dbPlana.execute("ATTACH DATABASE ? AS encrypted KEY ?", [
          encryptedPath,
          password,
        ]);
        await dbPlana.rawQuery("SELECT sqlcipher_export('encrypted')");
        await dbPlana.execute("DETACH DATABASE encrypted");
        await dbPlana.close();

        // 4. Reemplazo transparente del archivo
        if (await encryptedFile.exists() && await encryptedFile.length() > 0) {
          await file.delete();
          await encryptedFile.rename(dbPath);
        }
      } catch (_) {
        await dbPlana.close();
        if (await encryptedFile.exists()) {
          await encryptedFile.delete();
        }
      }
    } catch (_) {
      // Manejo silencioso defensivo para evitar caídas en arranque
    }
  }

  Future _actualizarEsquema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE colaboradores (
          id TEXT PRIMARY KEY,
          nombre TEXT NOT NULL,
          clave TEXT NOT NULL,
          rol TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE configuracion ADD COLUMN etiquetasJson TEXT NOT NULL DEFAULT \'["Interior", "Suculentas", "Macetas", "Regalos"]\'',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE configuracion ADD COLUMN aplicarIva INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE ventas ADD COLUMN aplicarIva INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE productos ADD COLUMN umbralStockCritico INTEGER NOT NULL DEFAULT 5',
      );
    }
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE productos ADD COLUMN tipo TEXT NOT NULL DEFAULT \'planta\'',
      );
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE configuracion_biometrica (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          biometriaHabilitada INTEGER NOT NULL DEFAULT 0,
          usuarioVinculadoId TEXT,
          nombreHuella TEXT,
          fechaRegistro TEXT,
          tipoConexion TEXT NOT NULL DEFAULT 'local',
          wifiHost TEXT NOT NULL DEFAULT '192.168.1.100',
          wifiPuerto INTEGER NOT NULL DEFAULT 4370,
          bluetoothDispositivo TEXT NOT NULL DEFAULT '',
          cablePuertoSerial TEXT NOT NULL DEFAULT 'COM3',
          cableBaudRate INTEGER NOT NULL DEFAULT 9600,
          ultimoEstadoConexion TEXT NOT NULL DEFAULT 'Desconectado'
        )
      ''');
      await db.execute('''
        INSERT INTO configuracion_biometrica (
          id, biometriaHabilitada, usuarioVinculadoId, nombreHuella, fechaRegistro,
          tipoConexion, wifiHost, wifiPuerto, bluetoothDispositivo, cablePuertoSerial,
          cableBaudRate, ultimoEstadoConexion
        ) VALUES (
          1, 0, NULL, NULL, NULL,
          'local', '192.168.1.100', 4370, '', 'COM3', 9600, 'Desconectado'
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE ia_calibracion_productos (
          producto_id TEXT PRIMARY KEY,
          velocidad_diaria REAL NOT NULL DEFAULT 0.0,
          variabilidad REAL NOT NULL DEFAULT 0.0,
          dias_cobertura REAL NOT NULL DEFAULT 999.0,
          tendencia REAL NOT NULL DEFAULT 0.0,
          nivel_rotacion TEXT NOT NULL DEFAULT 'MEDIA',
          score_prioridad REAL NOT NULL DEFAULT 0.0,
          ultima_calibracion TEXT NOT NULL,
          total_unidades_historicas INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE ia_sugerencias_compra (
          id TEXT PRIMARY KEY,
          producto_id TEXT NOT NULL,
          cantidad_sugerida INTEGER NOT NULL,
          costo_estimado REAL NOT NULL,
          ganancia_estimada REAL NOT NULL,
          nivel_urgencia TEXT NOT NULL,
          motivo_razonado TEXT NOT NULL,
          dias_hasta_agotamiento REAL NOT NULL,
          fecha_generacion TEXT NOT NULL,
          estado TEXT NOT NULL DEFAULT 'PENDIENTE',
          FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 10) {
      await db.execute(
        "ALTER TABLE ventas ADD COLUMN cliente TEXT NOT NULL DEFAULT 'Cliente Mostrador'",
      );
      await db.execute(
        "ALTER TABLE ventas ADD COLUMN montoPagado REAL NOT NULL DEFAULT 0.0",
      );
      await db.execute(
        "ALTER TABLE ventas ADD COLUMN notas TEXT NOT NULL DEFAULT ''",
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS abonos_venta (
          id TEXT PRIMARY KEY,
          venta_id TEXT NOT NULL,
          monto REAL NOT NULL,
          fecha TEXT NOT NULL,
          metodoPago TEXT NOT NULL DEFAULT 'Efectivo',
          FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 11) {
      // Índices de alto rendimiento para acelerar consultas y ordenamientos frecuentes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_productos_nombre ON productos (nombre)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON ventas (fecha DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_estado ON ventas (estado)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_articulos_venta_id ON articulos_venta (venta_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_abonos_venta_id ON abonos_venta (venta_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transacciones_fecha ON transacciones (fecha DESC)');
    }
    if (oldVersion < 12) {
      // Migración para Soft Delete (Borrado Lógico) de Productos
      try {
        await db.execute(
          'ALTER TABLE productos ADD COLUMN activo INTEGER NOT NULL DEFAULT 1',
        );
      } catch (_) {}
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_productos_activo ON productos (activo)',
      );
    }
    if (oldVersion < 13) {
      // Migración a FTS5 (Full-Text Search) para búsqueda botánica de alto rendimiento
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS productos_fts USING fts5(
          nombre,
          notas,
          tipo,
          content='productos',
          content_rowid='rowid'
        )
      ''');

      // Población e indexación inicial desde productos preexistentes
      await db.execute('''
        INSERT INTO productos_fts(rowid, nombre, notas, tipo)
        SELECT rowid, nombre, coalesce(notas, ''), tipo FROM productos
      ''');

      // Trigger de sincronización en inserción (INSERT)
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS productos_fts_ai AFTER INSERT ON productos BEGIN
          INSERT INTO productos_fts(rowid, nombre, notas, tipo)
          VALUES (new.rowid, new.nombre, coalesce(new.notas, ''), new.tipo);
        END;
      ''');

      // Trigger de sincronización en eliminación física (DELETE)
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS productos_fts_ad AFTER DELETE ON productos BEGIN
          INSERT INTO productos_fts(productos_fts, rowid, nombre, notas, tipo)
          VALUES ('delete', old.rowid, old.nombre, coalesce(old.notas, ''), old.tipo);
        END;
      ''');

      // Trigger de sincronización en actualización (UPDATE)
      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS productos_fts_au AFTER UPDATE ON productos BEGIN
          INSERT INTO productos_fts(productos_fts, rowid, nombre, notas, tipo)
          VALUES ('delete', old.rowid, old.nombre, coalesce(old.notas, ''), old.tipo);
          INSERT INTO productos_fts(rowid, nombre, notas, tipo)
          VALUES (new.rowid, new.nombre, coalesce(new.notas, ''), new.tipo);
        END;
      ''');
    }
  }

  Future _crearEsquema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE colaboradores (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        clave TEXT NOT NULL,
        rol TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE productos (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        notas TEXT,
        precioVenta REAL NOT NULL,
        costo REAL NOT NULL,
        cantidadEnInventario INTEGER NOT NULL,
        imagenes TEXT,
        umbralStockCritico INTEGER NOT NULL DEFAULT 5,
        tipo TEXT NOT NULL DEFAULT 'planta',
        activo INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE ventas (
        id TEXT PRIMARY KEY,
        fecha TEXT NOT NULL,
        estado TEXT NOT NULL,
        porcentajeIva REAL NOT NULL,
        aplicarIva INTEGER NOT NULL,
        cliente TEXT NOT NULL DEFAULT 'Cliente Mostrador',
        montoPagado REAL NOT NULL DEFAULT 0.0,
        notas TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE abonos_venta (
        id TEXT PRIMARY KEY,
        venta_id TEXT NOT NULL,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL,
        metodoPago TEXT NOT NULL DEFAULT 'Efectivo',
        FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE articulos_venta (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venta_id TEXT NOT NULL,
        producto_id TEXT NOT NULL,
        cantidad INTEGER NOT NULL,
        precioUnitario REAL NOT NULL,
        FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE,
        FOREIGN KEY (producto_id) REFERENCES productos (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE transacciones (
        id TEXT PRIMARY KEY,
        tipo TEXT NOT NULL,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL,
        descripcion TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE configuracion (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        temaOscuro INTEGER NOT NULL,
        tipoCambioUSD REAL NOT NULL,
        porcentajeIvaDefecto REAL NOT NULL,
        aplicarIva INTEGER NOT NULL,
        etiquetasJson TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT INTO configuracion (id, temaOscuro, tipoCambioUSD, porcentajeIvaDefecto, aplicarIva, etiquetasJson)
      VALUES (1, 2, 18.0, 0.16, 1, '["Interior", "Suculentas", "Macetas", "Regalos"]')
    ''');
    await db.execute('''
      CREATE TABLE configuracion_biometrica (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        biometriaHabilitada INTEGER NOT NULL DEFAULT 0,
        usuarioVinculadoId TEXT,
        nombreHuella TEXT,
        fechaRegistro TEXT,
        tipoConexion TEXT NOT NULL DEFAULT 'local',
        wifiHost TEXT NOT NULL DEFAULT '192.168.1.100',
        wifiPuerto INTEGER NOT NULL DEFAULT 4370,
        bluetoothDispositivo TEXT NOT NULL DEFAULT '',
        cablePuertoSerial TEXT NOT NULL DEFAULT 'COM3',
        cableBaudRate INTEGER NOT NULL DEFAULT 9600,
        ultimoEstadoConexion TEXT NOT NULL DEFAULT 'Desconectado'
      )
    ''');
    await db.execute('''
      INSERT INTO configuracion_biometrica (
        id, biometriaHabilitada, usuarioVinculadoId, nombreHuella, fechaRegistro,
        tipoConexion, wifiHost, wifiPuerto, bluetoothDispositivo, cablePuertoSerial,
        cableBaudRate, ultimoEstadoConexion
      ) VALUES (
        1, 0, NULL, NULL, NULL,
        'local', '192.168.1.100', 4370, '', 'COM3', 9600, 'Desconectado'
      )
    ''');
    await db.execute('''
      CREATE TABLE ia_calibracion_productos (
        producto_id TEXT PRIMARY KEY,
        velocidad_diaria REAL NOT NULL DEFAULT 0.0,
        variabilidad REAL NOT NULL DEFAULT 0.0,
        dias_cobertura REAL NOT NULL DEFAULT 999.0,
        tendencia REAL NOT NULL DEFAULT 0.0,
        nivel_rotacion TEXT NOT NULL DEFAULT 'MEDIA',
        score_prioridad REAL NOT NULL DEFAULT 0.0,
        ultima_calibracion TEXT NOT NULL,
        total_unidades_historicas INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE ia_sugerencias_compra (
        id TEXT PRIMARY KEY,
        producto_id TEXT NOT NULL,
        cantidad_sugerida INTEGER NOT NULL,
        costo_estimado REAL NOT NULL,
        ganancia_estimada REAL NOT NULL,
        nivel_urgencia TEXT NOT NULL,
        motivo_razonado TEXT NOT NULL,
        dias_hasta_agotamiento REAL NOT NULL,
        fecha_generacion TEXT NOT NULL,
        estado TEXT NOT NULL DEFAULT 'PENDIENTE',
        FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
      )
    ''');

    // Índices de alto rendimiento para acelerar consultas y ordenamientos frecuentes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_productos_nombre ON productos (nombre)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_productos_activo ON productos (activo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON ventas (fecha DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_estado ON ventas (estado)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_articulos_venta_id ON articulos_venta (venta_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_abonos_venta_id ON abonos_venta (venta_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transacciones_fecha ON transacciones (fecha DESC)');

    // Motor de búsqueda indexada FTS5 (Full-Text Search)
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS productos_fts USING fts5(
        nombre,
        notas,
        tipo,
        content='productos',
        content_rowid='rowid'
      )
    ''');

    // Triggers de sincronización automática para FTS5
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS productos_fts_ai AFTER INSERT ON productos BEGIN
        INSERT INTO productos_fts(rowid, nombre, notas, tipo)
        VALUES (new.rowid, new.nombre, coalesce(new.notas, ''), new.tipo);
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS productos_fts_ad AFTER DELETE ON productos BEGIN
        INSERT INTO productos_fts(productos_fts, rowid, nombre, notas, tipo)
        VALUES ('delete', old.rowid, old.nombre, coalesce(old.notas, ''), old.tipo);
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS productos_fts_au AFTER UPDATE ON productos BEGIN
        INSERT INTO productos_fts(productos_fts, rowid, nombre, notas, tipo)
        VALUES ('delete', old.rowid, old.nombre, coalesce(old.notas, ''), old.tipo);
        INSERT INTO productos_fts(rowid, nombre, notas, tipo)
        VALUES (new.rowid, new.nombre, coalesce(new.notas, ''), new.tipo);
      END;
    ''');
  }

  Future cerrar() async {
    final db = await instancia.database;
    db.close();
    _database = null;
  }
}
