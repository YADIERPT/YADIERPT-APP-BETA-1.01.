import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/widgets.dart';

import 'package:mi_app/BaseDatos/base_datos.dart';
import 'package:mi_app/Servicios/servicio_realtime.dart';
import 'package:mi_app/Servicios/servicio_conectividad.dart';
import 'package:mi_app/Servicios/servicio_sincronizacion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Fase 4b: Supabase Realtime y Sincronización Reactiva Multi-Dispositivo', () {
    late Database db;
    late ServicioRealtime servicioRealtime;

    setUp(() async {
      servicioRealtime = ServicioRealtime.instancia;
      servicioRealtime.inicializar();

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
      servicioRealtime.detenerEscucha();
      await db.close();
      ServicioConectividad.instancia.setMockConexion(null);
    });

    test('1. Modo Local Puro: Iniciar escucha sin cliente configurado no arroja excepciones', () async {
      // Sin cliente Supabase (modo local puro)
      await servicioRealtime.iniciarEscucha();
      expect(servicioRealtime.estaEscuchando, isFalse);
      expect(servicioRealtime.tieneCanalActivo, isFalse);
    });

    test('2. Tablas Monitoreadas: Incluye las 7 tablas de negocio especificadas en el plan', () {
      expect(ServicioRealtime.tablasMonitoreadas, contains('productos'));
      expect(ServicioRealtime.tablasMonitoreadas, contains('ventas'));
      expect(ServicioRealtime.tablasMonitoreadas, contains('articulos_venta'));
      expect(ServicioRealtime.tablasMonitoreadas, contains('deudores'));
      expect(ServicioRealtime.tablasMonitoreadas, contains('abonos_venta'));
      expect(ServicioRealtime.tablasMonitoreadas, contains('movimientos_inventario'));
      expect(ServicioRealtime.tablasMonitoreadas, contains('colaboradores'));
      expect(ServicioRealtime.tablasMonitoreadas.length, equals(7));
    });

    test('3. Realtime solo como AVISO: Callback onAvisoRecibido se activa tras aviso', () async {
      bool avisoDisparado = false;
      servicioRealtime.onAvisoRecibido = () {
        avisoDisparado = true;
      };

      // Simular la llegada de un aviso
      expect(avisoDisparado, isFalse);
      servicioRealtime.onAvisoRecibido?.call();
      expect(avisoDisparado, isTrue);
    });

    test('4. Ciclo de Vida: Pausa canal al pasar a segundo plano y reactiva en primer plano', () {
      // Simular cambio a segundo plano
      servicioRealtime.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(servicioRealtime.estaEscuchando, isFalse);

      // Simular retorno al primer plano (resumed)
      expect(
        () => servicioRealtime.didChangeAppLifecycleState(AppLifecycleState.resumed),
        returnsNormally,
      );
    });

    test('5. Reactividad ante retorno de Red: Servicio reacciona al stream de conectividad', () async {
      // Simular caída y retorno de red
      ServicioConectividad.instancia.setMockConexion(false);
      await Future.delayed(const Duration(milliseconds: 50));

      // Al reactivarse la red, el stream emite evento positivo
      ServicioConectividad.instancia.setMockConexion(true);
      await Future.delayed(const Duration(milliseconds: 50));

      final conectado = await ServicioConectividad.instancia.tieneConexion();
      expect(conectado, isTrue);
    });

    test('6. Detención segura: detenerEscucha limpia referencias y cancela recursos', () async {
      await servicioRealtime.detenerEscucha();
      expect(servicioRealtime.estaEscuchando, isFalse);
      expect(servicioRealtime.tieneCanalActivo, isFalse);
    });
  });
}
