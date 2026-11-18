import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:mi_app/BaseDatos/base_datos.dart';
import 'package:mi_app/Configuracion/supabase_config.dart';
import 'package:mi_app/Servicios/servicio_supabase.dart';
import 'package:mi_app/Servicios/servicio_conectividad.dart';
import 'package:mi_app/Servicios/servicio_sincronizacion.dart';
import 'package:mi_app/Controladores/controlador_sincronizacion.dart';
import 'package:mi_app/Modelos/movimiento_inventario.dart';
import 'package:mi_app/Modelos/elemento_cola_sync.dart';

/// Simulador en memoria de la base de datos remota de Supabase / Postgres.
/// Almacena tablas remotas en memoria y replica el comportamiento de upsert por UUID y filtrado por cursor.
class SimuladorRemotoMemoria implements FuenteRemotaSincronizacion {
  final Map<String, List<Map<String, dynamic>>> tablas = {
    'colaboradores': [],
    'productos': [],
    'ventas': [],
    'articulos_venta': [],
    'deudores': [],
    'abonos_venta': [],
    'movimientos_inventario': [],
  };

  final List<String> ordenLlamadasUpsert = [];
  bool lanzarErrorIntencional = false;

  @override
  Future<void> upsertLote(String tabla, List<Map<String, dynamic>> registros) async {
    if (lanzarErrorIntencional) {
      throw Exception('Simulación de fallo de red remoto (HTTP 503 / Network Timeout)');
    }
    ordenLlamadasUpsert.add(tabla);
    final lista = tablas[tabla] ??= [];

    for (final reg in registros) {
      final uuid = reg['uuid']?.toString();
      final idx = lista.indexWhere((r) => r['uuid'] == uuid);
      if (idx != -1) {
        lista[idx] = Map<String, dynamic>.from(reg); // Actualización idempotente
      } else {
        lista.add(Map<String, dynamic>.from(reg)); // Inserción nueva
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> consultarModificados({
    required String tabla,
    required String campoCursor,
    required String ultimoCursor,
    int limite = 100,
  }) async {
    final lista = tablas[tabla] ?? [];
    final filtrados = lista.where((r) {
      final cursorVal = r[campoCursor]?.toString() ?? '';
      return cursorVal.compareTo(ultimoCursor) > 0;
    }).toList();

    filtrados.sort((a, b) =>
        (a[campoCursor]?.toString() ?? '').compareTo(b[campoCursor]?.toString() ?? ''));

    if (filtrados.length > limite) {
      return filtrados.sublist(0, limite);
    }
    return filtrados;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Fase 3: Capa de Sincronización en Flutter (Supabase Offline-First)', () {
    late Database db;
    late SimuladorRemotoMemoria simuladorRemoto;

    setUp(() async {
      simuladorRemoto = SimuladorRemotoMemoria();

      // Abrir base de datos de prueba v15 limpia
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
      ServicioConectividad.instancia.setMockConexion(null);
    });

    test('1. Modo Local Puro: Opera sin errores cuando no hay credenciales configuradas', () async {
      expect(SupabaseConfig.estaConfigurado, isFalse);

      final servicio = ServicioSupabase.instancia;
      await servicio.inicializar(); // Sin llaves
      expect(servicio.modoLocalPuro, isTrue);
      expect(servicio.client, isNull);

      final res = await ServicioSincronizacion.instancia.sincronizar(dbOverride: db);
      expect(res.exitoso, isTrue);
      expect(res.error, contains('Modo local puro activo'));
    });

    test('2. PUSH Outbox: Sube registros a Supabase respetando el orden relacional', () async {
      final prodUuid = const Uuid().v4();
      final ventaUuid = const Uuid().v4();
      final artUuid = const Uuid().v4();

      // Sembrar datos locales pendientes
      await db.insert('productos', {
        'id': 'BOT-099',
        'uuid': prodUuid,
        'nombre': 'Ficus Lyrata',
        'notas': 'Riego moderado',
        'precioVenta': 350.0,
        'costo': 150.0,
        'cantidadEnInventario': 10,
        'sync_estado': 'pendiente',
        'updated_at': '2026-11-16T12:00:00Z',
      });

      await db.insert('ventas', {
        'id': 'VEN-9001',
        'uuid': ventaUuid,
        'fecha': '2026-11-16T12:05:00Z',
        'estado': 'completada',
        'porcentajeIva': 0.16,
        'aplicarIva': 1,
        'cliente': 'Ana Botánica',
        'montoPagado': 350.0,
        'sync_estado': 'pendiente',
        'updated_at': '2026-11-16T12:05:00Z',
      });

      await db.insert('articulos_venta', {
        'uuid': artUuid,
        'venta_id': 'VEN-9001',
        'venta_uuid': ventaUuid,
        'producto_id': 'BOT-099',
        'producto_uuid': prodUuid,
        'cantidad': 1,
        'precioUnitario': 350.0,
        'sync_estado': 'pendiente',
        'updated_at': '2026-11-16T12:05:00Z',
      });

      // Ejecutar sincronización con remoto simulado
      final res = await ServicioSincronizacion.instancia.sincronizar(
        fuenteRemotaOverride: simuladorRemoto,
        dbOverride: db,
      );

      expect(res.exitoso, isTrue);
      expect(res.registrosSubidos, greaterThanOrEqualTo(3));

      // Verificar que el remoto recibió los registros
      expect(simuladorRemoto.tablas['productos']!.any((p) => p['uuid'] == prodUuid), isTrue);
      expect(simuladorRemoto.tablas['ventas']!.any((v) => v['uuid'] == ventaUuid), isTrue);
      expect(simuladorRemoto.tablas['articulos_venta']!.any((a) => a['uuid'] == artUuid), isTrue);

      // Verificar orden relacional estricto: productos antes que ventas y articulos
      final idxProd = simuladorRemoto.ordenLlamadasUpsert.indexOf('productos');
      final idxVentas = simuladorRemoto.ordenLlamadasUpsert.indexOf('ventas');
      final idxArts = simuladorRemoto.ordenLlamadasUpsert.indexOf('articulos_venta');
      expect(idxProd, lessThan(idxVentas));
      expect(idxVentas, lessThan(idxArts));

      // Verificar que en SQLite local las filas se marcaron como 'sincronizado'
      final prodLocal = await db.query('productos', where: 'uuid = ?', whereArgs: [prodUuid]);
      expect(prodLocal.first['sync_estado'], equals('sincronizado'));

      final colaPendiente = await db.query('cola_sincronizacion');
      expect(colaPendiente.isEmpty, isTrue);
    });

    test('3. Idempotencia: Múltiples ejecuciones de PUSH no duplican registros en Supabase', () async {
      final prodUuid = const Uuid().v4();

      await db.insert('productos', {
        'id': 'BOT-100',
        'uuid': prodUuid,
        'nombre': 'Cactus San Pedro',
        'precioVenta': 120.0,
        'costo': 50.0,
        'cantidadEnInventario': 5,
        'sync_estado': 'pendiente',
        'updated_at': '2026-11-16T12:00:00Z',
      });

      // Primer PUSH
      await ServicioSincronizacion.instancia.sincronizar(
        fuenteRemotaOverride: simuladorRemoto,
        dbOverride: db,
      );

      // Forzar segundo intento marcando de nuevo pendiente
      await db.update('productos', {'sync_estado': 'pendiente'}, where: 'uuid = ?', whereArgs: [prodUuid]);
      await ServicioSincronizacion.instancia.sincronizar(
        fuenteRemotaOverride: simuladorRemoto,
        dbOverride: db,
      );

      // El remoto debe tener exactamente 1 registro para ese UUID (sin duplicados)
      final remotos = simuladorRemoto.tablas['productos']!.where((p) => p['uuid'] == prodUuid).toList();
      expect(remotos.length, equals(1));
    });

    test('4. PULL Incremental y Convergencia de Stock entre dispositivos (Append-Only)', () async {
      final prodUuid = const Uuid().v4();

      // Dispositivo 2 tiene el producto con stock inicial 20 y un movimiento de ajuste de 20
      await db.insert('productos', {
        'id': 'BOT-500',
        'uuid': prodUuid,
        'nombre': 'Pothos Dorado',
        'precioVenta': 80.0,
        'costo': 30.0,
        'cantidadEnInventario': 20,
        'sync_estado': 'sincronizado',
        'updated_at': '2026-11-16T10:00:00Z',
      });
      await db.insert('movimientos_inventario', {
        'uuid': const Uuid().v4(),
        'producto_uuid': prodUuid,
        'tipo': 'ajuste',
        'cantidad': 20,
        'motivo': 'saldo_inicial_migracion',
        'sync_estado': 'sincronizado',
        'created_at': '2026-11-16T10:00:00Z',
      });

      // El Dispositivo 1 registró en Supabase dos ventas de 3 y 4 unidades respectivamente (-7)
      simuladorRemoto.tablas['movimientos_inventario']!.add({
        'uuid': const Uuid().v4(),
        'producto_uuid': prodUuid,
        'tipo': 'venta',
        'cantidad': -3,
        'motivo': 'Venta Folio #VEN-D1-1',
        'created_at': '2026-11-16T11:00:00Z',
      });
      simuladorRemoto.tablas['movimientos_inventario']!.add({
        'uuid': const Uuid().v4(),
        'producto_uuid': prodUuid,
        'tipo': 'venta',
        'cantidad': -4,
        'motivo': 'Venta Folio #VEN-D1-2',
        'created_at': '2026-11-16T11:30:00Z',
      });

      // Dispositivo 2 ejecuta PULL
      final res = await ServicioSincronizacion.instancia.sincronizar(
        fuenteRemotaOverride: simuladorRemoto,
        dbOverride: db,
      );

      expect(res.exitoso, isTrue);
      expect(res.registrosDescargados, equals(2));

      // Verificamos que Dispositivo 2 recalculó el stock sumando todos los movimientos: 20 - 3 - 4 = 13
      final stockDerivado = await BaseDeDatos.instancia.calcularStockDesdeMovimientos(prodUuid, executor: db);
      expect(stockDerivado, equals(13));

      final prodActualizado = await db.query('productos', where: 'uuid = ?', whereArgs: [prodUuid]);
      expect(prodActualizado.first['cantidadEnInventario'], equals(13));
    });

    test('5. Resolución de Conflictos Last-Write-Wins (LWW) y Soft Delete en Productos', () async {
      final prodUuid = const Uuid().v4();

      await db.insert('productos', {
        'id': 'BOT-300',
        'uuid': prodUuid,
        'nombre': 'Suculenta Echeveria',
        'precioVenta': 50.0,
        'costo': 20.0,
        'cantidadEnInventario': 10,
        'activo': 1,
        'sync_estado': 'sincronizado',
        'updated_at': '2026-11-16T10:00:00Z',
      });

      // Simular cambio remoto más reciente (Dueño editó nombre y precio)
      simuladorRemoto.tablas['productos']!.add({
        'uuid': prodUuid,
        'codigo_local': 'BOT-300',
        'nombre': 'Echeveria Elegans Premium',
        'precio_venta': 65.0,
        'costo': 20.0,
        'stock': 10,
        'activo': true,
        'updated_at': '2026-11-16T11:00:00Z',
      });

      await ServicioSincronizacion.instancia.sincronizar(
        fuenteRemotaOverride: simuladorRemoto,
        dbOverride: db,
      );

      var prod = (await db.query('productos', where: 'uuid = ?', whereArgs: [prodUuid])).first;
      expect(prod['nombre'], equals('Echeveria Elegans Premium'));
      expect(prod['precioVenta'], equals(65.0));

      // Simular que el Dueño deshabilitó (Soft Delete) el producto en la nube
      simuladorRemoto.tablas['productos']!.clear();
      simuladorRemoto.tablas['productos']!.add({
        'uuid': prodUuid,
        'codigo_local': 'BOT-300',
        'nombre': 'Echeveria Elegans Premium',
        'precio_venta': 65.0,
        'costo': 20.0,
        'stock': 10,
        'activo': false,
        'deleted_at': '2026-11-16T11:30:00Z',
        'updated_at': '2026-11-16T11:30:00Z',
      });

      await ServicioSincronizacion.instancia.sincronizar(
        fuenteRemotaOverride: simuladorRemoto,
        dbOverride: db,
      );

      prod = (await db.query('productos', where: 'uuid = ?', whereArgs: [prodUuid])).first;
      expect(prod['activo'], equals(0)); // Soft deleted localmente sin DELETE físico
    });

    test('6. Manejo de Fallos: Incrementa intentos y guarda error en cola_sincronizacion', () async {
      final elem = ElementoColaSync(
        tabla: 'productos',
        registroUuid: const Uuid().v4(),
        operacion: 'upsert',
        payloadJson: '{"nombre": "Cactus Err"}',
      );
      await BaseDeDatos.instancia.encolarCambio(elem, executor: db);

      // Configurar fallo simulado
      simuladorRemoto.lanzarErrorIntencional = true;

      final res = await ServicioSincronizacion.instancia.sincronizar(
        fuenteRemotaOverride: simuladorRemoto,
        dbOverride: db,
      );

      expect(res.exitoso, isFalse);

      final cola = await db.query('cola_sincronizacion');
      expect(cola.first['intentos'], greaterThanOrEqualTo(1));
      expect(cola.first['ultimo_error'], contains('503'));
    });

    test('7. ControladorSincronizacion: Estados reactivos e integración de red', () async {
      // 1. Simular conectividad offline
      ServicioConectividad.instancia.setMockConexion(false);

      final controlador = ControladorSincronizacion();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // En modo local puro sin Supabase configurado
      expect(controlador.estadoUI, equals(EstadoSincronizacionUI.modoLocalPuro));
      expect(controlador.enLinea, isFalse);

      // 2. Simular retorno de conectividad a internet
      ServicioConectividad.instancia.setMockConexion(true);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controlador.enLinea, isTrue);

      controlador.dispose();
    });
  });
}
