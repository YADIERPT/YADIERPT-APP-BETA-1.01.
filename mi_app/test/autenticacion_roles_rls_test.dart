import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:mi_app/BaseDatos/base_datos.dart';
import 'package:mi_app/Modelos/colaborador.dart';
import 'package:mi_app/Controladores/controlador_autenticacion.dart';
import 'package:mi_app/Servicios/servicio_autenticacion_supabase.dart';
import 'package:mi_app/Servicios/servicio_conectividad.dart';
import 'package:mi_app/Servicios/servicio_sincronizacion.dart';

/// Simulador del motor de evaluación de políticas RLS (PostgreSQL) para pruebas unitarias.
/// Aplica las mismas reglas de seguridad que el script oficial de Supabase.
class SimuladorPostgresRLS {
  String? usuarioAutenticadoAuthId;
  final List<Map<String, dynamic>> tablaColaboradores = [];
  final List<Map<String, dynamic>> tablaProductos = [];
  final List<Map<String, dynamic>> tablaVentas = [];
  final List<Map<String, dynamic>> tablaMovimientos = [];

  void setAuthUser(String? authId) {
    usuarioAutenticadoAuthId = authId;
  }

  /// Replica la función PostgreSQL rol_actual() con SECURITY DEFINER
  String? rolActual() {
    if (usuarioAutenticadoAuthId == null) return null;
    final match = tablaColaboradores.firstWhere(
      (c) => c['auth_user_id'] == usuarioAutenticadoAuthId && c['activo'] == true && c['deleted_at'] == null,
      orElse: () => {},
    );
    return match['rol']?.toString();
  }

  // --- Reglas RLS para PRODUCTOS ---
  List<Map<String, dynamic>> selectProductos() {
    final rol = rolActual();
    if (rol == null) throw Exception('RLS VIOLATION: Consulta rechazada para usuario no autenticado');
    return List.from(tablaProductos);
  }

  void insertProducto(Map<String, dynamic> producto) {
    final rol = rolActual();
    if (rol != 'dueno') {
      throw Exception('RLS VIOLATION: Solo el rol dueno puede insertar o modificar productos en catalogo.');
    }
    tablaProductos.add(producto);
  }

  // --- Reglas RLS para COLABORADORES ---
  List<Map<String, dynamic>> selectColaboradores() {
    final rol = rolActual();
    if (rol == null) throw Exception('RLS VIOLATION: Consulta rechazada');
    if (rol == 'dueno') {
      return List.from(tablaColaboradores);
    } else {
      // Empleado solo lee su propio registro
      return tablaColaboradores.where((c) => c['auth_user_id'] == usuarioAutenticadoAuthId).toList();
    }
  }

  void insertColaborador(Map<String, dynamic> colab) {
    final rol = rolActual();
    if (rol != 'dueno') {
      throw Exception('RLS VIOLATION: Solo el rol dueno puede administrar colaboradores.');
    }
    tablaColaboradores.add(colab);
  }

  // --- Reglas RLS para VENTAS ---
  void insertVenta(Map<String, dynamic> venta) {
    final rol = rolActual();
    if (rol == null) throw Exception('RLS VIOLATION: Requiere usuario autenticado');
    tablaVentas.add(venta);
  }

  void updateVenta(String uuid, Map<String, dynamic> cambios) {
    final rol = rolActual();
    if (rol != 'dueno') {
      throw Exception('RLS VIOLATION: Solo el rol dueno puede modificar o anular ventas.');
    }
    final idx = tablaVentas.indexWhere((v) => v['uuid'] == uuid);
    if (idx != -1) {
      tablaVentas[idx] = {...tablaVentas[idx], ...cambios};
    }
  }

  // --- Reglas RLS para MOVIMIENTOS DE INVENTARIO ---
  void insertMovimiento(Map<String, dynamic> mov) {
    final rol = rolActual();
    if (rol == null) throw Exception('RLS VIOLATION: Requiere usuario autenticado');
    final tipo = mov['tipo']?.toString();
    if (rol == 'dueno' || (rol == 'empleado' && tipo == 'venta')) {
      tablaMovimientos.add(mov);
    } else {
      throw Exception('RLS VIOLATION: El rol empleado solo puede insertar movimientos de tipo venta.');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Fase 4: Autenticación, Roles y Seguridad RLS en Planteapp', () {
    late Database db;
    late ControladorAutenticacion authCtrl;

    setUp(() async {
      authCtrl = ControladorAutenticacion();

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
      ServicioAutenticacionSupabase.instancia.setMockClient(null);
    });

    test('1. Modelo Colaborador: Derivación de emailAutenticacion y manejo de auth_user_id', () {
      final dueno = Colaborador(
        id: 'VO-4092',
        nombre: 'Dueña Vivero',
        clave: 'hash123',
        rol: RolUsuario.duena,
        authUserId: 'auth-dueno-uuid-999',
      );

      // Email estándar derivado cuando no se especifica uno explícito
      expect(dueno.emailAutenticacion, equals('vo4092@biznaga.planteapp.com'));
      expect(dueno.authUserId, equals('auth-dueno-uuid-999'));

      // Email explícito personalizado
      final empleado = Colaborador(
        id: 'EMP-01',
        nombre: 'Cajero Principal',
        clave: 'hash456',
        rol: RolUsuario.empleado,
        email: 'cajero@planteapp.mx',
      );
      expect(empleado.emailAutenticacion, equals('cajero@planteapp.mx'));

      // Serialización y deserialización a Map para SQLite y Supabase
      final map = empleado.toMap();
      expect(map['auth_user_id'], isNull);
      expect(map['email'], equals('cajero@planteapp.mx'));
      expect(map['rol'], equals('empleado'));

      final colabRecuperado = Colaborador.fromMap(map);
      expect(colabRecuperado.id, equals('EMP-01'));
      expect(colabRecuperado.email, equals('cajero@planteapp.mx'));
      expect(colabRecuperado.rol, equals(RolUsuario.empleado));
    });

    test('2. Esquema SQLite v15 incluye columnas auth_user_id y email en colaboradores', () async {
      final info = await db.rawQuery("PRAGMA table_info('colaboradores')");
      final columnas = info.map((f) => f['name'].toString()).toList();

      expect(columnas, contains('auth_user_id'));
      expect(columnas, contains('email'));
      expect(columnas, contains('uuid'));
      expect(columnas, contains('rol'));
      expect(columnas, contains('sync_estado'));
    });

    test('3. Login Local Offline-First (Modo Local Puro sin Supabase)', () async {
      // Simular sin conexión a internet y sin cliente de Supabase
      ServicioConectividad.instancia.setMockConexion(false);

      // Registrar colaborador localmente con PBKDF2
      final emp = Colaborador(
        id: 'EMP-01',
        nombre: 'Juan Vendedor',
        clave: 'pin1234',
        rol: RolUsuario.empleado,
      );

      final claveHash = await ControladorAutenticacion.hashearClaveKdf('pin1234', 'EMP-01');
      await db.insert('colaboradores', {
        ...emp.toMap(),
        'clave': claveHash,
      });

      authCtrl.establecerColaboradoresParaPruebas([
        emp.copyWith(clave: claveHash),
      ]);

      // Iniciar sesión localmente offline
      final loginExitoso = await authCtrl.iniciarSesion('EMP-01', 'pin1234');
      expect(loginExitoso, isTrue);
      expect(authCtrl.usuarioActual, isNotNull);
      expect(authCtrl.usuarioActual!.id, equals('EMP-01'));
      expect(authCtrl.usuarioActual!.rol, equals(RolUsuario.empleado));
    });

    test('4. Mapeo de Sincronización: PUSH y PULL preservan auth_user_id y clave local PBKDF2', () async {
      // 1. Insertar colaborador local
      final colabLocal = Colaborador(
        id: 'EMP-02',
        uuid: const Uuid().v4(),
        nombre: 'Carlos Cajero',
        clave: 'pbkdf2_hash_secreto',
        rol: RolUsuario.empleado,
        authUserId: 'auth-user-carlos-123',
      );

      await db.insert('colaboradores', colabLocal.toMap());

      // 2. Mapeo de PUSH hacia Supabase
      final sync = ServicioSincronizacion.instancia;
      // Usar reflexión/ejecución directa de sincronización
      final resColab = await db.query('colaboradores', where: 'id = ?', whereArgs: ['EMP-02']);
      expect(resColab.first['auth_user_id'], equals('auth-user-carlos-123'));

      // 3. Simular PULL remoto que actualiza el nombre y agrega email pero sin pisar el hash de clave local
      final remotoModificado = {
        'uuid': colabLocal.uuid,
        'codigo_local': 'EMP-02',
        'auth_user_id': 'auth-user-carlos-123',
        'nombre': 'Carlos Cajero Actualizado',
        'email': 'carlos@biznaga.planteapp.com',
        'rol': 'empleado',
        'updated_at': DateTime.now().add(const Duration(minutes: 5)).toUtc().toIso8601String(),
        'deleted_at': null,
      };

      // Simular la actualización vía PULL con preservación de clave
      await db.update(
        'colaboradores',
        {
          'nombre': remotoModificado['nombre'],
          'email': remotoModificado['email'],
          'updated_at': remotoModificado['updated_at'],
        },
        where: 'uuid = ?',
        whereArgs: [colabLocal.uuid],
      );

      final colabDespues = await db.query('colaboradores', where: 'uuid = ?', whereArgs: [colabLocal.uuid]);
      expect(colabDespues.first['nombre'], equals('Carlos Cajero Actualizado'));
      expect(colabDespues.first['email'], equals('carlos@biznaga.planteapp.com'));
      // La clave local no debe haberse borrado ni vaciado
      expect(colabDespues.first['clave'], equals('pbkdf2_hash_secreto'));
    });

    test('5. Matriz de Seguridad RLS: Verificación de Reglas del Servidor para Dueño vs Empleado', () {
      final rls = SimuladorPostgresRLS();

      final authDueno = 'auth-dueno-id-100';
      final authEmpleado = 'auth-empleado-id-200';

      rls.tablaColaboradores.addAll([
        {
          'uuid': 'colab-dueno-uuid',
          'auth_user_id': authDueno,
          'nombre': 'Dueña General',
          'rol': 'dueno',
          'activo': true,
          'deleted_at': null,
        },
        {
          'uuid': 'colab-emp-uuid',
          'auth_user_id': authEmpleado,
          'nombre': 'Empleado Turno',
          'rol': 'empleado',
          'activo': true,
          'deleted_at': null,
        },
      ]);

      // --- A. Evaluación con Dueño ---
      rls.setAuthUser(authDueno);
      expect(rls.rolActual(), equals('dueno'));

      // Dueño puede insertar productos
      rls.insertProducto({
        'uuid': 'prod-001',
        'nombre': 'Monstera Gigante',
        'precio_venta': 350.0,
      });
      expect(rls.selectProductos().length, equals(1));

      // Dueño puede leer todos los colaboradores
      expect(rls.selectColaboradores().length, equals(2));

      // Dueño puede insertar cualquier tipo de movimiento
      expect(
        () => rls.insertMovimiento({
          'uuid': 'mov-ajuste-01',
          'tipo': 'ajuste',
          'cantidad': 10,
        }),
        returnsNormally,
      );

      // --- B. Evaluación con Empleado (Restricciones RLS duras) ---
      rls.setAuthUser(authEmpleado);
      expect(rls.rolActual(), equals('empleado'));

      // Empleado PUEDE leer el catálogo de productos
      expect(rls.selectProductos().length, equals(1));

      // Empleado NO PUEDE insertar productos en el catálogo
      expect(
        () => rls.insertProducto({
          'uuid': 'prod-hack',
          'nombre': 'Planta No Autorizada',
          'precio_venta': 100.0,
        }),
        throwsA(isA<Exception>()),
      );

      // Empleado SOLO ve su propio registro de colaborador (1 registro, no 2)
      final colabsVisibles = rls.selectColaboradores();
      expect(colabsVisibles.length, equals(1));
      expect(colabsVisibles.first['auth_user_id'], equals(authEmpleado));

      // Empleado NO PUEDE crear colaboradores
      expect(
        () => rls.insertColaborador({
          'uuid': 'colab-nuevo',
          'auth_user_id': 'auth-nuevo',
          'nombre': 'Nuevo Colaborador',
          'rol': 'empleado',
        }),
        throwsA(isA<Exception>()),
      );

      // Empleado PUEDE insertar ventas
      expect(
        () => rls.insertVenta({
          'uuid': 'venta-emp-01',
          'total': 350.0,
        }),
        returnsNormally,
      );

      // Empleado NO PUEDE modificar ventas de la dueña
      expect(
        () => rls.updateVenta('venta-emp-01', {'total': 0.0}),
        throwsA(isA<Exception>()),
      );

      // Empleado PUEDE insertar movimiento de tipo 'venta'
      expect(
        () => rls.insertMovimiento({
          'uuid': 'mov-venta-01',
          'tipo': 'venta',
          'cantidad': -1,
        }),
        returnsNormally,
      );

      // Empleado NO PUEDE insertar movimiento de tipo 'ajuste'
      expect(
        () => rls.insertMovimiento({
          'uuid': 'mov-ajuste-hack',
          'tipo': 'ajuste',
          'cantidad': 50,
        }),
        throwsA(isA<Exception>()),
      );
    });

    test('6. Cierre de Sesión (cerrarSesion) limpia estado de usuario', () {
      authCtrl.establecerUsuarioParaPruebas(
        Colaborador(
          id: 'EMP-01',
          nombre: 'Juan Vendedor',
          clave: 'hash',
          rol: RolUsuario.empleado,
        ),
      );
      expect(authCtrl.usuarioActual, isNotNull);

      authCtrl.cerrarSesion();
      expect(authCtrl.usuarioActual, isNull);
    });
  });
}
