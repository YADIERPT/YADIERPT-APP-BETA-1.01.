import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:mi_app/BaseDatos/base_datos.dart';
import 'package:mi_app/Servicios/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SyncService - Fase 2 (Push Batching)', () {
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

    test('1. Sube registros pendientes (is_synced == 0) y los actualiza a is_synced = 1 tras éxito', () async {
      final List<Map<String, dynamic>> llamadasRemotas = [];

      final prodUuid = const Uuid().v4();
      final ventaUuid = const Uuid().v4();
      final artUuid = const Uuid().v4();

      await db.insert('productos', {
        'id': 'PROD-001',
        'uuid': prodUuid,
        'nombre': 'Monstera Deliciosa',
        'precioVenta': 450.0,
        'costo': 200.0,
        'cantidadEnInventario': 8,
        'is_synced': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await db.insert('ventas', {
        'id': 'VEN-001',
        'uuid': ventaUuid,
        'fecha': DateTime.now().toUtc().toIso8601String(),
        'estado': 'completada',
        'porcentajeIva': 0.16,
        'aplicarIva': 1,
        'cliente': 'Carlos Jardines',
        'montoPagado': 450.0,
        'is_synced': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await db.insert('articulos_venta', {
        'uuid': artUuid,
        'venta_id': 'VEN-001',
        'venta_uuid': ventaUuid,
        'producto_id': 'PROD-001',
        'producto_uuid': prodUuid,
        'cantidad': 1,
        'precioUnitario': 450.0,
        'is_synced': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final resultado = await SyncService.instancia.pushLocalChanges(
        dbOverride: db,
        upsertHandlerOverride: (tabla, lote) async {
          llamadasRemotas.addAll(lote);
        },
      );

      expect(resultado.exitoso, isTrue);
      expect(resultado.totalSubidos, equals(3));
      expect(llamadasRemotas.length, equals(3));

      final productos = await db.query('productos', where: 'id = ?', whereArgs: ['PROD-001']);
      expect(productos.first['is_synced'], equals(1));
      expect(productos.first['sync_estado'], equals('sincronizado'));

      final ventas = await db.query('ventas', where: 'id = ?', whereArgs: ['VEN-001']);
      expect(ventas.first['is_synced'], equals(1));

      final arts = await db.query('articulos_venta', where: 'uuid = ?', whereArgs: [artUuid]);
      expect(arts.first['is_synced'], equals(1));
    });

    test('2. Agrupa datos en lotes (Batches) respetando el límite de batchSize', () async {
      final List<int> tamaniosLotes = [];

      for (var i = 1; i <= 12; i++) {
        await db.insert('productos', {
          'id': 'PROD-$i',
          'uuid': const Uuid().v4(),
          'nombre': 'Suculenta $i',
          'precioVenta': 80.0,
          'costo': 30.0,
          'cantidadEnInventario': 5,
          'is_synced': 0,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      final resultado = await SyncService.instancia.pushLocalChanges(
        dbOverride: db,
        batchSize: 5,
        upsertHandlerOverride: (tabla, lote) async {
          tamaniosLotes.add(lote.length);
        },
      );

      expect(resultado.exitoso, isTrue);
      expect(resultado.totalSubidos, equals(12));
      expect(tamaniosLotes, equals([5, 5, 2]));

      final pendientes = await db.query('productos', where: 'is_synced = ?', whereArgs: [0]);
      expect(pendientes, isEmpty);
    });

    test('3. CRÍTICO: Si la llamada remota falla, los registros NO se marcan como is_synced = 1', () async {
      await db.insert('productos', {
        'id': 'PROD-FALLA',
        'uuid': const Uuid().v4(),
        'nombre': 'Planta en Riesgo',
        'precioVenta': 120.0,
        'costo': 50.0,
        'cantidadEnInventario': 2,
        'is_synced': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final resultado = await SyncService.instancia.pushLocalChanges(
        dbOverride: db,
        upsertHandlerOverride: (tabla, lote) async {
          throw Exception('Simulación de fallo de red: Connection reset by peer (HTTP 500)');
        },
      );

      expect(resultado.exitoso, isFalse);
      expect(resultado.error, contains('Connection reset by peer'));

      final prod = await db.query('productos', where: 'id = ?', whereArgs: ['PROD-FALLA']);
      expect(prod.first['is_synced'], equals(0));
    });
  });

  group('SyncService - Fase 3 (Pull Incremental & Upsert Masivo)', () {
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

    test('4. Pull Incremental: Pide solo registros mayores a last_sync_timestamp', () async {
      const cursorAnterior = '2026-11-17T12:00:00Z';
      await SyncService.instancia.actualizarLastSyncTimestamp(cursorAnterior, db: db);

      String? cursorConsultado;

      final resultado = await SyncService.instancia.pullCloudChanges(
        dbOverride: db,
        pullHandlerOverride: (tabla, cursor) async {
          cursorConsultado = cursor;
          if (tabla == 'productos') {
            return [
              {
                'uuid': 'uuid-remoto-nuevo',
                'codigo_local': 'BOT-NUEVO',
                'nombre': 'Orquídea Blanca',
                'precio_venta': 300.0,
                'costo': 120.0,
                'stock': 4,
                'tipo': 'planta',
                'activo': true,
                'updated_at': '2026-11-17T13:00:00Z',
              }
            ];
          }
          return [];
        },
      );

      expect(cursorConsultado, equals(cursorAnterior));
      expect(resultado.exitoso, isTrue);
      expect(resultado.totalDescargados, equals(1));

      // Verificar que se insertó en SQLite marcado con is_synced = 1
      final prod = await db.query('productos', where: 'uuid = ?', whereArgs: ['uuid-remoto-nuevo']);
      expect(prod.length, equals(1));
      expect(prod.first['nombre'], equals('Orquídea Blanca'));
      expect(prod.first['is_synced'], equals(1));
      expect(prod.first['sync_estado'], equals('sincronizado'));

      // Verificar que el cursor se actualizó en SQLite
      final nuevoCursor = await SyncService.instancia.obtenerLastSyncTimestamp(db: db);
      expect(nuevoCursor, isNotNull);
      expect(nuevoCursor!.compareTo(cursorAnterior), greaterThan(0));
    });

    test('5. ¡CRÍTICO - Cero Duplicados!: Sobrescribe registro existente si coincide UUID (INSERT OR REPLACE)', () async {
      final uuidExistente = const Uuid().v4();

      // Sembrar producto existente localmente
      await db.insert('productos', {
        'id': 'LOCAL-10',
        'uuid': uuidExistente,
        'nombre': 'Ficus Antiguo',
        'precioVenta': 200.0,
        'costo': 100.0,
        'cantidadEnInventario': 2,
        'is_synced': 1,
        'updated_at': '2026-11-17T10:00:00Z',
      });

      // Simular cambio remoto con mismo UUID pero datos actualizados en la nube
      final resultado = await SyncService.instancia.pullCloudChanges(
        dbOverride: db,
        pullHandlerOverride: (tabla, cursor) async {
          if (tabla == 'productos') {
            return [
              {
                'uuid': uuidExistente,
                'codigo_local': 'LOCAL-10',
                'nombre': 'Ficus Actualizado desde Nube',
                'precio_venta': 250.0,
                'costo': 110.0,
                'stock': 9,
                'tipo': 'planta',
                'activo': true,
                'updated_at': '2026-11-17T15:00:00Z',
              }
            ];
          }
          return [];
        },
      );

      expect(resultado.exitoso, isTrue);

      // Verificar que NO hay duplicados: el conteo total con ese UUID debe ser exactamente 1
      final productos = await db.query('productos', where: 'uuid = ?', whereArgs: [uuidExistente]);
      expect(productos.length, equals(1));
      expect(productos.first['nombre'], equals('Ficus Actualizado desde Nube'));
      expect(productos.first['precioVenta'], equals(250.0));
      expect(productos.first['cantidadEnInventario'], equals(9));
      expect(productos.first['is_synced'], equals(1));
    });

    test('6. Tolerancia a fallo: Si ocurre un error, last_sync_timestamp no avanza', () async {
      const cursorOriginal = '2026-11-17T08:00:00Z';
      await SyncService.instancia.actualizarLastSyncTimestamp(cursorOriginal, db: db);

      final resultado = await SyncService.instancia.pullCloudChanges(
        dbOverride: db,
        pullHandlerOverride: (tabla, cursor) async {
          throw Exception('Simulación de fallo remoto: Timeout al descargar');
        },
      );

      expect(resultado.exitoso, isFalse);
      expect(resultado.error, contains('Timeout al descargar'));

      // Verificar que el timestamp NO se actualizó y conserva el cursor original
      final cursorActual = await SyncService.instancia.obtenerLastSyncTimestamp(db: db);
      expect(cursorActual, equals(cursorOriginal));
    });
  });
}
