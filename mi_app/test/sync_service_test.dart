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

      // Sembrar datos locales con is_synced = 0
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

      // Ejecutar Push con interceptor remoto
      final resultado = await SyncService.instancia.pushLocalChanges(
        dbOverride: db,
        upsertHandlerOverride: (tabla, lote) async {
          llamadasRemotas.addAll(lote);
        },
      );

      expect(resultado.exitoso, isTrue);
      expect(resultado.totalSubidos, equals(3));
      expect(llamadasRemotas.length, equals(3));

      // Verificar que en SQLite local todos pasaron a is_synced = 1
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

      // Sembrar 12 productos pendientes
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

      // Ejecutar Push con batchSize de 5 (debe generar lotes: 5, 5, 2)
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

      // Validar que todos los 12 se marcaron como sincronizados
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

      // Simular fallo de red HTTP / Supabase
      final resultado = await SyncService.instancia.pushLocalChanges(
        dbOverride: db,
        upsertHandlerOverride: (tabla, lote) async {
          throw Exception('Simulación de fallo de red: Connection reset by peer (HTTP 500)');
        },
      );

      expect(resultado.exitoso, isFalse);
      expect(resultado.error, contains('Connection reset by peer'));

      // Verificar que el registro permanece en is_synced = 0 para futuros reintentos
      final prod = await db.query('productos', where: 'id = ?', whereArgs: ['PROD-FALLA']);
      expect(prod.first['is_synced'], equals(0));
    });
  });
}
