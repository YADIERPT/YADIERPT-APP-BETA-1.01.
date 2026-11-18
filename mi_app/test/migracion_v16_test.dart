import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:mi_app/BaseDatos/base_datos.dart';
import 'package:mi_app/Modelos/corte_caja.dart';
import 'package:mi_app/Modelos/producto.dart';
import 'package:mi_app/Modelos/venta.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Pruebas de Migración SQLite Esquema v15 -> v16 (UUIDs, articulos_venta PK y cortes_caja)', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 15,
        onConfigure: (d) async => await d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, version) async {
          await BaseDeDatos.instancia.crearEsquemaParaPruebas(d, 15);
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Ejecuta migración v15 -> v16 recreando articulos_venta con UUID PK y agregando cortes_caja', () async {
      // 1. Insertar datos previos en v15
      final prodUuid = const Uuid().v4();
      final ventaUuid = const Uuid().v4();
      final artUuid = const Uuid().v4();

      await db.insert('productos', {
        'id': 'PROD-101',
        'uuid': prodUuid,
        'nombre': 'Suculenta Echeveria',
        'precioVenta': 65.0,
        'costo': 25.0,
        'cantidadEnInventario': 10,
        'activo': 1,
        'is_synced': 1,
        'updated_at': '2026-11-18T00:00:00Z',
      });

      await db.insert('ventas', {
        'id': ventaUuid,
        'uuid': ventaUuid,
        'fecha': '2026-11-18T00:05:00Z',
        'estado': 'completada',
        'porcentajeIva': 0.16,
        'aplicarIva': 1,
        'montoPagado': 65.0,
        'is_synced': 1,
        'updated_at': '2026-11-18T00:05:00Z',
      });

      await db.insert('articulos_venta', {
        'id': 1, // ID entero autoincremental en v15
        'uuid': artUuid,
        'venta_id': ventaUuid,
        'venta_uuid': ventaUuid,
        'producto_id': 'PROD-101',
        'producto_uuid': prodUuid,
        'cantidad': 1,
        'precioUnitario': 65.0,
        'is_synced': 1,
        'updated_at': '2026-11-18T00:05:00Z',
      });

      // 2. Ejecutar migración v15 -> v16
      await BaseDeDatos.instancia.actualizarEsquemaParaPruebas(db, 15, 16);

      // 3. Validar que created_at existe en todas las tablas maestras
      final tablas = [
        'colaboradores',
        'productos',
        'ventas',
        'articulos_venta',
        'deudores',
        'abonos_venta',
      ];
      for (final t in tablas) {
        final cols = await db.rawQuery('PRAGMA table_info($t)');
        final tieneCreatedAt = cols.any((c) => c['name'] == 'created_at');
        expect(tieneCreatedAt, isTrue, reason: 'Tabla $t debe contener created_at');
      }

      // 4. Validar que articulos_venta ahora tiene id TEXT PRIMARY KEY conteniendo el UUID
      final articulosInfo = await db.rawQuery('PRAGMA table_info(articulos_venta)');
      final idCol = articulosInfo.firstWhere((c) => c['name'] == 'id');
      expect(idCol['type'].toString().toUpperCase(), contains('TEXT'));
      expect(idCol['pk'], equals(1)); // Primary Key

      // Validar que los datos de articulos_venta migraron intactos
      final articulosMigrados = await db.query('articulos_venta');
      expect(articulosMigrados.length, equals(1));
      expect(articulosMigrados.first['id'], equals(artUuid));
      expect(articulosMigrados.first['uuid'], equals(artUuid));
      expect(articulosMigrados.first['created_at'], isNotNull);

      // 5. Validar tabla cortes_caja
      final cortesInfo = await db.rawQuery('PRAGMA table_info(cortes_caja)');
      expect(cortesInfo.isNotEmpty, isTrue);

      final corte = CorteCaja(
        colaboradorUuid: 'COLAB-001',
        dispositivoId: 'TERMINAL-A',
        montoApertura: 500.0,
        montoVentasEfectivo: 350.0,
        montoAbonosEfectivo: 100.0,
        montoEgresos: 50.0,
        montoReal: 900.0,
      );

      expect(corte.montoEsperado, equals(900.0));
      expect(corte.diferencia, equals(0.0));

      await db.insert('cortes_caja', corte.toMap());

      final cortesEnDb = await db.query('cortes_caja');
      expect(cortesEnDb.length, equals(1));
      expect(cortesEnDb.first['uuid'], equals(corte.uuid));
      expect(cortesEnDb.first['id'], equals(corte.id));
      expect(cortesEnDb.first['monto_apertura'], equals(500.0));
      expect(cortesEnDb.first['is_synced'], equals(0));

      // 6. Probar trigger trg_cortes_caja_updated_at
      await db.update(
        'cortes_caja',
        {'monto_real': 920.0},
        where: 'uuid = ?',
        whereArgs: [corte.uuid],
      );

      final corteActualizado = await db.query('cortes_caja', where: 'uuid = ?', whereArgs: [corte.uuid]);
      expect(corteActualizado.first['updated_at'], isNotNull);
      expect(corteActualizado.first['sync_estado'], equals('pendiente'));
    });

    test('Modelo ArticuloVenta opera correctamente con ID String UUID', () {
      final prod = Producto(
        id: const Uuid().v4(),
        nombre: 'Cactus Órgano',
        precioVenta: 120.0,
        costo: 50.0,
        cantidadEnInventario: 5,
      );

      final art = ArticuloVenta(
        producto: prod,
        cantidad: 2,
        precioUnitario: 120.0,
      );

      expect(art.id, isNotEmpty);
      expect(art.uuid, isNotEmpty);
      expect(art.id, equals(art.uuid));
      expect(art.subtotal, equals(240.0));

      final mapa = art.toMap('VENTA-123');
      expect(mapa['id'], equals(art.id));
      expect(mapa['uuid'], equals(art.uuid));
      expect(mapa['created_at'], isNotNull);

      final artFromMap = ArticuloVenta.fromMap(mapa, prod);
      expect(artFromMap.id, equals(art.id));
      expect(artFromMap.uuid, equals(art.uuid));
      expect(artFromMap.cantidad, equals(2));
    });

    test('Decremento atómico en SQL previene condiciones de carrera en inventario', () async {
      final prodId = const Uuid().v4();
      await db.insert('productos', {
        'id': prodId,
        'uuid': prodId,
        'nombre': 'Ficus Lyrata',
        'precioVenta': 500.0,
        'costo': 200.0,
        'cantidadEnInventario': 10,
        'activo': 1,
        'is_synced': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Terminal A descuenta 4 unidades atómicamente
      final filasA = await db.rawUpdate('''
        UPDATE productos 
        SET cantidadEnInventario = cantidadEnInventario - ?
        WHERE id = ? AND cantidadEnInventario >= ?
      ''', [4, prodId, 4]);
      expect(filasA, equals(1));

      // Terminal B descuenta 5 unidades atómicamente
      final filasB = await db.rawUpdate('''
        UPDATE productos 
        SET cantidadEnInventario = cantidadEnInventario - ?
        WHERE id = ? AND cantidadEnInventario >= ?
      ''', [5, prodId, 5]);
      expect(filasB, equals(1));

      // Stock restante debe ser 10 - 4 - 5 = 1
      final pFinal = await db.query('productos', where: 'id = ?', whereArgs: [prodId]);
      expect(pFinal.first['cantidadEnInventario'], equals(1));

      // Intento de sobreventa: Terminal C intenta descontar 3 unidades (solo hay 1)
      final filasC = await db.rawUpdate('''
        UPDATE productos 
        SET cantidadEnInventario = cantidadEnInventario - ?
        WHERE id = ? AND cantidadEnInventario >= ?
      ''', [3, prodId, 3]);
      expect(filasC, equals(0)); // Bloqueado a nivel motor SQL
    });
  });
}

