import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

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
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 8,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _crearEsquema,
      onUpgrade: _actualizarEsquema,
    );
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
        tipo TEXT NOT NULL DEFAULT 'planta'
      )
    ''');
    await db.execute('''
      CREATE TABLE ventas (
        id TEXT PRIMARY KEY,
        fecha TEXT NOT NULL,
        estado TEXT NOT NULL,
        porcentajeIva REAL NOT NULL,
        aplicarIva INTEGER NOT NULL
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
  }

  Future cerrar() async {
    final db = await instancia.database;
    db.close();
    _database = null;
  }
}
