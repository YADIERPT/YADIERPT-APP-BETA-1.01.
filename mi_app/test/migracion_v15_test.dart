import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:mi_app/BaseDatos/base_datos.dart';
import 'package:mi_app/Modelos/movimiento_inventario.dart';
import 'package:mi_app/Modelos/elemento_cola_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Pruebas de Migración SQLite Esquema v14 -> v15 (Offline-First / Supabase)', () {
    late Database db;

    setUp(() async {
      // 1. Abrimos base de datos en memoria simulando versión 14
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 14,
        onConfigure: (d) async => await d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, version) async {
          await d.execute('''
            CREATE TABLE colaboradores (
              id TEXT PRIMARY KEY,
              nombre TEXT NOT NULL,
              clave TEXT NOT NULL,
              rol TEXT NOT NULL
            )
          ''');

          await d.execute('''
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

          await d.execute('''
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

          await d.execute('''
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

          await d.execute('''
            CREATE TABLE abonos_venta (
              id TEXT PRIMARY KEY,
              venta_id TEXT NOT NULL,
              monto REAL NOT NULL,
              fecha TEXT NOT NULL,
              metodoPago TEXT NOT NULL DEFAULT 'Efectivo',
              FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE
            )
          ''');

          await d.execute('''
            CREATE TABLE deudores (
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

          await d.execute('''
            CREATE VIRTUAL TABLE IF NOT EXISTS productos_fts USING fts5(
              nombre,
              notas,
              tipo,
              content='productos',
              content_rowid='rowid'
            )
          ''');

          await d.execute('''
            CREATE TRIGGER IF NOT EXISTS productos_fts_ai AFTER INSERT ON productos BEGIN
              INSERT INTO productos_fts(rowid, nombre, notas, tipo)
              VALUES (new.rowid, new.nombre, coalesce(new.notas, ''), new.tipo);
            END;
          ''');

          await d.execute('''
            CREATE TRIGGER IF NOT EXISTS productos_fts_ad AFTER DELETE ON productos BEGIN
              INSERT INTO productos_fts(productos_fts, rowid, nombre, notas, tipo)
              VALUES ('delete', old.rowid, old.nombre, coalesce(old.notas, ''), old.tipo);
            END;
          ''');

          await d.execute('''
            CREATE TRIGGER IF NOT EXISTS productos_fts_au AFTER UPDATE OF nombre, notas, tipo ON productos BEGIN
              INSERT INTO productos_fts(productos_fts, rowid, nombre, notas, tipo)
              VALUES ('delete', old.rowid, old.nombre, coalesce(old.notas, ''), old.tipo);
              INSERT INTO productos_fts(rowid, nombre, notas, tipo)
              VALUES (new.rowid, new.nombre, coalesce(new.notas, ''), new.tipo);
            END;
          ''');

          // Población inicial de datos reales/de prueba en v14
          await d.insert('colaboradores', {
            'id': 'VO-4092',
            'nombre': 'Admin Dueña',
            'clave': 'hash123',
            'rol': 'dueño',
          });

          await d.insert('productos', {
            'id': 'BOT-001',
            'nombre': 'Monstera Deliciosa',
            'notas': 'Luz tamizada',
            'precioVenta': 250.0,
            'costo': 100.0,
            'cantidadEnInventario': 12,
            'umbralStockCritico': 3,
            'tipo': 'planta',
            'activo': 1,
          });

          await d.insert('productos', {
            'id': 'ART-001',
            'nombre': 'Maceta Barro 20cm',
            'notas': 'Mortero clásico',
            'precioVenta': 80.0,
            'costo': 35.0,
            'cantidadEnInventario': 25,
            'umbralStockCritico': 5,
            'tipo': 'articulo',
            'activo': 1,
          });

          await d.insert('ventas', {
            'id': 'VEN-1001',
            'fecha': '2026-11-15T10:00:00Z',
            'estado': 'apartada',
            'porcentajeIva': 0.16,
            'aplicarIva': 1,
            'cliente': 'Carlos Botánico',
            'montoPagado': 100.0,
            'notas': 'Apartado 15 días',
          });

          await d.insert('articulos_venta', {
            'venta_id': 'VEN-1001',
            'producto_id': 'BOT-001',
            'cantidad': 1,
            'precioUnitario': 250.0,
          });

          await d.insert('deudores', {
            'id': 'deu_VEN-1001',
            'venta_id': 'VEN-1001',
            'cliente': 'Carlos Botánico',
            'telefono': '5512345678',
            'montoTotal': 290.0,
            'montoPagado': 100.0,
            'saldoPendiente': 190.0,
            'fechaRegistro': '2026-11-15T10:00:00Z',
            'estado': 'PENDIENTE',
          });

          await d.insert('abonos_venta', {
            'id': 'ABO-501',
            'venta_id': 'VEN-1001',
            'monto': 100.0,
            'fecha': '2026-11-15T10:05:00Z',
            'metodoPago': 'Efectivo',
          });
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Ejecuta migración v14 -> v15 poblando UUIDs, saldo_inicial, outbox y relaciones', () async {
      // 1. Ejecutar migración v14 -> v15
      await BaseDeDatos.instancia.actualizarEsquemaParaPruebas(db, 14, 15);

      // 2. Verificar que todas las tablas conservan exactamente el mismo número de filas (sin pérdidas)
      final colabs = await db.query('colaboradores');
      expect(colabs.length, equals(1));
      expect(colabs.first['uuid'], isNotNull);
      expect(colabs.first['sync_estado'], equals('pendiente'));

      final prods = await db.query('productos');
      expect(prods.length, equals(2));
      for (final p in prods) {
        expect(p['uuid'], isNotNull);
        expect(p['uuid'].toString().length, equals(36)); // Longitud de UUID v4
        expect(p['sync_estado'], equals('pendiente'));
      }

      final ventas = await db.query('ventas');
      expect(ventas.length, equals(1));
      expect(ventas.first['uuid'], isNotNull);

      // 3. Verificar que las relaciones se poblaron con los UUIDs correspondientes
      final arts = await db.query('articulos_venta');
      expect(arts.length, equals(1));
      expect(arts.first['venta_uuid'], equals(ventas.first['uuid']));
      expect(arts.first['producto_uuid'], equals(prods.firstWhere((p) => p['id'] == 'BOT-001')['uuid']));

      final deudores = await db.query('deudores');
      expect(deudores.length, equals(1));
      expect(deudores.first['venta_uuid'], equals(ventas.first['uuid']));

      final abonos = await db.query('abonos_venta');
      expect(abonos.length, equals(1));
      expect(abonos.first['venta_uuid'], equals(ventas.first['uuid']));
      expect(abonos.first['deudor_uuid'], equals(deudores.first['uuid']));

      // 4. Verificar que movimientos_inventario tiene los saldos iniciales exactos
      final movs = await db.query('movimientos_inventario');
      expect(movs.length, equals(2)); // Uno por BOT-001 y otro por ART-001

      final movMonstera = movs.firstWhere((m) => m['producto_uuid'] == prods.firstWhere((p) => p['id'] == 'BOT-001')['uuid']);
      expect(movMonstera['cantidad'], equals(12));
      expect(movMonstera['tipo'], equals('ajuste'));
      expect(movMonstera['motivo'], equals('saldo_inicial_migracion'));

      final movMaceta = movs.firstWhere((m) => m['producto_uuid'] == prods.firstWhere((p) => p['id'] == 'ART-001')['uuid']);
      expect(movMaceta['cantidad'], equals(25));
      expect(movMaceta['motivo'], equals('saldo_inicial_migracion'));

      // 5. Verificar cálculo de stock derivado desde movimientos
      final monsteraUuid = prods.firstWhere((p) => p['id'] == 'BOT-001')['uuid'].toString();
      final stockDerivado = await BaseDeDatos.instancia.calcularStockDesdeMovimientos(monsteraUuid, executor: db);
      expect(stockDerivado, equals(12));

      // 6. Verificar config_sync con dispositivo_id único
      final config = await db.query('config_sync');
      expect(config.length, equals(1));
      expect(config.first['dispositivo_id'], isNotNull);
      expect(config.first['sync_habilitada'], equals(0));

      // 7. Verificar que el trigger AFTER UPDATE actualiza sync_estado y updated_at sin bucles
      await db.update(
        'productos',
        {'notas': 'Notas actualizadas para probar trigger'},
        where: 'id = ?',
        whereArgs: ['BOT-001'],
      );

      final monsteraActualizada = await db.query('productos', where: 'id = ?', whereArgs: ['BOT-001']);
      expect(monsteraActualizada.first['sync_estado'], equals('pendiente'));
      expect(monsteraActualizada.first['updated_at'], isNotNull);
    });

    test('Validación directa de operaciones de BaseDeDatos oficial con esquema v15', () async {
      final dbOficial = await BaseDeDatos.instancia.database;

      // 1. Verificar dispositivo_id
      final dispId = await BaseDeDatos.instancia.obtenerDispositivoId();
      expect(dispId.length, equals(36));

      // 2. Probar encolarCambio (Outbox)
      final elem = ElementoColaSync(
        tabla: 'productos',
        registroUuid: 'uuid-test-999',
        operacion: 'upsert',
        payloadJson: '{"nombre": "Suculenta Test"}',
      );
      await BaseDeDatos.instancia.encolarCambio(elem);

      final cola = await dbOficial.query(
        'cola_sincronizacion',
        where: 'registro_uuid = ?',
        whereArgs: ['uuid-test-999'],
      );
      expect(cola.isNotEmpty, isTrue);
      expect(cola.first['operacion'], equals('upsert'));

      // 3. Probar registro de movimiento y recálculo acumulado
      final testProdUuid = 'uuid-prod-${const Uuid().v4()}';
      await BaseDeDatos.instancia.registrarMovimientoInventario(
        MovimientoInventario(
          productoUuid: testProdUuid,
          tipo: TipoMovimientoInventario.compra,
          cantidad: 50,
          motivo: 'Lote entrante',
        ),
      );
      await BaseDeDatos.instancia.registrarMovimientoInventario(
        MovimientoInventario(
          productoUuid: testProdUuid,
          tipo: TipoMovimientoInventario.venta,
          cantidad: -15,
          motivo: 'Venta mostrador',
        ),
      );
      await BaseDeDatos.instancia.registrarMovimientoInventario(
        MovimientoInventario(
          productoUuid: testProdUuid,
          tipo: TipoMovimientoInventario.ajuste,
          cantidad: -5,
          motivo: 'Merma',
        ),
      );

      final stockFinal = await BaseDeDatos.instancia.calcularStockDesdeMovimientos(testProdUuid);
      expect(stockFinal, equals(30)); // 50 - 15 - 5 = 30
    });

    test('FTS5 sigue operando correctamente tras migración v15', () async {
      await BaseDeDatos.instancia.actualizarEsquemaParaPruebas(db, 14, 15);
      final ftsRes = await db.rawQuery(
        "SELECT * FROM productos_fts WHERE productos_fts MATCH 'Monstera*'",
      );
      expect(ftsRes.isNotEmpty, isTrue);
      expect(ftsRes.first['nombre'], contains('Monstera'));
    });
  });
}
