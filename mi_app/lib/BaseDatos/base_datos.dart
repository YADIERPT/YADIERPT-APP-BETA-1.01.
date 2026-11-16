import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

import 'clave_base_datos.dart';
import '../Modelos/movimiento_inventario.dart';
import '../Modelos/elemento_cola_sync.dart';

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
        version: 15,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _crearEsquema,
        onUpgrade: _actualizarEsquema,
      );
    } else {
      dbInstancia = await openDatabase(
        path,
        version: 15,
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
    if (oldVersion < 14) {
      // Migración a Módulo Relacional de Deudores y Cuentas por Cobrar
      await db.execute('''
        CREATE TABLE IF NOT EXISTS deudores (
          id TEXT PRIMARY KEY,
          venta_id TEXT NOT NULL,
          cliente TEXT NOT NULL,
          telefono TEXT NOT NULL DEFAULT '',
          montoTotal REAL NOT NULL,
          montoPagado REAL NOT NULL,
          saldoPendiente REAL NOT NULL,
          fechaRegistro TEXT NOT NULL,
          fechaLimite TEXT,
          estado TEXT NOT NULL DEFAULT 'PENDIENTE',
          FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_deudores_venta_id ON deudores (venta_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_deudores_cliente ON deudores (cliente)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_deudores_estado ON deudores (estado)');

      // Migración retrospectiva de ventas apartadas existentes
      try {
        final ventasApartadas = await db.query(
          'ventas',
          where: "estado = 'apartada' OR estado = 'liquidada'",
        );
        for (final row in ventasApartadas) {
          final vId = row['id'].toString();
          final arts = await db.query('articulos_venta', where: 'venta_id = ?', whereArgs: [vId]);
          double subtotal = 0.0;
          for (final a in arts) {
            subtotal += ((a['cantidad'] as num?)?.toDouble() ?? 0.0) * ((a['precioUnitario'] as num?)?.toDouble() ?? 0.0);
          }
          final bool aplicarIva = row['aplicarIva'] == 1;
          final double iva = aplicarIva ? subtotal * ((row['porcentajeIva'] as num?)?.toDouble() ?? 0.16) : 0.0;
          final double total = subtotal + iva;
          final double pagado = (row['montoPagado'] as num?)?.toDouble() ?? 0.0;
          final double saldo = (total - pagado).clamp(0.0, double.infinity);

          await db.insert('deudores', {
            'id': 'deu_$vId',
            'venta_id': vId,
            'cliente': row['cliente']?.toString() ?? 'Cliente',
            'telefono': '',
            'montoTotal': total,
            'montoPagado': pagado,
            'saldoPendiente': saldo,
            'fechaRegistro': row['fecha']?.toString() ?? DateTime.now().toIso8601String(),
            'fechaLimite': null,
            'estado': saldo <= 0.01 ? 'LIQUIDADA' : 'PENDIENTE',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (_) {}
    }
    if (oldVersion < 15) {
      // 1. Respaldo preventivo antes de migrar a v15 (.pre_v15.bak)
      if (!kIsWeb && db.path.isNotEmpty) {
        try {
          final dbFile = File(db.path);
          if (await dbFile.exists()) {
            final backupPath = '${db.path}.pre_v15.bak';
            await dbFile.copy(backupPath);
            final walFile = File('${db.path}-wal');
            if (await walFile.exists()) {
              await walFile.copy('$backupPath-wal');
            }
          }
        } catch (e) {
          debugPrint('Aviso al crear respaldo .pre_v15.bak: $e');
        }
      }

      // 2. Tablas nuevas: movimientos_inventario, cola_sincronizacion, config_sync
      await db.execute('''
        CREATE TABLE IF NOT EXISTS movimientos_inventario (
          uuid TEXT PRIMARY KEY,
          producto_uuid TEXT NOT NULL,
          tipo TEXT NOT NULL,
          cantidad INTEGER NOT NULL,
          referencia_uuid TEXT,
          motivo TEXT,
          colaborador_uuid TEXT,
          dispositivo_id TEXT,
          sync_estado TEXT NOT NULL DEFAULT 'pendiente',
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_mov_inventario_prod ON movimientos_inventario (producto_uuid)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_mov_inventario_created ON movimientos_inventario (created_at)');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS cola_sincronizacion (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          tabla TEXT NOT NULL,
          registro_uuid TEXT NOT NULL,
          operacion TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          intentos INTEGER NOT NULL DEFAULT 0,
          ultimo_error TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cola_sync_created ON cola_sincronizacion (created_at ASC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cola_sync_registro ON cola_sincronizacion (tabla, registro_uuid)');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS config_sync (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          dispositivo_id TEXT NOT NULL,
          ultimo_pull_por_tabla TEXT NOT NULL DEFAULT '{}',
          ultima_sync_exitosa TEXT,
          sync_habilitada INTEGER NOT NULL DEFAULT 0
        )
      ''');

      final String dispositivoId = const Uuid().v4();
      await db.execute('''
        INSERT OR IGNORE INTO config_sync (id, dispositivo_id, ultimo_pull_por_tabla, sync_habilitada)
        VALUES (1, ?, '{}', 0)
      ''', [dispositivoId]);

      // 3. Agregar columnas de sincronización y UUIDs a las 6 tablas existentes
      final tablasSincronizables = [
        'colaboradores',
        'productos',
        'ventas',
        'articulos_venta',
        'deudores',
        'abonos_venta',
      ];

      for (final tabla in tablasSincronizables) {
        await _agregarColumnaSiNoExiste(db, tabla, 'uuid', 'TEXT');
        await _agregarColumnaSiNoExiste(db, tabla, 'updated_at', 'TEXT');
        await _agregarColumnaSiNoExiste(db, tabla, 'deleted_at', 'TEXT');
        await _agregarColumnaSiNoExiste(db, tabla, 'sync_estado', "TEXT NOT NULL DEFAULT 'pendiente'");
        await _agregarColumnaSiNoExiste(db, tabla, 'dispositivo_id', 'TEXT');
      }

      // Columnas relacionales UUID
      await _agregarColumnaSiNoExiste(db, 'articulos_venta', 'venta_uuid', 'TEXT');
      await _agregarColumnaSiNoExiste(db, 'articulos_venta', 'producto_uuid', 'TEXT');
      await _agregarColumnaSiNoExiste(db, 'deudores', 'venta_uuid', 'TEXT');
      await _agregarColumnaSiNoExiste(db, 'abonos_venta', 'venta_uuid', 'TEXT');
      await _agregarColumnaSiNoExiste(db, 'abonos_venta', 'deudor_uuid', 'TEXT');
      await _agregarColumnaSiNoExiste(db, 'abonos_venta', 'colaborador_uuid', 'TEXT');
      await _agregarColumnaSiNoExiste(db, 'ventas', 'colaborador_uuid', 'TEXT');

      // 4. Rellenar UUIDs para filas existentes que no lo tengan
      final nowIso = DateTime.now().toUtc().toIso8601String();
      for (final tabla in tablasSincronizables) {
        final filasSinUuid = await db.query(tabla, where: "uuid IS NULL OR uuid = ''");
        for (final fila in filasSinUuid) {
          final nuevoUuid = const Uuid().v4();
          final idFila = fila['id'];
          if (idFila != null) {
            await db.update(
              tabla,
              {
                'uuid': nuevoUuid,
                'updated_at': nowIso,
                'sync_estado': 'pendiente',
                'dispositivo_id': dispositivoId,
              },
              where: 'id = ?',
              whereArgs: [idFila],
            );
          }
        }
      }

      // 5. Vincular claves foráneas en formato UUID
      try {
        await db.execute('''
          UPDATE articulos_venta
          SET venta_uuid = (SELECT uuid FROM ventas WHERE ventas.id = articulos_venta.venta_id),
              producto_uuid = (SELECT uuid FROM productos WHERE productos.id = articulos_venta.producto_id)
          WHERE venta_uuid IS NULL OR producto_uuid IS NULL;
        ''');
      } catch (_) {}

      try {
        await db.execute('''
          UPDATE deudores
          SET venta_uuid = (SELECT uuid FROM ventas WHERE ventas.id = deudores.venta_id)
          WHERE venta_uuid IS NULL;
        ''');
      } catch (_) {}

      try {
        await db.execute('''
          UPDATE abonos_venta
          SET venta_uuid = (SELECT uuid FROM ventas WHERE ventas.id = abonos_venta.venta_id),
              deudor_uuid = (SELECT uuid FROM deudores WHERE deudores.venta_id = abonos_venta.venta_id)
          WHERE venta_uuid IS NULL OR deudor_uuid IS NULL;
        ''');
      } catch (_) {}

      // 6. Sembrar movimientos iniciales de inventario (saldo_inicial_migracion)
      try {
        final productos = await db.query('productos');
        for (final prod in productos) {
          final prodUuid = prod['uuid']?.toString();
          final stockActual = (prod['cantidadEnInventario'] as num?)?.toInt() ?? 0;
          if (prodUuid != null && prodUuid.isNotEmpty) {
            final existeMov = await db.query(
              'movimientos_inventario',
              where: 'producto_uuid = ? AND motivo = ?',
              whereArgs: [prodUuid, 'saldo_inicial_migracion'],
            );
            if (existeMov.isEmpty) {
              await db.insert('movimientos_inventario', {
                'uuid': const Uuid().v4(),
                'producto_uuid': prodUuid,
                'tipo': 'ajuste',
                'cantidad': stockActual,
                'referencia_uuid': null,
                'motivo': 'saldo_inicial_migracion',
                'colaborador_uuid': null,
                'dispositivo_id': dispositivoId,
                'sync_estado': 'pendiente',
                'created_at': nowIso,
              });
            }
          }
        }
      } catch (_) {}

      // 7. Índices únicos por UUID
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_colaboradores_uuid ON colaboradores (uuid)');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_productos_uuid ON productos (uuid)');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_ventas_uuid ON ventas (uuid)');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_articulos_venta_uuid ON articulos_venta (uuid)');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_deudores_uuid ON deudores (uuid)');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_abonos_venta_uuid ON abonos_venta (uuid)');

      // 8. Triggers automáticos para actualizar updated_at y sync_estado = 'pendiente'
      try {
        await db.execute('DROP TRIGGER IF EXISTS productos_fts_au');
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS productos_fts_au AFTER UPDATE OF nombre, notas, tipo ON productos BEGIN
            INSERT INTO productos_fts(productos_fts, rowid, nombre, notas, tipo)
            VALUES ('delete', old.rowid, old.nombre, coalesce(old.notas, ''), old.tipo);
            INSERT INTO productos_fts(rowid, nombre, notas, tipo)
            VALUES (new.rowid, new.nombre, coalesce(new.notas, ''), new.tipo);
          END;
        ''');
        await db.execute("INSERT INTO productos_fts(productos_fts) VALUES('rebuild')");
      } catch (_) {}

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_colaboradores_updated_at AFTER UPDATE ON colaboradores
        WHEN (NEW.sync_estado = OLD.sync_estado AND (NEW.updated_at IS OLD.updated_at OR NEW.updated_at = OLD.updated_at))
        BEGIN
          UPDATE colaboradores SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), sync_estado = 'pendiente' WHERE rowid = NEW.rowid;
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_productos_updated_at AFTER UPDATE ON productos
        WHEN (NEW.sync_estado = OLD.sync_estado AND (NEW.updated_at IS OLD.updated_at OR NEW.updated_at = OLD.updated_at))
        BEGIN
          UPDATE productos SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), sync_estado = 'pendiente' WHERE rowid = NEW.rowid;
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_ventas_updated_at AFTER UPDATE ON ventas
        WHEN (NEW.sync_estado = OLD.sync_estado AND (NEW.updated_at IS OLD.updated_at OR NEW.updated_at = OLD.updated_at))
        BEGIN
          UPDATE ventas SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), sync_estado = 'pendiente' WHERE rowid = NEW.rowid;
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_articulos_venta_updated_at AFTER UPDATE ON articulos_venta
        WHEN (NEW.sync_estado = OLD.sync_estado AND (NEW.updated_at IS OLD.updated_at OR NEW.updated_at = OLD.updated_at))
        BEGIN
          UPDATE articulos_venta SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), sync_estado = 'pendiente' WHERE rowid = NEW.rowid;
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_deudores_updated_at AFTER UPDATE ON deudores
        WHEN (NEW.sync_estado = OLD.sync_estado AND (NEW.updated_at IS OLD.updated_at OR NEW.updated_at = OLD.updated_at))
        BEGIN
          UPDATE deudores SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), sync_estado = 'pendiente' WHERE rowid = NEW.rowid;
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_abonos_venta_updated_at AFTER UPDATE ON abonos_venta
        WHEN (NEW.sync_estado = OLD.sync_estado AND (NEW.updated_at IS OLD.updated_at OR NEW.updated_at = OLD.updated_at))
        BEGIN
          UPDATE abonos_venta SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), sync_estado = 'pendiente' WHERE rowid = NEW.rowid;
        END;
      ''');
    }
  }

  @visibleForTesting
  Future<void> actualizarEsquemaParaPruebas(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await _actualizarEsquema(db, oldVersion, newVersion);
  }

  static Future<void> _agregarColumnaSiNoExiste(
    DatabaseExecutor db,
    String tabla,
    String columna,
    String tipoYDefault,
  ) async {
    try {
      await db.execute('ALTER TABLE $tabla ADD COLUMN $columna $tipoYDefault');
    } catch (_) {
      // La columna ya existe
    }
  }

  Future _crearEsquema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE colaboradores (
        id TEXT PRIMARY KEY,
        uuid TEXT,
        nombre TEXT NOT NULL,
        clave TEXT NOT NULL,
        rol TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        sync_estado TEXT NOT NULL DEFAULT 'pendiente',
        dispositivo_id TEXT
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_colaboradores_uuid ON colaboradores (uuid)');

    await db.execute('''
      CREATE TABLE productos (
        id TEXT PRIMARY KEY,
        uuid TEXT,
        nombre TEXT NOT NULL,
        notas TEXT,
        precioVenta REAL NOT NULL,
        costo REAL NOT NULL,
        cantidadEnInventario INTEGER NOT NULL,
        imagenes TEXT,
        umbralStockCritico INTEGER NOT NULL DEFAULT 5,
        tipo TEXT NOT NULL DEFAULT 'planta',
        activo INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT,
        deleted_at TEXT,
        sync_estado TEXT NOT NULL DEFAULT 'pendiente',
        dispositivo_id TEXT
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_productos_uuid ON productos (uuid)');

    await db.execute('''
      CREATE TABLE ventas (
        id TEXT PRIMARY KEY,
        uuid TEXT,
        colaborador_uuid TEXT,
        fecha TEXT NOT NULL,
        estado TEXT NOT NULL,
        porcentajeIva REAL NOT NULL,
        aplicarIva INTEGER NOT NULL,
        cliente TEXT NOT NULL DEFAULT 'Cliente Mostrador',
        montoPagado REAL NOT NULL DEFAULT 0.0,
        notas TEXT NOT NULL DEFAULT '',
        updated_at TEXT,
        deleted_at TEXT,
        sync_estado TEXT NOT NULL DEFAULT 'pendiente',
        dispositivo_id TEXT
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_ventas_uuid ON ventas (uuid)');

    await db.execute('''
      CREATE TABLE abonos_venta (
        id TEXT PRIMARY KEY,
        uuid TEXT,
        venta_id TEXT NOT NULL,
        venta_uuid TEXT,
        deudor_uuid TEXT,
        colaborador_uuid TEXT,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL,
        metodoPago TEXT NOT NULL DEFAULT 'Efectivo',
        updated_at TEXT,
        deleted_at TEXT,
        sync_estado TEXT NOT NULL DEFAULT 'pendiente',
        dispositivo_id TEXT,
        FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_abonos_venta_uuid ON abonos_venta (uuid)');

    await db.execute('''
      CREATE TABLE articulos_venta (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT,
        venta_id TEXT NOT NULL,
        venta_uuid TEXT,
        producto_id TEXT NOT NULL,
        producto_uuid TEXT,
        cantidad INTEGER NOT NULL,
        precioUnitario REAL NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        sync_estado TEXT NOT NULL DEFAULT 'pendiente',
        dispositivo_id TEXT,
        FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE,
        FOREIGN KEY (producto_id) REFERENCES productos (id)
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_articulos_venta_uuid ON articulos_venta (uuid)');

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

    await db.execute('''
      CREATE TABLE deudores (
        id TEXT PRIMARY KEY,
        uuid TEXT,
        venta_id TEXT NOT NULL,
        venta_uuid TEXT,
        cliente TEXT NOT NULL,
        telefono TEXT NOT NULL DEFAULT '',
        montoTotal REAL NOT NULL,
        montoPagado REAL NOT NULL,
        saldoPendiente REAL NOT NULL,
        fechaRegistro TEXT NOT NULL,
        fechaLimite TEXT,
        estado TEXT NOT NULL DEFAULT 'PENDIENTE',
        updated_at TEXT,
        deleted_at TEXT,
        sync_estado TEXT NOT NULL DEFAULT 'pendiente',
        dispositivo_id TEXT,
        FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_deudores_uuid ON deudores (uuid)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS movimientos_inventario (
        uuid TEXT PRIMARY KEY,
        producto_uuid TEXT NOT NULL,
        tipo TEXT NOT NULL,
        cantidad INTEGER NOT NULL,
        referencia_uuid TEXT,
        motivo TEXT,
        colaborador_uuid TEXT,
        dispositivo_id TEXT,
        sync_estado TEXT NOT NULL DEFAULT 'pendiente',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mov_inventario_prod ON movimientos_inventario (producto_uuid)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_mov_inventario_created ON movimientos_inventario (created_at)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cola_sincronizacion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tabla TEXT NOT NULL,
        registro_uuid TEXT NOT NULL,
        operacion TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        intentos INTEGER NOT NULL DEFAULT 0,
        ultimo_error TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cola_sync_created ON cola_sincronizacion (created_at ASC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cola_sync_registro ON cola_sincronizacion (tabla, registro_uuid)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS config_sync (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        dispositivo_id TEXT NOT NULL,
        ultimo_pull_por_tabla TEXT NOT NULL DEFAULT '{}',
        ultima_sync_exitosa TEXT,
        sync_habilitada INTEGER NOT NULL DEFAULT 0
      )
    ''');

    final String dispositivoId = const Uuid().v4();
    await db.execute('''
      INSERT OR IGNORE INTO config_sync (id, dispositivo_id, ultimo_pull_por_tabla, sync_habilitada)
      VALUES (1, ?, '{}', 0)
    ''', [dispositivoId]);

    // Índices de alto rendimiento para acelerar consultas y ordenamientos frecuentes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_productos_nombre ON productos (nombre)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_productos_activo ON productos (activo)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON ventas (fecha DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ventas_estado ON ventas (estado)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_articulos_venta_id ON articulos_venta (venta_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_abonos_venta_id ON abonos_venta (venta_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transacciones_fecha ON transacciones (fecha DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_deudores_venta_id ON deudores (venta_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_deudores_cliente ON deudores (cliente)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_deudores_estado ON deudores (estado)');

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
      CREATE TRIGGER IF NOT EXISTS productos_fts_au AFTER UPDATE OF nombre, notas, tipo ON productos BEGIN
        INSERT INTO productos_fts(productos_fts, rowid, nombre, notas, tipo)
        VALUES ('delete', old.rowid, old.nombre, coalesce(old.notas, ''), old.tipo);
        INSERT INTO productos_fts(rowid, nombre, notas, tipo)
        VALUES (new.rowid, new.nombre, coalesce(new.notas, ''), new.tipo);
      END;
    ''');

    // Triggers automáticos para actualizar updated_at y sync_estado = 'pendiente'
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_colaboradores_updated_at AFTER UPDATE ON colaboradores
      WHEN (NEW.sync_estado = OLD.sync_estado AND (NEW.updated_at IS OLD.updated_at OR NEW.updated_at = OLD.updated_at))
      BEGIN
        UPDATE colaboradores SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), sync_estado = 'pendiente' WHERE rowid = NEW.rowid;
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_productos_updated_at AFTER UPDATE ON productos
      WHEN (NEW.sync_estado = OLD.sync_estado AND (NEW.updated_at IS OLD.updated_at OR NEW.updated_at = OLD.updated_at))
      BEGIN
        UPDATE productos SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), sync_estado = 'pendiente' WHERE rowid = NEW.rowid;
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_ventas_updated_at AFTER UPDATE ON ventas
      WHEN (NEW.sync_estado = OLD.sync_estado AND (NEW.updated_at IS OLD.updated_at OR NEW.updated_at = OLD.updated_at))
      BEGIN
        UPDATE ventas SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), sync_estado = 'pendiente' WHERE rowid = NEW.rowid;
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_articulos_venta_updated_at AFTER UPDATE ON articulos_venta
      WHEN (NEW.sync_estado = OLD.sync_estado AND (NEW.updated_at IS OLD.updated_at OR NEW.updated_at = OLD.updated_at))
      BEGIN
        UPDATE articulos_venta SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), sync_estado = 'pendiente' WHERE rowid = NEW.rowid;
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_deudores_updated_at AFTER UPDATE ON deudores
      WHEN (NEW.sync_estado = OLD.sync_estado AND (NEW.updated_at IS OLD.updated_at OR NEW.updated_at = OLD.updated_at))
      BEGIN
        UPDATE deudores SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), sync_estado = 'pendiente' WHERE rowid = NEW.rowid;
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_abonos_venta_updated_at AFTER UPDATE ON abonos_venta
      WHEN (NEW.sync_estado = OLD.sync_estado AND (NEW.updated_at IS OLD.updated_at OR NEW.updated_at = OLD.updated_at))
      BEGIN
        UPDATE abonos_venta SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), sync_estado = 'pendiente' WHERE rowid = NEW.rowid;
      END;
    ''');
  }

  /// Retorna el identificador único persistido de este dispositivo
  Future<String> obtenerDispositivoId() async {
    final db = await database;
    final res = await db.query('config_sync', where: 'id = 1');
    if (res.isNotEmpty && res.first['dispositivo_id'] != null) {
      return res.first['dispositivo_id'].toString();
    }
    final nuevoId = const Uuid().v4();
    await db.insert(
      'config_sync',
      {
        'id': 1,
        'dispositivo_id': nuevoId,
        'ultimo_pull_por_tabla': '{}',
        'sync_habilitada': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return nuevoId;
  }

  /// Calcula el stock disponible de un producto sumando todos sus movimientos (Append-Only)
  Future<int> calcularStockDesdeMovimientos(
    String productoUuid, {
    DatabaseExecutor? executor,
  }) async {
    final dbEx = executor ?? (await database);
    final res = await dbEx.rawQuery(
      'SELECT COALESCE(SUM(cantidad), 0) as total FROM movimientos_inventario WHERE producto_uuid = ?',
      [productoUuid],
    );
    return (res.first['total'] as num?)?.toInt() ?? 0;
  }

  /// Registra un movimiento de existencias dentro o fuera de una transacción ACID
  Future<void> registrarMovimientoInventario(
    MovimientoInventario mov, {
    DatabaseExecutor? executor,
  }) async {
    final dbEx = executor ?? (await database);
    await dbEx.insert(
      'movimientos_inventario',
      mov.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Encola una operación en la cola de salida (Outbox Pattern)
  Future<void> encolarCambio(
    ElementoColaSync elem, {
    DatabaseExecutor? executor,
  }) async {
    final dbEx = executor ?? (await database);
    await dbEx.insert(
      'cola_sincronizacion',
      elem.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future cerrar() async {
    final db = await instancia.database;
    db.close();
    _database = null;
  }
}
