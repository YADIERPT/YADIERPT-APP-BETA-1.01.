import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mi_app/Controladores/controlador_sincronizacion.dart';
import 'package:mi_app/Controladores/controlador_autenticacion.dart';
import 'package:mi_app/Controladores/controlador_perfil.dart';
import 'package:mi_app/Controladores/controlador_inventario.dart';
import 'package:mi_app/Controladores/controlador_ventas.dart';
import 'package:mi_app/Controladores/controlador_finanzas.dart';
import 'package:mi_app/Controladores/controlador_biometrico.dart';
import 'package:mi_app/Modelos/colaborador.dart';
import 'package:mi_app/Vista/Widgets/indicador_sincronizacion.dart';
import 'package:mi_app/Vista/sincronizacion_vista.dart';
import 'package:mi_app/Vista/perfil.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 5: UI Mínima de Sincronización y Respaldo en la Nube', () {
    late ControladorSincronizacion ctrlSync;

    setUp(() {
      ctrlSync = ControladorSincronizacion();
      // Inyectar valores limpios sin requerir llamadas SQLite
      ctrlSync.setMockValores(
        enLinea: true,
        sincronizando: false,
        cambiosPendientes: 0,
        syncHabilitada: true,
        dispositivoId: 'test-device-uuid-12345',
        registroErrores: [],
        modoLocalPuro: false,
      );
    });

    tearDown(() {
      ctrlSync.dispose();
    });

    testWidgets('1. IndicadorSincronizacion: Renderiza correctamente según cada estado', (tester) async {
      // 1.1 Estado Sincronizado
      ctrlSync.setMockValores(
        enLinea: true,
        cambiosPendientes: 0,
        syncHabilitada: true,
        modoLocalPuro: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                ChangeNotifierProvider<ControladorSincronizacion>.value(
                  value: ctrlSync,
                  child: const IndicadorSincronizacion(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);

      // 1.2 Estado Pendiente con contador de cambios
      ctrlSync.setMockValores(cambiosPendientes: 7);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
      expect(find.text('7'), findsOneWidget);

      // 1.3 Estado Sin Conexión
      ctrlSync.setMockValores(enLinea: false, cambiosPendientes: 0);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

      // 1.4 Estado Error / Aviso
      ctrlSync.setMockValores(enLinea: true, ultimoError: 'Fallo de timeout');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_sync_rounded), findsOneWidget);

      // 1.5 Estado Pausado (Sync deshabilitada)
      ctrlSync.setMockValores(syncHabilitada: false, ultimoError: null);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });

    testWidgets('2. IndicadorSincronizacion: Tocar el botón dispara feedback con SnackBar', (tester) async {
      ctrlSync.setMockValores(
        enLinea: true,
        cambiosPendientes: 2,
        modoLocalPuro: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ControladorSincronizacion>.value(
              value: ctrlSync,
              child: const Center(child: IndicadorSincronizacion()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boton = find.byKey(const ValueKey('boton_indicador_sincronizacion'));
      expect(boton, findsOneWidget);

      await tester.tap(boton);
      await tester.pump(); // Inicia animación de SnackBar

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('2 cambios locales pendientes de subir'), findsOneWidget);
    });

    testWidgets('3. IndicadorSincronizacion: Tolera ausencia de provider sin arrojar excepciones', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: IndicadorSincronizacion()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IndicadorSincronizacion), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('4. SincronizacionVista: Restringe acceso a empleados y permite acceso a dueños', (tester) async {
      final ctrlAuth = ControladorAutenticacion();
      final empleado = Colaborador(
        id: 'EMP-01',
        nombre: 'Carlos Empleado',
        clave: 'pbkdf2_hash_clave',
        rol: RolUsuario.empleado,
      );
      ctrlAuth.establecerUsuarioParaPruebas(empleado);

      // 4.1 Intento de acceso como Empleado
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: ctrlAuth),
            ChangeNotifierProvider<ControladorSincronizacion>.value(value: ctrlSync),
          ],
          child: MaterialApp(
            home: SincronizacionVista(controladorSincronizacion: ctrlSync),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar pantalla de acceso restringido por RoleGuard
      expect(find.text('Acceso Restringido'), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_sincronizar_ahora')), findsNothing);

      // 4.2 Acceso permitido como Dueña
      final duena = Colaborador(
        id: 'VO-4092',
        nombre: 'Dueña Admin',
        clave: 'pbkdf2_hash_clave',
        rol: RolUsuario.duena,
      );
      ctrlAuth.establecerUsuarioParaPruebas(duena);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: ctrlAuth),
            ChangeNotifierProvider<ControladorSincronizacion>.value(value: ctrlSync),
          ],
          child: MaterialApp(
            home: SincronizacionVista(controladorSincronizacion: ctrlSync),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sincronización y Respaldo'), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_sincronizar_ahora')), findsOneWidget);
      expect(find.byKey(const ValueKey('switch_sincronizacion_activa')), findsOneWidget);
      expect(find.text('ID del Dispositivo'), findsOneWidget);
      expect(find.text('test-device-uuid-12345'), findsOneWidget);

      ctrlAuth.dispose();
    });

    testWidgets('5. SincronizacionVista: Switch y botón de Sincronizar Ahora interactúan reactivamente', (tester) async {
      final ctrlAuth = ControladorAutenticacion();
      final duena = Colaborador(
        id: 'VO-4092',
        nombre: 'Dueña Admin',
        clave: 'pbkdf2_hash_clave',
        rol: RolUsuario.duena,
      );
      ctrlAuth.establecerUsuarioParaPruebas(duena);

      ctrlSync.setMockValores(
        enLinea: true,
        syncHabilitada: true,
        cambiosPendientes: 3,
        dispositivoId: 'disp-uuid-abc',
        modoLocalPuro: false,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: ctrlAuth),
            ChangeNotifierProvider<ControladorSincronizacion>.value(value: ctrlSync),
          ],
          child: MaterialApp(
            home: SincronizacionVista(controladorSincronizacion: ctrlSync),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar estado inicial
      expect(find.text('Cambios Locales Pendientes'), findsOneWidget);
      expect(find.text('En línea'), findsOneWidget);

      // Alternar switch
      final switchWidget = find.byKey(const ValueKey('switch_sincronizacion_activa'));
      await tester.tap(switchWidget);
      await tester.pumpAndSettle();

      // Pulsar botón Sincronizar Ahora
      final botonSync = find.byKey(const ValueKey('boton_sincronizar_ahora'));
      expect(botonSync, findsOneWidget);

      await tester.tap(botonSync);
      await tester.pump(); // Refrescar para ver feedback

      expect(find.byType(SnackBar), findsOneWidget);

      ctrlAuth.dispose();
    });

    testWidgets('6. SincronizacionVista: Muestra registro de errores cuando existen mutaciones fallidas', (tester) async {
      final ctrlAuth = ControladorAutenticacion();
      final duena = Colaborador(
        id: 'VO-4092',
        nombre: 'Dueña Admin',
        clave: 'pbkdf2_hash_clave',
        rol: RolUsuario.duena,
      );
      ctrlAuth.establecerUsuarioParaPruebas(duena);

      // 6.1 Sin errores
      ctrlSync.setMockValores(registroErrores: [], modoLocalPuro: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: ctrlAuth),
            ChangeNotifierProvider<ControladorSincronizacion>.value(value: ctrlSync),
          ],
          child: MaterialApp(
            home: SincronizacionVista(controladorSincronizacion: ctrlSync),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Desplazar para asegurar visibilidad en pantallas con viewport de prueba estándar
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();

      expect(find.text('Sin errores en cola'), findsOneWidget);

      // 6.2 Con errores simulados en la cola
      ctrlSync.setMockValores(
        registroErrores: [
          {
            'tabla': 'productos',
            'operacion': 'upsert',
            'registro_uuid': 'prod-uuid-999',
            'intentos': 3,
            'ultimo_error': 'Error 500: Database lock timeout',
            'created_at': '2026-11-16T18:00:00Z',
          },
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('productos (upsert)'), findsOneWidget);
      expect(find.text('Error 500: Database lock timeout'), findsOneWidget);
      expect(find.text('Intentos: 3'), findsOneWidget);
      expect(find.byKey(const ValueKey('boton_reintentar_errores')), findsOneWidget);

      ctrlAuth.dispose();
    });

    testWidgets('7. PerfilVista: Muestra Sincronización y Respaldo para Dueña y lo oculta para Empleado', (tester) async {
      final ctrlAuth = ControladorAutenticacion();
      final ctrlPerf = ControladorPerfil();
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlBio = ControladorBiometrico();

      // 7.1 Empleado: El tile NO debe aparecer
      final empleado = Colaborador(
        id: 'EMP-02',
        nombre: 'Empleado Test',
        clave: 'pbkdf2_hash_clave',
        rol: RolUsuario.empleado,
      );
      ctrlAuth.establecerUsuarioParaPruebas(empleado);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: ctrlAuth),
            Provider<ControladorPerfil>.value(value: ctrlPerf),
            ChangeNotifierProvider<ControladorInventario>.value(value: ctrlInv),
            ChangeNotifierProvider<ControladorFinanzas>.value(value: ctrlFin),
            ChangeNotifierProvider<ControladorVentas>.value(value: ctrlVentas),
            Provider<ControladorBiometrico>.value(value: ctrlBio),
            ChangeNotifierProvider<ControladorSincronizacion>.value(value: ctrlSync),
          ],
          child: MaterialApp(
            home: PerfilVista(onLogout: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sincronización y Respaldo'), findsNothing);

      // 7.2 Dueña: El tile DEBE aparecer y permitir navegación
      final duena = Colaborador(
        id: 'VO-4092',
        nombre: 'Dueña Test',
        clave: 'pbkdf2_hash_clave',
        rol: RolUsuario.duena,
      );
      ctrlAuth.establecerUsuarioParaPruebas(duena);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: ctrlAuth),
            Provider<ControladorPerfil>.value(value: ctrlPerf),
            ChangeNotifierProvider<ControladorInventario>.value(value: ctrlInv),
            ChangeNotifierProvider<ControladorFinanzas>.value(value: ctrlFin),
            ChangeNotifierProvider<ControladorVentas>.value(value: ctrlVentas),
            Provider<ControladorBiometrico>.value(value: ctrlBio),
            ChangeNotifierProvider<ControladorSincronizacion>.value(value: ctrlSync),
          ],
          child: MaterialApp(
            home: PerfilVista(onLogout: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sincronización y Respaldo'), findsOneWidget);

      await tester.tap(find.text('Sincronización y Respaldo'));
      await tester.pumpAndSettle();

      expect(find.byType(SincronizacionVista), findsOneWidget);

      ctrlAuth.dispose();
      ctrlInv.dispose();
      ctrlFin.dispose();
      ctrlVentas.dispose();
    });
  });
}
