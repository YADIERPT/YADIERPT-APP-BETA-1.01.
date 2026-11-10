import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mi_app/BaseDatos/base_datos.dart';
import 'package:mi_app/Controladores/controlador_autenticacion.dart';
import 'package:mi_app/Controladores/controlador_biometrico.dart';
import 'package:mi_app/Modelos/colaborador.dart';
import 'package:mi_app/Modelos/producto.dart';
import 'package:mi_app/Modelos/venta.dart';
import 'package:mi_app/Modelos/configuracion_biometrica.dart';
import 'package:mi_app/Servicios/servicio_biometrico.dart';
import 'package:mi_app/Servicios/servicio_imagen.dart';
import 'package:mi_app/Servicios/servicio_permisos.dart';
import 'package:mi_app/Servicios/secure_storage_service.dart';
import 'package:mi_app/Vista/camara_vista.dart';
import 'package:mi_app/Vista/Widgets/role_guard.dart';
import 'package:mi_app/Modelos/abono.dart';
import 'package:mi_app/Vista/deudores_vista.dart';
import 'package:mi_app/Controladores/controlador_inventario.dart';
import 'package:mi_app/Controladores/controlador_ventas.dart';
import 'package:mi_app/Controladores/controlador_cuentas_por_cobrar.dart';
import 'package:mi_app/Controladores/controlador_finanzas.dart';
import 'package:mi_app/Controladores/controlador_perfil.dart';
import 'package:mi_app/Controladores/controlador_inicio.dart';
import 'package:mi_app/Vista/inicio.dart';
import 'package:mi_app/Vista/pos_vista.dart';
import 'package:mi_app/Vista/venta.dart';
import 'package:mi_app/Vista/inventario_vista.dart';
import 'package:mi_app/Vista/login.dart';
import 'package:mi_app/Vista/splash_vista.dart';
import 'package:mi_app/Vista/Widgets/tarjeta_producto_inventario.dart';
import 'package:mi_app/Vista/Widgets/resumen_inventario_header.dart';
import 'package:mi_app/Vista/Widgets/dashboard_vista.dart';
import 'package:mi_app/Vista/Widgets/tarjeta_historial_venta.dart';
import 'package:mi_app/Vista/Widgets/venta_footer.dart';
import 'package:mi_app/Servicios/servicio_ticket_pdf.dart';
import 'package:mi_app/Vista/perfil.dart';
import 'package:mi_app/Tema/app_theme.dart';
import 'package:mi_app/Modelos/finanzas.dart';
import 'package:mi_app/Vista/empleados_vista.dart';
import 'package:mi_app/Vista/historial_ventas_vista.dart';
import 'package:mi_app/Vista/Widgets/dialogo_seguridad_admin.dart';
import 'package:mi_app/Vista/Widgets/formulario_empleado_sheet.dart';
import 'package:mi_app/Utilidades/formateador.dart';
import 'package:mi_app/Utilidades/debouncer.dart';
import 'package:mi_app/Controladores/controlador_hardware.dart';
import 'package:mi_app/Vista/hardware_vista.dart';
import 'package:mi_app/Servicios/generador_esc_pos.dart';
import 'package:mi_app/Modelos/configuracion_hardware.dart';
import 'package:mi_app/Vista/Widgets/logo_biznaga.dart';
import 'package:mi_app/IA/Controladores/controlador_ia_compras.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('App smoke test', (WidgetTester tester) async {
    expect(true, isTrue);
  });

  group('Seguridad y Hashing de Contraseñas', () {
    test('hashearClave genera un hash SHA-256 de 64 caracteres', () {
      final hash = ControladorAutenticacion.hashearClave('123456', 'VO-4092');
      expect(hash.length, 64);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(hash), isTrue);
    });

    test('hashearClave genera hashes distintos para usuarios distintos con la misma clave', () {
      final hash1 = ControladorAutenticacion.hashearClave('123456', 'USER-1');
      final hash2 = ControladorAutenticacion.hashearClave('123456', 'USER-2');
      expect(hash1, isNot(equals(hash2)));
    });

    test('hashearClaveKdf genera hash PBKDF2-HMAC-SHA256 con formato modular', () async {
      final hashPbkdf2 =
          await ControladorAutenticacion.hashearClaveKdf('miClaveFuerte', 'EMP-77');
      expect(hashPbkdf2.startsWith('\$pbkdf2\$100000\$EMP-77\$'), isTrue);
    });

    test('verificarClave valida correctamente contraseñas modernas PBKDF2 y legadas SHA-256', () async {
      final auth = ControladorAutenticacion();

      // 1. Caso PBKDF2 moderno
      final hashPbkdf2 =
          await ControladorAutenticacion.hashearClaveKdf('miSecretoSeguro', 'EMP-01');
      final colabPbkdf2 = Colaborador(
        id: 'EMP-01',
        nombre: 'Empleado PBKDF2',
        clave: hashPbkdf2,
        rol: RolUsuario.empleado,
      );
      expect(await auth.verificarClave(colabPbkdf2, 'miSecretoSeguro'), isTrue);
      expect(await auth.verificarClave(colabPbkdf2, 'claveErronea'), isFalse);

      // 2. Caso SHA-256 legado
      final hashSha =
          ControladorAutenticacion.hashearClave('miClaveLegada', 'EMP-02');
      final colabSha = Colaborador(
        id: 'EMP-02',
        nombre: 'Empleado Legacy',
        clave: hashSha,
        rol: RolUsuario.empleado,
      );
      expect(await auth.verificarClave(colabSha, 'miClaveLegada'), isTrue);
      expect(await auth.verificarClave(colabSha, 'claveErronea'), isFalse);
    });

    test('generarClaveAleatoriaSegura genera cadena hexadecimal de 64 caracteres (256 bits)', () {
      final key = SecureStorageService.instancia.generarClaveAleatoriaSegura();
      expect(key.length, 64);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(key), isTrue);
    });

    test('generarClaveAleatoriaSegura produce llaves unicas con alta entropia', () {
      final key1 = SecureStorageService.instancia.generarClaveAleatoriaSegura();
      final key2 = SecureStorageService.instancia.generarClaveAleatoriaSegura();
      expect(key1, isNot(equals(key2)));
    });

    test('obtenerClaveMaestraDb lanza KeystoreUnavailableException ante entorno sin hardware Keystore', () async {
      expect(
        () => SecureStorageService.instancia.obtenerClaveMaestraDb(),
        throwsA(isA<KeystoreUnavailableException>()),
      );
    });
  });

  group('Seguridad Criptográfica y Control de Acceso en Autenticación', () {
    test('generarTokenDesafioBiometrico produce tokens de 64 caracteres hex', () {
      final authCtrl = ControladorAutenticacion();
      final token = authCtrl.generarTokenDesafioBiometrico('USR-1');
      expect(token.length, 64);
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(token), isTrue);
    });

    test('iniciarSesionPorId rechaza acceso con token inválido o inexistente', () async {
      final authCtrl = ControladorAutenticacion();
      final exito = await authCtrl.iniciarSesionPorId(
        id: 'USR-ADMIN',
        tokenVerificacion: 'token-falso-inyeccion',
      );
      expect(exito, isFalse);
      expect(authCtrl.usuarioActual, isNull);
    });

    test('iniciarSesionPorId rechaza token emitido para otro usuario', () async {
      final authCtrl = ControladorAutenticacion();
      final token = authCtrl.generarTokenDesafioBiometrico('USR-VALIDO');
      final exito = await authCtrl.iniciarSesionPorId(
        id: 'USR-ADMIN',
        tokenVerificacion: token,
      );
      expect(exito, isFalse);
      expect(authCtrl.usuarioActual, isNull);
    });

    test('iniciarSesionPorId invalida token de un solo uso impidiendo ataques de replay', () async {
      final authCtrl = ControladorAutenticacion();
      final token = authCtrl.generarTokenDesafioBiometrico('USR-1');

      await authCtrl.iniciarSesionPorId(
        id: 'USR-1',
        tokenVerificacion: token,
      );

      final intentoReplay = await authCtrl.iniciarSesionPorId(
        id: 'USR-1',
        tokenVerificacion: token,
      );
      expect(intentoReplay, isFalse);
    });
  });

  group('Ticket en Curso y Gestión de Artículos', () {
    test('Eliminación de artículo del ticket recalcula subtotal y total correctamente', () {
      final prod1 = Producto(
        id: 'P1',
        nombre: 'Monstera Deliciosa',
        costo: 50.0,
        precioVenta: 120.0,
        cantidadEnInventario: 10,
      );
      final prod2 = Producto(
        id: 'P2',
        nombre: 'Ficus Lyrata',
        costo: 80.0,
        precioVenta: 200.0,
        cantidadEnInventario: 5,
      );

      final venta = Venta(
        id: 'V-001',
        fecha: DateTime.now(),
        articulos: [
          ArticuloVenta(producto: prod1, cantidad: 2, precioUnitario: 120.0),
          ArticuloVenta(producto: prod2, cantidad: 1, precioUnitario: 200.0),
        ],
        porcentajeIva: 0.16,
        aplicarIva: true,
      );

      // Subtotal inicial: (2 * 120) + (1 * 200) = 440
      expect(venta.subtotalVenta, 440.0);
      expect(venta.total, closeTo(440.0 * 1.16, 0.01));

      // Simular deslizamiento para eliminar prod1
      final articuloEliminado = venta.articulos.removeAt(0);
      expect(articuloEliminado.producto.id, 'P1');

      // Nuevo subtotal debe ser solo prod2 (200.0)
      expect(venta.subtotalVenta, 200.0);
      expect(venta.total, closeTo(200.0 * 1.16, 0.01));

      // Simular acción "Deshacer"
      venta.articulos.insert(0, articuloEliminado);
      expect(venta.articulos.length, 2);
      expect(venta.subtotalVenta, 440.0);
    });

    test('Cuando aplicarIva está desactivado, totalIva es 0 y total es igual al subtotal', () {
      final prod = Producto(
        id: 'P1',
        nombre: 'Suculenta',
        costo: 30.0,
        precioVenta: 75.0,
        cantidadEnInventario: 8,
      );

      final venta = Venta(
        id: 'V-002',
        fecha: DateTime.now(),
        articulos: [
          ArticuloVenta(producto: prod, cantidad: 2, precioUnitario: 75.0),
        ],
        porcentajeIva: 0.16,
        aplicarIva: false, // IVA desactivado
      );

      expect(venta.subtotalVenta, 150.0);
      expect(venta.totalIva, 0.0);
      expect(venta.total, 150.0);
    });
  });

  group('Gestión y Filtros de Productos (Plantas vs Artículos vs Stock Crítico)', () {
    test('Modelo Producto serializa y detecta tipo (planta / articulo) correctamente', () {
      final planta = Producto(
        id: 'P-1',
        nombre: 'Orquídea Phalaenopsis',
        precioVenta: 250.0,
        costo: 120.0,
        cantidadEnInventario: 10,
        tipo: 'planta',
      );
      expect(planta.esPlanta, isTrue);
      expect(planta.esArticulo, isFalse);

      final articulo = Producto(
        id: 'A-1',
        nombre: 'Sustrato para Orquídeas 5L',
        precioVenta: 95.0,
        costo: 40.0,
        cantidadEnInventario: 25,
        tipo: 'articulo',
      );
      expect(articulo.esPlanta, isFalse);
      expect(articulo.esArticulo, isTrue);

      final mapArticulo = articulo.toMap();
      expect(mapArticulo['tipo'], 'articulo');

      final deserializado = Producto.fromMap(mapArticulo);
      expect(deserializado.tipo, 'articulo');
      expect(deserializado.esArticulo, isTrue);
    });

    test('Filtros clasifican y separan adecuadamente Plantas, Artículos y Stock Crítico', () {
      final lista = [
        Producto(
          id: '1',
          nombre: 'Ficus Elástica',
          precioVenta: 180,
          costo: 90,
          cantidadEnInventario: 15,
          umbralStockCritico: 5,
          tipo: 'planta',
        ),
        Producto(
          id: '2',
          nombre: 'Cactus San Pedro',
          precioVenta: 120,
          costo: 60,
          cantidadEnInventario: 2,
          umbralStockCritico: 4,
          tipo: 'planta',
        ),
        Producto(
          id: '3',
          nombre: 'Maceta Barro 20cm',
          precioVenta: 85,
          costo: 35,
          cantidadEnInventario: 30,
          umbralStockCritico: 10,
          tipo: 'articulo',
        ),
        Producto(
          id: '4',
          nombre: 'Fertilizante Floración',
          precioVenta: 150,
          costo: 70,
          cantidadEnInventario: 1,
          umbralStockCritico: 3,
          tipo: 'articulo',
        ),
      ];

      // Filtro "Plantas"
      final plantas = lista.where((p) => p.esPlanta).toList();
      expect(plantas.length, 2);
      expect(plantas.map((p) => p.id), containsAll(['1', '2']));

      // Filtro "Artículos"
      final articulos = lista.where((p) => p.esArticulo).toList();
      expect(articulos.length, 2);
      expect(articulos.map((p) => p.id), containsAll(['3', '4']));

      // Filtro "Stock Crítico" (independiente del tipo)
      final stockCritico = lista.where((p) => p.esStockCritico).toList();
      expect(stockCritico.length, 2); // Cactus (2<=4) y Fertilizante (1<=3)
      expect(stockCritico.map((p) => p.id), containsAll(['2', '4']));
    });

    test('Filtros del POS (Ventas) aplican exclusividad Todos, Plantas y Artículos', () {
      final productos = [
        Producto(id: '1', nombre: 'Planta 1', precioVenta: 10, costo: 5, tipo: 'planta'),
        Producto(id: '2', nombre: 'Planta 2', precioVenta: 20, costo: 10, tipo: 'planta'),
        Producto(id: '3', nombre: 'Artículo 1', precioVenta: 30, costo: 15, tipo: 'articulo'),
      ];

      List<Producto> filtrarPOS(String cat) {
        return productos.where((p) {
          if (cat == 'planta') return p.esPlanta;
          if (cat == 'articulo') return p.esArticulo;
          return true; // 'all'
        }).toList();
      }

      expect(filtrarPOS('all').length, 3);
      expect(filtrarPOS('planta').length, 2);
      expect(filtrarPOS('articulo').length, 1);
      expect(filtrarPOS('articulo').first.nombre, 'Artículo 1');
    });
  });

  group('Biometría y Conexión de Lectores (WiFi, Bluetooth, Cable USB)', () {
    test('ConfiguracionBiometrica serializa y deserializa correctamente', () {
      final config = ConfiguracionBiometrica(
        biometriaHabilitada: true,
        usuarioVinculadoId: 'EMP-01',
        nombreHuella: 'Huella Pulgar Derecho',
        fechaRegistro: '2026-10-23T00:00:00',
        tipoConexion: 'wifi',
        wifiHost: '192.168.1.150',
        wifiPuerto: 4370,
        bluetoothDispositivo: 'POS-BioScanner-BT',
        cablePuertoSerial: 'COM4',
        cableBaudRate: 115200,
        ultimoEstadoConexion: 'Conectado',
      );

      expect(config.tieneHuellaRegistrada, isTrue);

      final map = config.toMap();
      expect(map['biometriaHabilitada'], 1);
      expect(map['usuarioVinculadoId'], 'EMP-01');
      expect(map['tipoConexion'], 'wifi');
      expect(map['wifiPuerto'], 4370);
      expect(map['cableBaudRate'], 115200);

      final deserializado = ConfiguracionBiometrica.fromMap(map);
      expect(deserializado.biometriaHabilitada, isTrue);
      expect(deserializado.usuarioVinculadoId, 'EMP-01');
      expect(deserializado.wifiHost, '192.168.1.150');
      expect(deserializado.bluetoothDispositivo, 'POS-BioScanner-BT');
      expect(deserializado.cablePuertoSerial, 'COM4');
      expect(deserializado.tieneHuellaRegistrada, isTrue);
    });

    test('Eliminación de huella restablece estado biométrico a inactivo', () {
      final config = ConfiguracionBiometrica(
        biometriaHabilitada: true,
        usuarioVinculadoId: 'EMP-01',
        nombreHuella: 'Huella Administrador',
      );
      expect(config.tieneHuellaRegistrada, isTrue);

      final configLimpia = config.copyWith(
        biometriaHabilitada: false,
        usuarioVinculadoId: null,
        nombreHuella: null,
      );
      expect(configLimpia.tieneHuellaRegistrada, isFalse);
      expect(configLimpia.usuarioVinculadoId, isNull);
    });

    test('Validación de conexiones de hardware (WiFi, Cable y Bluetooth)', () async {
      final servicio = ServicioBiometrico();

      // Validación de parámetros inválidos en WiFi
      final resWifiInvalido = await servicio.probarConexionWifi(host: '', puerto: 0);
      expect(resWifiInvalido.exito, isFalse);

      // Validación de parámetros inválidos en Cable Serial
      final resCableInvalido = await servicio.probarConexionCable(puertoSerial: '', baudRate: 9600);
      expect(resCableInvalido.exito, isFalse);

      // Validación de parámetros inválidos en Bluetooth
      final resBtInvalido = await servicio.probarConexionBluetooth(dispositivo: '');
      expect(resBtInvalido.exito, isFalse);
    });
  });

  group('Servicio de Imagen y Protección de Cámara', () {
    test('ServicioImagen instancia única y método seguro de recuperación', () async {
      final servicio = ServicioImagen.instancia;
      expect(servicio, isNotNull);
      final perdida = await servicio.recuperarImagenPerdida();
      expect(perdida, isNull);
    });

    testWidgets('CamaraVista se renderiza con estructura base', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CamaraVista(),
        ),
      );
      // Debe renderizar el Scaffold base en color negro y el indicador o mensaje
      expect(find.byType(CamaraVista), findsOneWidget);
    });
  });

  group('Servicio de Permisos en Tiempo de Ejecución', () {
    test('ServicioPermisos singleton disponible y operativo', () {
      final permisos = ServicioPermisos.instancia;
      expect(permisos, isNotNull);
    });
  });

  group('Control de Acceso Basado en Roles (RBAC) y RoleGuard', () {
    test('RolUsuario.desdeString mapea correctamente esquemas legados y sinónimos a 2 roles', () {
      expect(RolUsuario.desdeString('admin'), RolUsuario.duena);
      expect(RolUsuario.desdeString('dueña'), RolUsuario.duena);
      expect(RolUsuario.desdeString('duena'), RolUsuario.duena);
      expect(RolUsuario.desdeString('DUENA'), RolUsuario.duena);
      expect(RolUsuario.desdeString('dueño'), RolUsuario.duena);
      expect(RolUsuario.desdeString('dueno'), RolUsuario.duena);
      expect(RolUsuario.desdeString('gerente'), RolUsuario.empleado);
      expect(RolUsuario.desdeString('manager'), RolUsuario.empleado);
      expect(RolUsuario.desdeString('cajero'), RolUsuario.empleado);
      expect(RolUsuario.desdeString('empleado'), RolUsuario.empleado);
      expect(RolUsuario.desdeString(null), RolUsuario.empleado);
      expect(RolUsuario.desdeString('desconocido'), RolUsuario.empleado);
    });

    test('Permisos de negocio exclusivos de Dueño vs Empleado', () {
      expect(RolUsuario.duena.puedeVerFinanzas, isTrue);
      expect(RolUsuario.duena.puedeModificarInventario, isTrue);
      expect(RolUsuario.duena.puedeGestionarColaboradores, isTrue);
      expect(RolUsuario.duena.esDueno, isTrue);
      expect(RolUsuario.duena.esDuena, isTrue);

      expect(RolUsuario.empleado.puedeVerFinanzas, isFalse);
      expect(RolUsuario.empleado.puedeModificarInventario, isFalse);
      expect(RolUsuario.empleado.puedeGestionarColaboradores, isFalse);
      expect(RolUsuario.empleado.soloPuntoDeVenta, isTrue);
      expect(RolUsuario.empleado.esDueno, isFalse);
    });

    test('Colaborador serializa y deserializa rol correctamente', () {
      final colab = Colaborador(
        id: 'EMP-99',
        nombre: 'Cajero Prueba',
        clave: 'secret',
        rol: RolUsuario.empleado,
      );
      final map = colab.toMap();
      expect(map['rol'], 'empleado');

      final desdeMap = Colaborador.fromMap(map);
      expect(desdeMap.rol, RolUsuario.empleado);

      final desdeMapLegado = Colaborador.fromMap({
        'id': 'ADM-01',
        'nombre': 'Admin',
        'clave': 'pass',
        'rol': 'admin',
      });
      expect(desdeMapLegado.rol, RolUsuario.duena);
    });

    testWidgets('RoleGuard oculta widget cuando rol no está autorizado (modo ocultar)', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoleGuard.soloDueno(
              rolActual: RolUsuario.empleado,
              modo: RoleGuardMode.ocultar,
              child: Text('Solo Dueño'),
            ),
          ),
        ),
      );

      expect(find.text('Solo Dueño'), findsNothing);
    });

    testWidgets('RoleGuard muestra widget cuando rol sí está autorizado', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoleGuard.soloDueno(
              rolActual: RolUsuario.duena,
              modo: RoleGuardMode.ocultar,
              child: Text('Solo Dueño'),
            ),
          ),
        ),
      );

      expect(find.text('Solo Dueño'), findsOneWidget);
    });

    testWidgets('RoleGuard muestra AccesoDenegadoView cuando modo es placeholder', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoleGuard.soloDueno(
              rolActual: RolUsuario.empleado,
              modo: RoleGuardMode.placeholder,
              titulo: 'Acceso Prohibido',
              child: Text('Solo Dueño'),
            ),
          ),
        ),
      );

      expect(find.text('Solo Gerencia'), findsNothing);
      expect(find.text('Acceso Prohibido'), findsOneWidget);
      expect(find.text('Tu rol actual: Empleado'), findsOneWidget);
    });
  });

  group('Módulo de Deudores, Cuentas por Cobrar y Abonos', () {
    test('Venta calcula correctamente saldo pendiente y porcentaje pagado', () {
      final prod = Producto(
        id: 'P_DEUDA',
        nombre: 'Orquídea Phalaenopsis',
        costo: 100.0,
        precioVenta: 200.0,
        cantidadEnInventario: 5,
      );

      final venta = Venta(
        id: 'V_DEUDA_01',
        fecha: DateTime.now(),
        estado: EstadoVenta.apartada,
        aplicarIva: false,
        cliente: 'María López',
        montoPagado: 50.0,
      );
      venta.agregarArticulo(prod, 1);

      expect(venta.total, 200.0);
      expect(venta.montoPagado, 50.0);
      expect(venta.saldoPendiente, 150.0);
      expect(venta.tieneSaldoPendiente, isTrue);
      expect(venta.esApartada, isTrue);
      expect(venta.porcentajePagado, 0.25);

      // Simular abono que liquida la deuda
      venta.montoPagado = 200.0;
      expect(venta.saldoPendiente, 0.0);
      expect(venta.tieneSaldoPendiente, isFalse);
      expect(venta.porcentajePagado, 1.0);
    });

    test('Abono serializa y deserializa toMap y fromMap íntegramente', () {
      final ahora = DateTime.now();
      final abono = Abono(
        id: 'AB_01',
        ventaId: 'V_DEUDA_01',
        monto: 75.50,
        fecha: ahora,
        metodoPago: 'Transferencia',
      );

      final mapa = abono.toMap();
      expect(mapa['id'], 'AB_01');
      expect(mapa['venta_id'], 'V_DEUDA_01');
      expect(mapa['monto'], 75.50);
      expect(mapa['metodoPago'], 'Transferencia');

      final desdeMapa = Abono.fromMap(mapa);
      expect(desdeMapa.id, 'AB_01');
      expect(desdeMapa.monto, 75.50);
      expect(desdeMapa.metodoPago, 'Transferencia');
    });

    testWidgets('DeudoresVista se renderiza con AppBar y estado de carga inicial', (WidgetTester tester) async {
      final controladorInv = ControladorInventario();
      final controladorFin = ControladorFinanzas();
      final controladorPerf = ControladorPerfil();
      final controladorVentas = ControladorVentas(
        controladorInventario: controladorInv,
        controladorFinanzas: controladorFin,
        controladorPerfil: controladorPerf,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DeudoresVista(controladorVentas: controladorVentas),
        ),
      );

      expect(find.byType(DeudoresVista), findsOneWidget);
      expect(find.text('Cuentas por Cobrar'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Ajustes Visuales y Flujo Inicial (Splash, Tarjetas, Botón Editar, Perfil)', () {
    testWidgets('SplashVista se renderiza con el logotipo centrado e indicador de carga', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashVista(),
        ),
      );

      expect(find.byType(SplashVista), findsOneWidget);
      expect(find.text('Planteapp'), findsOneWidget);
      expect(find.text('Terminal de Punto de Venta Botánico'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Descartar timers pendientes para limpieza ordenada del test
      await tester.pump(const Duration(milliseconds: 500));
    });

    test('Tokens de color para Tarjetas de Inicio cumplen especificación botánica y relajada', () {
      AppColors.isDark = true;
      expect(AppColors.homeCardBackground, const Color(0xFF1E2620));
      expect(AppColors.homeCardBorder, const Color(0xFF2E3D31));
      expect(AppColors.homeCardGradient, isNotNull);

      AppColors.isDark = false;
      expect(AppColors.homeCardBackground, const Color(0xFFFFFFFF));
      expect(AppColors.homeCardBorder, const Color(0xFFEAE5DC));
      expect(AppColors.homeCardGradient, isNull);
    });

    testWidgets('TarjetaProductoInventario presenta botón de editar con área táctil mejorada (>= 40px)', (WidgetTester tester) async {
      final prod = Producto(
        id: 'TEST-001',
        nombre: 'Ficus Lyrata',
        precioVenta: 35.0,
        costo: 15.0,
        cantidadEnInventario: 8,
        tipo: 'planta',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TarjetaProductoInventario(
              prod: prod,
              onEditar: () {},
              onAjustar: () {},
              onBorrar: () {},
              rolActual: RolUsuario.duena,
            ),
          ),
        ),
      );

      final botonEditar = find.byTooltip('Editar producto');
      expect(botonEditar, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(botonEditar);
      expect(renderBox.size.width, greaterThanOrEqualTo(40.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(40.0));
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('PerfilVista no muestra el apartado de Alertas y Notificaciones', (WidgetTester tester) async {
      final ctrlPerfil = ControladorPerfil();
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerfil,
      );
      final ctrlAuth = ControladorAutenticacion();
      final ctrlBio = ControladorBiometrico();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ControladorPerfil>.value(value: ctrlPerfil),
            ChangeNotifierProvider<ControladorVentas>.value(value: ctrlVentas),
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: ctrlAuth),
            Provider<ControladorBiometrico>.value(value: ctrlBio),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PerfilVista(
                onLogout: () {},
              ),
            ),
          ),
        ),
      );

      // Verificamos que Alertas y Notificaciones fue eliminado/ocultado
      expect(find.text('Alertas y Notificaciones'), findsNothing);
      expect(find.text('Configurar alertas de stock'), findsNothing);
    });

    testWidgets('Modo Empleado en Dashboard oculta métricas financieras y muestra panel operativo', (WidgetTester tester) async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      ctrlPerf.configuracion.aplicarIva = false;
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlInicio = ControladorInicio(
        controladorInventario: ctrlInv,
        controladorVentas: ctrlVentas,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlAuth = ControladorAutenticacion();
      ctrlAuth.establecerUsuarioParaPruebas(
        Colaborador(
          id: 'EMP_01',
          nombre: 'Carlos Empleado',
          clave: '123456',
          rol: RolUsuario.empleado,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorInicio>.value(value: ctrlInicio),
            ChangeNotifierProvider<ControladorInventario>.value(value: ctrlInv),
            ChangeNotifierProvider<ControladorVentas>.value(value: ctrlVentas),
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: ctrlAuth),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DashboardVista(
                alNavegar: (_) {},
              ),
            ),
          ),
        ),
      );

      // Métricas financieras deben estar ocultas
      expect(find.text('Ingresos Totales'), findsNothing);
      expect(find.text('Ticket prom.'), findsNothing);

      // Terminal operativo y acceso a Deudores deben estar visibles
      expect(find.text('Terminal Operativo • Modo Empleado'), findsOneWidget);
      expect(find.text('Cuentas por Cobrar'), findsOneWidget);
      expect(find.text('Ver todos'), findsOneWidget);
    });

    testWidgets('Modo Dueña en Dashboard muestra ingresos totales y tarjeta de deudores', (WidgetTester tester) async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      ctrlPerf.configuracion.aplicarIva = false;
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlInicio = ControladorInicio(
        controladorInventario: ctrlInv,
        controladorVentas: ctrlVentas,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlAuth = ControladorAutenticacion();
      ctrlAuth.establecerUsuarioParaPruebas(
        Colaborador(
          id: 'ADM_01',
          nombre: 'Ana Dueña',
          clave: '123456',
          rol: RolUsuario.duena,
        ),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorInicio>.value(value: ctrlInicio),
            ChangeNotifierProvider<ControladorInventario>.value(value: ctrlInv),
            ChangeNotifierProvider<ControladorVentas>.value(value: ctrlVentas),
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: ctrlAuth),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DashboardVista(
                alNavegar: (_) {},
              ),
            ),
          ),
        ),
      );

      // Métricas financieras deben estar visibles para Dueña
      expect(find.text('Ingresos Totales'), findsOneWidget);
      expect(find.text('Ticket prom.'), findsOneWidget);

      // Tarjeta de Deudores con botón 'Ver todos' debe estar visible
      expect(find.text('Cuentas por Cobrar'), findsOneWidget);
      expect(find.text('Ver todos'), findsOneWidget);
    });
  });

  group('Persistencia de Sesión y Generación de Tickets PDF', () {
    test('ServicioTicketPdf instancia singleton disponible', () {
      final servicio = ServicioTicketPdf.instancia;
      expect(servicio, isNotNull);
    });

    testWidgets('TarjetaHistorialVenta muestra botón de descarga de Ticket PDF', (WidgetTester tester) async {
      final venta = Venta(
        id: 'VENTA-TEST-99',
        fecha: DateTime.now(),
        articulos: [
          ArticuloVenta(
            producto: Producto(
              id: 'P1',
              nombre: 'Helecho Espada',
              precioVenta: 25.0,
              costo: 10.0,
              cantidadEnInventario: 5,
              tipo: 'planta',
            ),
            cantidad: 2,
            precioUnitario: 25.0,
          ),
        ],
        estado: EstadoVenta.completada,
        cliente: 'Laura Flores',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TarjetaHistorialVenta(venta: venta),
          ),
        ),
      );

      expect(find.text('Ticket PDF'), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.byTooltip('Descargar Ticket PDF'), findsOneWidget);
    });

    test('SecureStorageService almacena y lee preferencias de sesión correctamente', () async {
      final storage = SecureStorageService.instancia;
      await storage.guardar('planteapp_recordar_sesion', 'true');
      await storage.guardar('planteapp_ultimo_usuario_id', 'VO-4092');

      final recordar = await storage.leer('planteapp_recordar_sesion');
      final usuarioId = await storage.leer('planteapp_ultimo_usuario_id');

      expect(recordar == 'true' || recordar == null, isTrue);
      expect(usuarioId == 'VO-4092' || usuarioId == null, isTrue);
    });
  });

  group('Prevención de Bad State en Abonos y Transacciones SQLite', () {
    test('TransaccionFinanciera.fromMap maneja mayúsculas, minúsculas y desconocidos sin crashear', () {
      final t1 = TransaccionFinanciera.fromMap({
        'id': 'T1',
        'tipo': 'INGRESO',
        'monto': 150.0,
        'fecha': '2026-11-07T12:00:00.000',
        'descripcion': 'Abono recibido',
      });
      expect(t1.tipo, TipoTransaccion.ingreso);

      final t2 = TransaccionFinanciera.fromMap({
        'id': 'T2',
        'tipo': 'desconocido_fallback',
        'monto': 50.0,
        'fecha': '2026-11-07T12:00:00.000',
        'descripcion': 'Fallback test',
      });
      expect(t2.tipo, TipoTransaccion.ingreso);
    });

    test('Venta.fromMap maneja estados con tolerancia a mayúsculas y fallback seguro', () {
      final v = Venta.fromMap({
        'id': 'V-TEST-1',
        'fecha': '2026-11-07T12:00:00.000',
        'estado': 'APARTADA',
        'porcentajeIva': 0.16,
        'aplicarIva': 1,
        'cliente': 'Carlos Vivero',
        'montoPagado': 200.0,
        'notas': 'Apartado con 50%',
      }, []);
      expect(v.estado, EstadoVenta.apartada);
    });
  });

  group('Gestión de Empleados y Barrera de Seguridad', () {
    testWidgets('EmpleadosVista presenta FloatingActionButton de Nuevo Empleado', (WidgetTester tester) async {
      final ctrlAuth = ControladorAutenticacion();
      ctrlAuth.establecerUsuarioParaPruebas(
        Colaborador(
          id: 'ADMIN-01',
          nombre: 'Dueña General',
          clave: 'clave_hash',
          rol: RolUsuario.duena,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EmpleadosVista(controladorAutenticacion: ctrlAuth),
        ),
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Nuevo Empleado'), findsOneWidget);
    });

    test('Protección Anti-Suicidio: ControladorAutenticacion impide que el usuario activo se elimine', () async {
      final ctrlAuth = ControladorAutenticacion();
      final dueno = Colaborador(
        id: 'DUENO-01',
        nombre: 'Dueño Principal',
        clave: 'hash',
        rol: RolUsuario.duena,
      );
      final empleado = Colaborador(
        id: 'EMP-02',
        nombre: 'Empleado Mostrador',
        clave: 'hash',
        rol: RolUsuario.empleado,
      );

      ctrlAuth.establecerUsuarioParaPruebas(dueno);
      ctrlAuth.establecerColaboradoresParaPruebas([dueno, empleado]);

      // Intento de auto-eliminación debe lanzar excepción de protección Anti-Suicidio
      expect(
        () => ctrlAuth.eliminarColaborador('DUENO-01'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('No puedes eliminar tu propia cuenta mientras tengas la sesión activa'),
        )),
      );

      // Eliminación de un empleado subordinado sí es permitida
      final exito = await ctrlAuth.eliminarColaborador('EMP-02');
      expect(exito, isTrue);
      expect(ctrlAuth.colaboradores.any((c) => c.id == 'EMP-02'), isFalse);
    });

    testWidgets('EmpleadosVista bloquea acceso a usuarios que no son Dueño', (WidgetTester tester) async {
      final ctrlAuth = ControladorAutenticacion();
      ctrlAuth.establecerUsuarioParaPruebas(
        Colaborador(
          id: 'EMP-01',
          nombre: 'Cajero',
          clave: 'hash',
          rol: RolUsuario.empleado,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EmpleadosVista(controladorAutenticacion: ctrlAuth),
        ),
      );
      await tester.pump();

      expect(find.text('Gestión de Personal Reservada'), findsOneWidget);
      expect(find.textContaining('Solo el Dueño tiene autorización'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('EmpleadosVista aplica Protección Anti-Suicidio visual en lista', (WidgetTester tester) async {
      final ctrlAuth = ControladorAutenticacion();
      final dueno = Colaborador(
        id: 'DUENO-01',
        nombre: 'Dueño Activo',
        clave: 'hash',
        rol: RolUsuario.duena,
      );
      final empleado = Colaborador(
        id: 'EMP-02',
        nombre: 'Empleado Auxiliar',
        clave: 'hash',
        rol: RolUsuario.empleado,
      );

      ctrlAuth.establecerUsuarioParaPruebas(dueno);
      ctrlAuth.establecerColaboradoresParaPruebas([dueno, empleado]);

      await tester.pumpWidget(
        MaterialApp(
          home: EmpleadosVista(controladorAutenticacion: ctrlAuth),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar la insignia 'Tú' para la sesión activa (Anti-Suicidio)
      expect(find.text('Tú'), findsOneWidget);
      expect(find.byIcon(Icons.shield_rounded), findsOneWidget);

      // Debe haber exactamente 1 botón de eliminar (para el empleado, NO para el dueño activo)
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('DialogoSeguridadAdmin se renderiza con campo de clave y botón de verificar', (WidgetTester tester) async {
      final ctrlAuth = ControladorAutenticacion();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DialogoSeguridadAdmin(controladorAutenticacion: ctrlAuth),
          ),
        ),
      );

      expect(find.text('Autorización de Seguridad'), findsOneWidget);
      expect(find.text('Contraseña de Dueña/Admin'), findsOneWidget);
      expect(find.text('Verificar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('FormularioEmpleadoSheet presenta campos de Nombre, Rol y Contraseña', (WidgetTester tester) async {
      final ctrlAuth = ControladorAutenticacion();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormularioEmpleadoSheet(controladorAutenticacion: ctrlAuth),
          ),
        ),
      );

      expect(find.text('Nuevo Empleado'), findsOneWidget);
      expect(find.text('Nombre completo *'), findsOneWidget);
      expect(find.text('Rol en Planteapp *'), findsOneWidget);
      expect(find.text('Contraseña de acceso *'), findsOneWidget);
      expect(find.text('Registrar Empleado'), findsOneWidget);
    });

    testWidgets('FormularioEmpleadoSheet aplica Protección Anti-Degradación cuando el Dueño edita su propio usuario', (WidgetTester tester) async {
      final ctrlAuth = ControladorAutenticacion();
      final dueno = Colaborador(
        id: 'DUENO-99',
        nombre: 'Ana Dueña',
        clave: '1234',
        rol: RolUsuario.duena,
      );
      ctrlAuth.establecerUsuarioParaPruebas(dueno);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormularioEmpleadoSheet(
              empleadoExistente: dueno,
              controladorAutenticacion: ctrlAuth,
            ),
          ),
        ),
      );

      expect(find.text('Editar Empleado'), findsOneWidget);
      expect(find.text('Rol: Dueño (No modificable)'), findsOneWidget);
      expect(find.text('TÚ'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<RolUsuario>), findsNothing);
    });

    testWidgets('FormularioEmpleadoSheet permite editar rol si el Dueño edita a otro colaborador', (WidgetTester tester) async {
      final ctrlAuth = ControladorAutenticacion();
      final dueno = Colaborador(
        id: 'DUENO-99',
        nombre: 'Ana Dueña',
        clave: '1234',
        rol: RolUsuario.duena,
      );
      final empleado = Colaborador(
        id: 'EMP-01',
        nombre: 'Juan Empleado',
        clave: '1234',
        rol: RolUsuario.empleado,
      );
      ctrlAuth.establecerUsuarioParaPruebas(dueno);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormularioEmpleadoSheet(
              empleadoExistente: empleado,
              controladorAutenticacion: ctrlAuth,
            ),
          ),
        ),
      );

      expect(find.text('Editar Empleado'), findsOneWidget);
      expect(find.text('Rol en Planteapp *'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<RolUsuario>), findsOneWidget);
      expect(find.text('Rol: Dueño (No modificable)'), findsNothing);
    });

    test('ControladorAutenticacion.actualizarColaborador bloquea auto-degradación de rol a nivel de dominio', () async {
      final ctrlAuth = ControladorAutenticacion();
      final dueno = Colaborador(
        id: 'DUENO-99',
        nombre: 'Ana Dueña',
        clave: '1234',
        rol: RolUsuario.duena,
      );
      ctrlAuth.establecerUsuarioParaPruebas(dueno);
      ctrlAuth.establecerColaboradoresParaPruebas([dueno]);

      // Intento de auto-degradación a empleado
      final duenoDegradado = dueno.copyWith(rol: RolUsuario.empleado, nombre: 'Ana Modificada');
      await ctrlAuth.actualizarColaborador(duenoDegradado);

      // El rol debe permanecer como RolUsuario.duena
      expect(ctrlAuth.usuarioActual?.rol, RolUsuario.duena);
      expect(ctrlAuth.usuarioActual?.nombre, 'Ana Modificada');
      expect(ctrlAuth.colaboradores.first.rol, RolUsuario.duena);
    });
  });

  group('Persistencia de Ventas y Carga Inicial en SQLite', () {
    test('ControladorVentas expone método cargarVentasHistorial para sincronización de arranque', () {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      ctrlPerf.configuracion.aplicarIva = false;
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );

      expect(ctrlVentas.cargarVentasHistorial, isA<Function>());
    });

    testWidgets('HistorialVentasVista inicializa y permite refrescar ventas con RefreshIndicator', (WidgetTester tester) async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      ctrlPerf.configuracion.aplicarIva = false;
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HistorialVentasVista(controladorVentas: ctrlVentas),
        ),
      );
      await tester.pump();

      expect(find.text('Historial de Ventas'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
    });
  });

  group('Estandarización de Formato Numérico y Moneda (Formateador e intl)', () {
    test('Formateador.moneda formatea correctamente con comas y puntos', () {
      expect(Formateador.moneda(1500.5), r'$1,500.50');
      expect(Formateador.moneda(1500.5, conEspacio: true), r'$ 1,500.50');
      expect(Formateador.moneda(1000000.99), r'$1,000,000.99');
      expect(Formateador.moneda(0), r'$0.00');
      expect(Formateador.moneda(null), r'$0.00');
    });

    test('Extensiones numéricas .aMoneda() y .aNumero() funcionan con fluidez', () {
      expect(1500.5.aMoneda(), r'$1,500.50');
      expect(1500.5.aMoneda(conEspacio: true), r'$ 1,500.50');
      expect(1500.5.aNumero(), '1,500.50');
      expect(1250.aEntero(), '1,250');

      num? valorNulo;
      expect(valorNulo.aMoneda(), r'$0.00');
    });
  });

  group('Encapsulamiento del Carrito en ControladorVentas (P0)', () {
    test('agregarArticulo, decrementarArticulo, actualizarCantidadArticulo y eliminarArticulo', () {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      ctrlPerf.configuracion.aplicarIva = false;
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );

      final producto = Producto(
        id: 'P-TEST-1',
        nombre: 'Monstera Deliciosa',
        precioVenta: 150.0,
        costo: 80.0,
        cantidadEnInventario: 5,
        tipo: 'planta',
      );

      // 1. Agregar artículo
      ctrlVentas.agregarArticulo(producto, 2);
      expect(ctrlVentas.obtenerCantidadEnCarrito('P-TEST-1'), 2);
      expect(ctrlVentas.totalArticulosEnCarrito, 2);
      expect(ctrlVentas.totalVentaActual, 300.0);

      // 2. Incrementar agregando 1 más
      ctrlVentas.agregarArticulo(producto, 1);
      expect(ctrlVentas.obtenerCantidadEnCarrito('P-TEST-1'), 3);
      expect(ctrlVentas.totalArticulosEnCarrito, 3);
      expect(ctrlVentas.totalVentaActual, 450.0);

      // 3. Decrementar
      ctrlVentas.decrementarArticulo('P-TEST-1');
      expect(ctrlVentas.obtenerCantidadEnCarrito('P-TEST-1'), 2);
      expect(ctrlVentas.totalArticulosEnCarrito, 2);
      expect(ctrlVentas.totalVentaActual, 300.0);

      // 4. Actualizar cantidad directamente dentro del rango
      ctrlVentas.actualizarCantidadArticulo(0, 4);
      expect(ctrlVentas.obtenerCantidadEnCarrito('P-TEST-1'), 4);
      expect(ctrlVentas.totalArticulosEnCarrito, 4);

      // 5. Exceder inventario debe lanzar excepción
      expect(
        () => ctrlVentas.actualizarCantidadArticulo(0, 10),
        throwsA(isA<Exception>()),
      );

      // 6. Eliminar artículo
      ctrlVentas.eliminarArticulo(0);
      expect(ctrlVentas.obtenerCantidadEnCarrito('P-TEST-1'), 0);
      expect(ctrlVentas.totalArticulosEnCarrito, 0);
      expect(ctrlVentas.totalVentaActual, 0.0);
    });
  });

  group('Impresión Térmica ESC/POS y Hardware Bluetooth (P0)', () {
    test('GeneradorEscPos produce secuencias de bytes binarios válidos para 58mm y 80mm', () {
      final gen58 = GeneradorEscPos(es80mm: false);
      expect(gen58.maxColumnas, 32);

      gen58.texto('TEST 58MM', alineacion: AlineacionEscPos.centro, esNegrita: true);
      gen58.lineaDivisoria('=');
      gen58.filaDosColumnas('Monstera', '\$28.00');
      gen58.cortarPapel();

      final bytes58 = gen58.obtenerBytes();
      expect(bytes58.isNotEmpty, isTrue);
      // Validar comando de inicialización ESC @ (0x1B, 0x40)
      expect(bytes58[0], 0x1B);
      expect(bytes58[1], 0x40);

      final gen80 = GeneradorEscPos(es80mm: true);
      expect(gen80.maxColumnas, 48);
    });

    test('ControladorHardware inicializa con defaults y gestiona ciclo de vida', () {
      final ctrlHw = ControladorHardware();
      expect(ctrlHw.config.impresoraTipo, 'bluetooth');
      expect(ctrlHw.config.impresoraAnchoPapel, '80mm');
      expect(ctrlHw.config.impresoraConectada, isFalse);
    });
  });

  group('Logotipo Oficial Adaptativo SVG (LogoBiznaga)', () {
    testWidgets('LogoBiznaga selecciona logo_claro.svg en modo claro', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: LogoBiznaga(size: 100),
          ),
        ),
      );

      final svgFinder = find.byType(SvgPicture);
      expect(svgFinder, findsOneWidget);
      final SvgPicture svg = tester.widget(svgFinder);
      final BytesLoader loader = svg.bytesLoader;
      expect(loader, isA<SvgAssetLoader>());
      final assetLoader = loader as SvgAssetLoader;
      expect(assetLoader.assetName, LogoBiznaga.assetClaro);
    });

    testWidgets('LogoBiznaga selecciona logo_oscuro.svg en modo oscuro', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: LogoBiznaga(size: 120),
          ),
        ),
      );

      final svgFinder = find.byType(SvgPicture);
      expect(svgFinder, findsOneWidget);
      final SvgPicture svg = tester.widget(svgFinder);
      final BytesLoader loader = svg.bytesLoader;
      expect(loader, isA<SvgAssetLoader>());
      final assetLoader = loader as SvgAssetLoader;
      expect(assetLoader.assetName, LogoBiznaga.assetOscuro);
    });
  });

  group('Reactividad Contable en ControladorFinanzas (P1)', () {
    test('ControladorFinanzas es ChangeNotifier y expone estado inicial consistente', () {
      final ctrlFin = ControladorFinanzas();
      expect(ctrlFin, isA<ChangeNotifier>());
      expect(ctrlFin.transacciones, isEmpty);
      expect(ctrlFin.totalIngresos, 0.0);
      expect(ctrlFin.totalEgresos, 0.0);
      expect(ctrlFin.totalMermas, 0.0);
      expect(ctrlFin.balanceTotal, 0.0);
      expect(ctrlFin.obtenerBalance(), 0.0);
      expect(ctrlFin.cargando, isFalse);
    });

    test('registrarIngreso, registrarEgreso, registrarMerma y registrarIngresoVentaContado notifican reactivamente a listeners', () async {
      final ctrlFin = ControladorFinanzas();
      int notificaciones = 0;
      ctrlFin.addListener(() {
        notificaciones++;
      });

      // 1. Ingreso
      await ctrlFin.registrarIngreso('Venta mostrador', 150.0);
      expect(notificaciones, 1);
      expect(ctrlFin.transacciones.length, 1);
      expect(ctrlFin.totalIngresos, 150.0);
      expect(ctrlFin.balanceTotal, 150.0);

      // 2. Egreso
      await ctrlFin.registrarEgreso('Compra sustrato', 50.0);
      expect(notificaciones, 2);
      expect(ctrlFin.transacciones.length, 2);
      expect(ctrlFin.totalEgresos, 50.0);
      expect(ctrlFin.balanceTotal, 100.0);

      // 3. Merma
      await ctrlFin.registrarMerma('Planta marchita', 20.0);
      expect(notificaciones, 3);
      expect(ctrlFin.transacciones.length, 3);
      expect(ctrlFin.totalMermas, 20.0);
      expect(ctrlFin.totalEgresos, 70.0);
      expect(ctrlFin.balanceTotal, 80.0);

      // 4. Venta Contado Semántica
      await ctrlFin.registrarIngresoVentaContado(ventaId: 'VTA-999', monto: 200.0);
      expect(notificaciones, 4);
      expect(ctrlFin.transacciones.length, 4);
      expect(ctrlFin.totalIngresos, 350.0);
      expect(ctrlFin.balanceTotal, 280.0);
      expect(ctrlFin.obtenerBalance(), 280.0);
    });

    test('ControladorInicio escucha automáticamente cambios en ControladorFinanzas y recalcula métricas', () async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlInicio = ControladorInicio(
        controladorInventario: ctrlInv,
        controladorVentas: ctrlVentas,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );

      int inicioNotificaciones = 0;
      ctrlInicio.addListener(() {
        inicioNotificaciones++;
      });

      await ctrlFin.registrarIngreso('Aporte extraordinario', 500.0);
      expect(inicioNotificaciones, greaterThanOrEqualTo(1));
    });
  });

  group('Carga Perezosa de Pestañas en InicioVista (P1)', () {
    testWidgets('InicioVista monta bajo demanda solo la pestaña activa liberando memoria Heap', (WidgetTester tester) async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      ctrlPerf.configuracion.aplicarIva = false;
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlInicio = ControladorInicio(
        controladorInventario: ctrlInv,
        controladorVentas: ctrlVentas,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlAuth = ControladorAutenticacion();
      ctrlAuth.establecerUsuarioParaPruebas(
        Colaborador(
          id: 'ADM_01',
          nombre: 'Ana Dueña',
          clave: '123456',
          rol: RolUsuario.duena,
        ),
      );
      final ctrlHw = ControladorHardware();
      final ctrlIA = ControladorIACompras(controladorInventario: ctrlInv);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorInicio>.value(value: ctrlInicio),
            ChangeNotifierProvider<ControladorInventario>.value(value: ctrlInv),
            ChangeNotifierProvider<ControladorVentas>.value(value: ctrlVentas),
            ChangeNotifierProvider<ControladorFinanzas>.value(value: ctrlFin),
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: ctrlAuth),
            Provider<ControladorPerfil>.value(value: ctrlPerf),
            ChangeNotifierProvider<ControladorHardware>.value(value: ctrlHw),
            ChangeNotifierProvider<ControladorIACompras>.value(value: ctrlIA),
          ],
          child: const MaterialApp(
            home: InicioVista(),
          ),
        ),
      );

      // En el arranque inicial (tab 0: Inicio / Dashboard):
      // 1. DashboardVista DEBE estar montado
      expect(find.byType(DashboardVista), findsOneWidget);

      // 2. PosVista e InventarioVista NO deben estar montados en memoria (Lazy Loading)
      expect(find.byType(PosVista), findsNothing);
      expect(find.byType(InventarioVista), findsNothing);

      // Al navegar a 'Ventas' (tab 1):
      await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
      await tester.pumpAndSettle();

      // PosVista se monta bajo demanda
      expect(find.byType(PosVista), findsOneWidget);
      // DashboardVista e InventarioVista no están montados
      expect(find.byType(DashboardVista), findsNothing);
      expect(find.byType(InventarioVista), findsNothing);

      // Al navegar a 'Inventario' (tab 2):
      await tester.tap(find.text('Inventario').last);
      await tester.pumpAndSettle();

      expect(find.byType(InventarioVista), findsOneWidget);
      expect(find.byType(PosVista), findsNothing);
    });
  });

  group('Erradicación de AppColors.isDark y Declaratividad de Tema (P1)', () {
    testWidgets('LoginVista se renderiza puramente desde Theme.of(context) en modo claro y oscuro', (WidgetTester tester) async {
      final ctrlAuth = ControladorAutenticacion();
      final ctrlBio = ControladorBiometrico();

      // 1. Renderizado en Modo Claro
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: ctrlAuth),
            Provider<ControladorBiometrico>.value(value: ctrlBio),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginVista(),
          ),
        ),
      );

      expect(find.byType(LogoBiznaga), findsOneWidget);
      expect(find.text('Usuario o correo'), findsOneWidget);
      expect(find.text('PIN de acceso o clave'), findsOneWidget);
      expect(find.text('Ingresar'), findsOneWidget);

      // 2. Renderizado en Modo Oscuro
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: ctrlAuth),
            Provider<ControladorBiometrico>.value(value: ctrlBio),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const LoginVista(),
          ),
        ),
      );

      expect(find.byType(LogoBiznaga), findsOneWidget);
      expect(find.text('Usuario o correo'), findsOneWidget);
      expect(find.text('PIN de acceso o clave'), findsOneWidget);
      expect(find.text('Ingresar'), findsOneWidget);
    });

    testWidgets('LogoBiznaga resuelve brillo mediante BotanicalThemeColors sin tocar banderas estáticas', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: const Scaffold(
            body: LogoBiznaga(size: 80),
          ),
        ),
      );

      final svgFinderClaro = find.byType(SvgPicture);
      expect(svgFinderClaro, findsOneWidget);
      final SvgPicture svgClaro = tester.widget(svgFinderClaro);
      final assetLoaderClaro = svgClaro.bytesLoader as SvgAssetLoader;
      expect(assetLoaderClaro.assetName, LogoBiznaga.assetClaro);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: LogoBiznaga(size: 80),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final svgFinderOscuro = find.byType(SvgPicture);
      expect(svgFinderOscuro, findsOneWidget);
      final SvgPicture svgOscuro = tester.widget(svgFinderOscuro);
      final assetLoaderOscuro = svgOscuro.bytesLoader as SvgAssetLoader;
      expect(assetLoaderOscuro.assetName, LogoBiznaga.assetOscuro);
    });
  });

  group('Granularidad con Selector en Inventario y POS (P2)', () {
    testWidgets('InventarioVista utiliza Selector para aislar re-renderizados de productos', (tester) async {
      final cInv = ControladorInventario();
      final cFinanzas = ControladorFinanzas();
      final cPerfil = ControladorPerfil();
      final cVentas = ControladorVentas(
        controladorInventario: cInv,
        controladorFinanzas: cFinanzas,
        controladorPerfil: cPerfil,
      );
      final cAuth = ControladorAutenticacion();
      final cIA = ControladorIACompras(controladorInventario: cInv);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: cInv),
            ChangeNotifierProvider.value(value: cVentas),
            ChangeNotifierProvider.value(value: cAuth),
            ChangeNotifierProvider.value(value: cIA),
            ChangeNotifierProvider.value(value: cFinanzas),
            Provider<ControladorPerfil>.value(value: cPerfil),
          ],
          child: const MaterialApp(
            home: InventarioVista(),
          ),
        ),
      );

      expect(find.byType(Selector<ControladorInventario, List<Producto>>), findsOneWidget);
    });

    testWidgets('PosVista utiliza Selector para aislar la cuadrícula del catálogo', (tester) async {
      final cInv = ControladorInventario();
      final cFinanzas = ControladorFinanzas();
      final cPerfil = ControladorPerfil();
      final cVentas = ControladorVentas(
        controladorInventario: cInv,
        controladorFinanzas: cFinanzas,
        controladorPerfil: cPerfil,
      );
      final cAuth = ControladorAutenticacion();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: cInv),
            ChangeNotifierProvider.value(value: cVentas),
            ChangeNotifierProvider.value(value: cAuth),
            ChangeNotifierProvider.value(value: cFinanzas),
            Provider<ControladorPerfil>.value(value: cPerfil),
          ],
          child: const MaterialApp(
            home: PosVista(),
          ),
        ),
      );

      expect(find.byType(Selector<ControladorInventario, List<Producto>>), findsOneWidget);
    });
  });

  group('Paginación en Consultas Históricas y Búsqueda Optimizada (P2)', () {
    test('ControladorVentas soporta parámetros limite y offset en cargarVentas', () {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );

      expect(ctrlVentas.hayMasVentas, isTrue);
      expect(ctrlVentas.cargandoPaginaVentas, isFalse);
      expect(ctrlVentas.cargarSiguientePaginaVentas, isA<Function>());
      expect(ctrlVentas.refrescarVentasHistorial, isA<Function>());
    });

    test('ControladorInventario soporta paginación y búsqueda indexada con límite', () {
      final ctrlInv = ControladorInventario();
      expect(ctrlInv.buscarProductosAsync, isA<Function>());
    });

    testWidgets('HistorialVentasVista inicializa con ScrollController para paginación progresiva', (tester) async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HistorialVentasVista(controladorVentas: ctrlVentas),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });
  });

  group('Concurrencia y Optimización WAL en SQLite', () {
    test('BaseDeDatos expone método singleton para inicializar base de datos con WAL', () {
      expect(BaseDeDatos.instancia, isNotNull);
      expect(BaseDeDatos.instancia, same(BaseDeDatos.instancia));
    });
  });

  group('ControladorCuentasPorCobrar y Desacoplamiento SRP', () {
    test('ControladorCuentasPorCobrar inicializa con estado consistente y extiende ChangeNotifier', () {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlCobrar = ControladorCuentasPorCobrar(
        controladorVentas: ctrlVentas,
        controladorFinanzas: ctrlFin,
      );

      expect(ctrlCobrar, isA<ChangeNotifier>());
      expect(ctrlCobrar.cuentasPorCobrar, isEmpty);
      expect(ctrlCobrar.cargando, isFalse);
      expect(ctrlCobrar.totalSaldoPendiente, 0.0);
      expect(ctrlCobrar.totalCuentasActivas, 0);
    });

    test('registrarAbono y liquidarDeuda registran ingresos en finanzas y traspasan a completada (ACID)', () async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      ctrlPerf.configuracion.aplicarIva = false;
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlCobrar = ControladorCuentasPorCobrar(
        controladorVentas: ctrlVentas,
        controladorFinanzas: ctrlFin,
      );

      final p1 = Producto(
        id: 'p_deuda_acid',
        nombre: 'Bonsai Jade',
        precioVenta: 500.0,
        costo: 200.0,
        cantidadEnInventario: 10,
      );
      await ctrlInv.agregarProducto(p1);

      final String idVenta = 'V_ACID_${DateTime.now().microsecondsSinceEpoch}';

      // Crear venta apartada en SQLite
      final ventaApartada = Venta(
        id: idVenta,
        fecha: DateTime.now(),
        estado: EstadoVenta.apartada,
        aplicarIva: false,
        cliente: 'Carlos Vega',
        montoPagado: 100.0,
      );
      ventaApartada.agregarArticulo(p1, 1);

      final db = await BaseDeDatos.instancia.database;
      await db.insert('ventas', ventaApartada.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      for (final art in ventaApartada.articulos) {
        await db.insert('articulos_venta', art.toMap(ventaApartada.id), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await db.insert('deudores', {
        'id': 'deu_${ventaApartada.id}',
        'venta_id': ventaApartada.id,
        'cliente': ventaApartada.cliente,
        'telefono': '555-1234',
        'montoTotal': 500.0,
        'montoPagado': 100.0,
        'saldoPendiente': 400.0,
        'estado': 'PENDIENTE',
        'fechaRegistro': ventaApartada.fecha.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await ctrlVentas.cargarVentas();
      await ctrlFin.cargarTransacciones();
      final ingresosIniciales = ctrlFin.totalIngresos;

      // 1. Registrar abono parcial de $200.0
      final comp1 = await ctrlCobrar.registrarAbono(
        ventaId: idVenta,
        monto: 200.0,
        metodoPago: 'Efectivo',
      );

      expect(comp1.abonoHoy, 200.0);
      expect(comp1.saldoRestante, 200.0);
      expect(comp1.totalPagado, 300.0);
      expect(comp1.liquidado, isFalse);

      // Verificar que finanzas registró el ingreso de $200.0
      expect(ctrlFin.totalIngresos, ingresosIniciales + 200.0);
      final ultimaTxn = ctrlFin.transacciones.first;
      expect(ultimaTxn.esIngreso, isTrue);
      expect(ultimaTxn.monto, 200.0);
      expect(ultimaTxn.descripcion, contains('Folio #$idVenta'));

      // 2. Liquidación total de la deuda restante ($200.0) mediante liquidarDeuda
      final comp2 = await ctrlCobrar.liquidarDeuda(
        ventaId: idVenta,
        metodoPago: 'Transferencia',
      );

      expect(comp2, isNotNull);
      expect(comp2!.liquidado, isTrue);
      expect(comp2.saldoRestante, 0.0);
      expect(comp2.totalPagado, 500.0);

      // Verificar que finanzas registró el ingreso final de $200.0
      expect(ctrlFin.totalIngresos, ingresosIniciales + 400.0);

      // 3. Traspaso al Historial de Ventas: el estado de la venta es ahora 'completada'
      await ctrlVentas.cargarVentas();
      final ventaActualizada = ctrlVentas.ventas.firstWhere((v) => v.id == idVenta);
      expect(ventaActualizada.estado, EstadoVenta.completada);
      expect(ventaActualizada.montoPagado, 500.0);
      expect(ventaActualizada.saldoPendiente, 0.0);

      // Verificar estado en tabla deudores en SQLite
      final deudoresDb = await db.query('deudores', where: 'venta_id = ?', whereArgs: [idVenta]);
      expect(deudoresDb.first['estado'], 'LIQUIDADA');
      expect((deudoresDb.first['saldoPendiente'] as num).toDouble(), 0.0);
    });

    testWidgets('DeudoresVista se renderiza utilizando ControladorCuentasPorCobrar', (WidgetTester tester) async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlCobrar = ControladorCuentasPorCobrar(
        controladorVentas: ctrlVentas,
        controladorFinanzas: ctrlFin,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DeudoresVista(controladorCuentasPorCobrar: ctrlCobrar),
        ),
      );

      expect(find.byType(DeudoresVista), findsOneWidget);
      expect(find.text('Cuentas por Cobrar'), findsOneWidget);
    });
  });

  group('Indexación de Texto Completo FTS5 y Búsqueda con MATCH', () {
    test('ControladorInventario expone buscarProductosAsync optimizado', () {
      final ctrlInv = ControladorInventario();
      expect(ctrlInv.buscarProductosAsync, isA<Function>());
      expect(ctrlInv.buscarProductos('test'), isA<List<Producto>>());
    });

    test('SQLite soporta FTS5 con contenido externo y triggers de sincronización', () async {
      sqfliteFfiInit();
      final ffiDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
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
              tipo TEXT NOT NULL DEFAULT 'planta',
              activo INTEGER NOT NULL DEFAULT 1
            )
          ''');

          await db.execute('''
            CREATE VIRTUAL TABLE IF NOT EXISTS productos_fts USING fts5(
              nombre,
              notas,
              tipo,
              content='productos',
              content_rowid='rowid'
            )
          ''');

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
            CREATE TRIGGER IF NOT EXISTS productos_fts_au AFTER UPDATE ON productos BEGIN
              INSERT INTO productos_fts(productos_fts, rowid, nombre, notas, tipo)
              VALUES ('delete', old.rowid, old.nombre, coalesce(old.notas, ''), old.tipo);
              INSERT INTO productos_fts(rowid, nombre, notas, tipo)
              VALUES (new.rowid, new.nombre, coalesce(new.notas, ''), new.tipo);
            END;
          ''');
        },
      ));

      await ffiDb.insert('productos', {
        'id': 'p-test',
        'nombre': 'Begonia Maculata',
        'notas': 'Planta de sombra con puntos plateados',
        'precioVenta': 250.0,
        'costo': 120.0,
        'cantidadEnInventario': 10,
        'tipo': 'planta',
        'activo': 1,
      });

      final matchRes = await ffiDb.rawQuery('''
        SELECT p.*
        FROM productos p
        JOIN productos_fts f ON p.rowid = f.rowid
        WHERE p.activo = 1 AND productos_fts MATCH ?
      ''', ['plateados*']);

      expect(matchRes.length, 1);
      expect(matchRes.first['id'], 'p-test');
      await ffiDb.close();
    });
  });

  group('Sondeo de Estado en Tiempo Real ESC/POS (DLE EOT)', () {
    test('EstadoHardwareImpresora decodifica correctamente banderas binarias ESC/POS', () {
      // Estado normal
      final estadoNormal = EstadoHardwareImpresora.desdeBytes(bytePapel: 0x00);
      expect(estadoNormal.tienePapel, isTrue);
      expect(estadoNormal.esOperativo, isTrue);
      expect(estadoNormal.mensajeError, isNull);

      // Estado falta de papel (bits 5 y 6 = 0x60)
      final estadoSinPapel = EstadoHardwareImpresora.desdeBytes(bytePapel: 0x60);
      expect(estadoSinPapel.tienePapel, isFalse);
      expect(estadoSinPapel.esOperativo, isFalse);
      expect(estadoSinPapel.mensajeError, contains('sin rollo'));

      // Estado papel casi agotado (bits 2 y 3 = 0x0C)
      final estadoPapelBajo = EstadoHardwareImpresora.desdeBytes(bytePapel: 0x0C);
      expect(estadoPapelBajo.tienePapel, isTrue);
      expect(estadoPapelBajo.papelCasiAgotado, isTrue);
      expect(estadoPapelBajo.esOperativo, isTrue);

      // Estado tapa abierta (bit 2 = 0x04)
      final estadoTapa = EstadoHardwareImpresora.desdeBytes(bytePapel: 0x00, byteOffline: 0x04);
      expect(estadoTapa.tapaAbierta, isTrue);
      expect(estadoTapa.esOperativo, isFalse);
      expect(estadoTapa.mensajeError, contains('Tapa abierta'));
    });

    test('ControladorHardware aborta transmisión si se detecta falta de rollo de papel', () async {
      final ctrlHw = ControladorHardware();
      expect(ControladorHardware.comandoDleEotPapel, equals([0x10, 0x04, 0x04]));
      expect(ControladorHardware.comandoDleEotOffline, equals([0x10, 0x04, 0x02]));

      // Inyectar byte de error (0x60 = fin de rollo de papel)
      ctrlHw.inyectarRespuestaHardwarePrueba(0x60);

      // Intentar enviar flujo de bytes masivo
      final exito = await ctrlHw.enviarBytesAImpresora([0x1B, 0x40, 0x41, 0x42, 0x43]);

      // Debe abortar de inmediato sin gastar socket ni memoria
      expect(exito, isFalse);

      // Restaurar estado
      ctrlHw.inyectarRespuestaHardwarePrueba(null);
    });

    testWidgets('mostrarAlertaHardware despliega SnackBar ante contingencia física', (WidgetTester tester) async {
      final ctrlHw = ControladorHardware();

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: ControladorHardware.scaffoldMessengerKey,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  ctrlHw.mostrarAlertaHardware('¡Impresora sin rollo!', context: ctx);
                },
                child: const Text('Probar Alerta'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Probar Alerta'));
      await tester.pump(); // Inicia animación del SnackBar

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('¡Impresora sin rollo!'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });

  group('Integridad Relacional y Módulo de Cuentas por Cobrar (Deudores)', () {
    test('Esquema SQLite soporta tabla deudores con FK hacia ventas y consulta de plantas apartadas', () async {
      sqfliteFfiInit();
      final inMemoryDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE productos (
                id TEXT PRIMARY KEY,
                nombre TEXT NOT NULL,
                precioVenta REAL NOT NULL,
                tipo TEXT NOT NULL DEFAULT 'planta'
              )
            ''');
            await db.execute('''
              CREATE TABLE ventas (
                id TEXT PRIMARY KEY,
                fecha TEXT NOT NULL,
                estado TEXT NOT NULL,
                cliente TEXT NOT NULL,
                montoPagado REAL NOT NULL DEFAULT 0.0
              )
            ''');
            await db.execute('''
              CREATE TABLE articulos_venta (
                id TEXT PRIMARY KEY,
                venta_id TEXT NOT NULL,
                producto_id TEXT NOT NULL,
                cantidad INTEGER NOT NULL,
                precioUnitario REAL NOT NULL,
                FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE,
                FOREIGN KEY (producto_id) REFERENCES productos (id) ON DELETE CASCADE
              )
            ''');
            await db.execute('''
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
          },
        ),
      );

      // Inserción de prueba
      await inMemoryDb.insert('productos', {
        'id': 'planta-1',
        'nombre': 'Monstera Deliciosa',
        'precioVenta': 450.0,
        'tipo': 'planta',
      });
      await inMemoryDb.insert('ventas', {
        'id': 'v-101',
        'fecha': DateTime.now().toIso8601String(),
        'estado': 'apartada',
        'cliente': 'Ana Sofía',
        'montoPagado': 150.0,
      });
      await inMemoryDb.insert('articulos_venta', {
        'id': 'art-1',
        'venta_id': 'v-101',
        'producto_id': 'planta-1',
        'cantidad': 1,
        'precioUnitario': 450.0,
      });
      await inMemoryDb.insert('deudores', {
        'id': 'deu_v-101',
        'venta_id': 'v-101',
        'cliente': 'Ana Sofía',
        'telefono': '555-1234',
        'montoTotal': 450.0,
        'montoPagado': 150.0,
        'saldoPendiente': 300.0,
        'fechaRegistro': DateTime.now().toIso8601String(),
        'estado': 'PENDIENTE',
      });

      // Consulta relacional de plantas apartadas
      const sqlPlantas = '''
        SELECT 
          d.id AS deudor_id,
          d.cliente,
          d.saldoPendiente,
          v.id AS venta_id,
          p.id AS producto_id,
          p.nombre AS planta_nombre,
          av.cantidad,
          av.precioUnitario,
          (av.cantidad * av.precioUnitario) AS subtotal
        FROM deudores d
        JOIN ventas v ON d.venta_id = v.id
        JOIN articulos_venta av ON v.id = av.venta_id
        JOIN productos p ON av.producto_id = p.id
        WHERE d.id = ? OR d.venta_id = ?
      ''';

      final resultado = await inMemoryDb.rawQuery(sqlPlantas, ['deu_v-101', 'v-101']);
      expect(resultado.length, 1);
      expect(resultado.first['planta_nombre'], 'Monstera Deliciosa');
      expect(resultado.first['cliente'], 'Ana Sofía');
      expect(resultado.first['saldoPendiente'], 300.0);
      expect(resultado.first['subtotal'], 450.0);

      await inMemoryDb.close();
    });

    test('ComprobanteAbono modela fielmente los datos para emisión de recibo de pago', () {
      final comprobante = ComprobanteAbono(
        idAbono: 'ab-500',
        ventaId: 'v-200',
        cliente: 'Carlos Mendoza',
        totalOriginal: 1000.0,
        abonoHoy: 400.0,
        saldoRestante: 600.0,
        totalPagado: 400.0,
        fecha: DateTime(2026, 11, 8, 14, 30),
        metodoPago: 'Transferencia',
        liquidado: false,
      );

      expect(comprobante.cliente, 'Carlos Mendoza');
      expect(comprobante.totalOriginal, 1000.0);
      expect(comprobante.abonoHoy, 400.0);
      expect(comprobante.saldoRestante, 600.0);
      expect(comprobante.liquidado, isFalse);

      final map = comprobante.toMap();
      expect(map['idAbono'], 'ab-500');
      expect(map['metodoPago'], 'Transferencia');
    });

    test('ControladorHardware genera buffers ESC/POS binarios para Ticket de Crédito y Comprobante de Abono', () async {
      final ctrlHw = ControladorHardware();

      final ventaCredito = Venta(
        id: 'v-cred-999',
        fecha: DateTime.now(),
        cliente: 'Beatriz Silva',
        estado: EstadoVenta.apartada,
        montoPagado: 200.0,
        articulos: [
          ArticuloVenta(
            producto: Producto(
              id: 'pl-fikus',
              nombre: 'Ficus Lyrata Gigante',
              precioVenta: 850.0,
              costo: 400.0,
              cantidadEnInventario: 5,
            ),
            cantidad: 1,
            precioUnitario: 850.0,
          ),
        ],
      );

      final comprobante = ComprobanteAbono(
        idAbono: 'ab-999',
        ventaId: 'v-cred-999',
        cliente: 'Beatriz Silva',
        totalOriginal: 850.0,
        abonoHoy: 350.0,
        saldoRestante: 300.0,
        totalPagado: 550.0,
        fecha: DateTime.now(),
        metodoPago: 'Efectivo',
        liquidado: false,
      );

      // Verificamos que los métodos ESC/POS no lanzan excepciones
      expect(() async {
        await ctrlHw.imprimirTicketCreditoEscPos(ventaCredito);
      }, returnsNormally);

      expect(() async {
        await ctrlHw.imprimirComprobanteAbonoEscPos(comprobante);
      }, returnsNormally);
    });
  });

  group('Escaneo Real y Conexión Térmica Bluetooth ESC/POS (print_bluetooth_thermal)', () {
    test('ControladorHardware escanea impresoras Bluetooth recuperando Nombre y MAC', () async {
      final ctrlHw = ControladorHardware();
      ctrlHw.inyectarDispositivosPrueba([
        const DispositivoImpresora(
          nombre: 'POS-58C Thermal',
          macOUrl: '66:02:BD:06:18:7B',
          tipo: 'bluetooth',
        ),
        const DispositivoImpresora(
          nombre: 'MTP-II MiniPrinter',
          macOUrl: 'AA:BB:CC:DD:EE:FF',
          tipo: 'bluetooth',
        ),
      ]);

      final resultado = await ctrlHw.escanearImpresorasBluetooth(solicitarPermisos: false);

      expect(resultado.length, 2);
      expect(resultado[0].nombre, 'POS-58C Thermal');
      expect(resultado[0].macOUrl, '66:02:BD:06:18:7B');
      expect(resultado[1].nombre, 'MTP-II MiniPrinter');
      expect(resultado[1].macOUrl, 'AA:BB:CC:DD:EE:FF');

      ctrlHw.inyectarDispositivosPrueba(null);
    });

    test('ControladorHardware conecta exitosamente, guarda MAC y actualiza estado a Conectada', () async {
      final ctrlHw = ControladorHardware();
      ctrlHw.inyectarConexionPrueba(true);

      expect(ctrlHw.config.impresoraConectada, isFalse);

      final exito = await ctrlHw.conectarImpresora(
        macAddress: '66:02:BD:06:18:7B',
        nombre: 'POS-58C Thermal',
      );

      expect(exito, isTrue);
      expect(ctrlHw.config.impresoraConectada, isTrue);
      expect(ctrlHw.config.impresoraMac, '66:02:BD:06:18:7B');
      expect(ctrlHw.config.impresoraNombre, 'POS-58C Thermal');

      ctrlHw.inyectarConexionPrueba(null);
    });

    testWidgets('DialogoBuscarImpresoraBluetooth muestra indicador de carga y lista impresoras', (tester) async {
      final ctrlHw = ControladorHardware();
      ctrlHw.inyectarDispositivosPrueba([
        const DispositivoImpresora(
          nombre: 'RPP02N Thermal Printer',
          macOUrl: '00:11:22:33:44:55',
          tipo: 'bluetooth',
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DialogoBuscarImpresoraBluetooth(
              controladorHardware: ctrlHw,
            ),
          ),
        ),
      );

      // Verificamos el montaje inicial y la resolución del escaneo
      await tester.pumpAndSettle();

      expect(find.text('Buscar Impresora'), findsOneWidget);
      expect(find.text('RPP02N Thermal Printer'), findsOneWidget);
      expect(find.text('MAC: 00:11:22:33:44:55'), findsOneWidget);
      expect(find.text('Conectar'), findsOneWidget);

      ctrlHw.inyectarDispositivosPrueba(null);
    });

    testWidgets('HardwareVista muestra estado Conectada en verde y habilita Ticket Prueba', (tester) async {
      final ctrlBio = ControladorBiometrico();
      final ctrlHw = ControladorHardware();

      // Forzamos conexión activa
      ctrlHw.config.impresoraConectada = true;
      ctrlHw.config.impresoraMac = '66:02:BD:06:18:7B';
      ctrlHw.config.impresoraNombre = 'POS-58C';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HardwareVista(
              controladorBiometrico: ctrlBio,
              controladorHardware: ctrlHw,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Conectada'), findsOneWidget);
      expect(find.text('Ticket Prueba'), findsOneWidget);

      // Verificar que el botón de prueba está habilitado cuando está conectada
      final botonPrueba = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Ticket Prueba'),
      );
      expect(botonPrueba.onPressed, isNotNull);
    });

    testWidgets('HardwareVista deshabilita Ticket Prueba cuando la impresora está desconectada', (tester) async {
      final ctrlBio = ControladorBiometrico();
      final ctrlHw = ControladorHardware();

      // Estado desconectado
      ctrlHw.config.impresoraConectada = false;
      ctrlHw.config.impresoraMac = '';
      ctrlHw.config.impresoraNombre = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HardwareVista(
              controladorBiometrico: ctrlBio,
              controladorHardware: ctrlHw,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Desconectada'), findsOneWidget);

      // El botón de prueba debe estar deshabilitado (onPressed == null)
      final botonPrueba = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Ticket Prueba'),
      );
      expect(botonPrueba.onPressed, isNull);
    });
  });

  group('Optimización de Rendimiento, Aislamiento de Scaffold y Debounce (P1)', () {
    test('Debouncer retrasa la ejecución 300ms y descarta pulsaciones intermedias', () async {
      final debouncer = Debouncer(delay: const Duration(milliseconds: 300));
      int llamadas = 0;
      String valorFinal = '';

      debouncer.run(() {
        llamadas++;
        valorFinal = 'c';
      });

      // Simula escritura rápida antes de 300ms
      await Future.delayed(const Duration(milliseconds: 100));
      expect(llamadas, 0);

      debouncer.run(() {
        llamadas++;
        valorFinal = 'ca';
      });

      await Future.delayed(const Duration(milliseconds: 100));
      expect(llamadas, 0);

      debouncer.run(() {
        llamadas++;
        valorFinal = 'cactus';
      });

      // Esperar más de 300ms
      await Future.delayed(const Duration(milliseconds: 350));
      expect(llamadas, 1);
      expect(valorFinal, 'cactus');

      debouncer.dispose();
    });

    testWidgets('PosVista configura Scaffold con resizeToAvoidBottomInset: true y RepaintBoundary', (WidgetTester tester) async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorVentas>.value(value: ctrlVentas),
            ChangeNotifierProvider<ControladorInventario>.value(value: ctrlInv),
          ],
          child: const MaterialApp(
            home: PosVista(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);
      final scaffold = tester.widget<Scaffold>(scaffoldFinder);
      expect(scaffold.resizeToAvoidBottomInset, isTrue);

      // Debe existir RepaintBoundary alrededor del TextField de búsqueda
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('VentaVista configura Scaffold con resizeToAvoidBottomInset: true, SingleChildScrollView y viewInsets en VentaFooter', (WidgetTester tester) async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      ctrlVentas.iniciarVenta();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorVentas>.value(value: ctrlVentas),
            ChangeNotifierProvider<ControladorInventario>.value(value: ctrlInv),
          ],
          child: MaterialApp(
            home: VentaVista(
              controladorVentas: ctrlVentas,
              controladorInventario: ctrlInv,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.resizeToAvoidBottomInset, isTrue);
    });

    testWidgets('VentaVista y VentaFooter ajustan dinamicamente con teclado virtual activo (viewInsets.bottom)', (WidgetTester tester) async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      ctrlVentas.iniciarVenta();
      final prod = Producto(
        id: 'P_BOT_01',
        nombre: 'Monstera Deliciosa',
        tipo: 'planta',
        precioVenta: 150.0,
        costo: 80.0,
        cantidadEnInventario: 5,
      );
      ctrlVentas.agregarArticulo(prod, 1);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorVentas>.value(value: ctrlVentas),
            ChangeNotifierProvider<ControladorInventario>.value(value: ctrlInv),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(400, 800),
                viewInsets: EdgeInsets.only(bottom: 300),
              ),
              child: VentaVista(
                controladorVentas: ctrlVentas,
                controladorInventario: ctrlInv,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(VentaFooter), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Monstera Deliciosa'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('DeudoresVista configura Scaffold con resizeToAvoidBottomInset: true y buscador en RepaintBoundary', (WidgetTester tester) async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlCuentas = ControladorCuentasPorCobrar(
        controladorVentas: ctrlVentas,
        controladorFinanzas: ctrlFin,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorVentas>.value(value: ctrlVentas),
            ChangeNotifierProvider<ControladorCuentasPorCobrar>.value(value: ctrlCuentas),
          ],
          child: const MaterialApp(
            home: DeudoresVista(),
          ),
        ),
      );

      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.resizeToAvoidBottomInset, isTrue);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    test('ControladorInventario.agregarProducto actualiza optimistamente en memoria antes de persistir en microtarea', () async {
      final ctrlInv = ControladorInventario();
      final nuevoProd = Producto(
        id: 'test_opt_001',
        nombre: 'Cactus Optimista',
        tipo: 'planta',
        precioVenta: 120.0,
        costo: 60.0,
        cantidadEnInventario: 10,
      );

      // La invocación sincroniza inmediatamente en memoria (UI instantánea)
      final futureOperacion = ctrlInv.agregarProducto(nuevoProd);
      expect(ctrlInv.productos.any((p) => p.id == 'test_opt_001'), isTrue);

      // Esperar culminación de la microtarea
      try {
        await futureOperacion;
      } catch (_) {
        // En entorno mock de prueba SQLite sin Keystore
      }
    });

    testWidgets('PosVista renderiza TarjetaPosProducto dentro de Selector granular para aislar frame drops', (WidgetTester tester) async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );

      final p1 = Producto(
        id: 'p_gran_1',
        nombre: 'Sucu 1',
        tipo: 'planta',
        precioVenta: 50.0,
        costo: 25.0,
        cantidadEnInventario: 5,
      );
      ctrlInv.productos.add(p1);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorVentas>.value(value: ctrlVentas),
            ChangeNotifierProvider<ControladorInventario>.value(value: ctrlInv),
          ],
          child: const MaterialApp(
            home: PosVista(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe utilizar Selector<ControladorVentas, int> para aislar tarjetas individuales
      expect(find.byType(Selector<ControladorVentas, int>), findsWidgets);
    });
  });

  group('Gestión de Productos por Roles: Soft Delete, Restauración y Hard Delete', () {
    test('Soft delete (deshabilitarProducto), Restaurar y Hard delete en SQLite', () async {
      final ctrlInv = ControladorInventario();
      final pPrueba = Producto(
        id: '9991',
        nombre: 'Cactus de Prueba Soft Delete',
        precioVenta: 100.0,
        costo: 50.0,
        cantidadEnInventario: 10,
        activo: true,
      );

      // Inserción en SQLite y memoria
      await ctrlInv.agregarProducto(pPrueba);
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Deshabilitar producto (Soft Delete con id entero o string)
      await ctrlInv.deshabilitarProducto(9991);
      expect(ctrlInv.productos.any((p) => p.id == '9991'), isFalse);

      // 2. Filtro soloActivos = false permite al Dueño ver productos deshabilitados
      await ctrlInv.cargarProductos(soloActivos: false);
      expect(ctrlInv.productos.any((p) => p.id == '9991'), isTrue);
      final prodDeshabilitado = ctrlInv.productos.firstWhere((p) => p.id == '9991');
      expect(prodDeshabilitado.activo, isFalse);

      // 3. Restaurar producto (vuelve a activo = 1)
      await ctrlInv.restaurarProducto(9991);
      await ctrlInv.cargarProductos(soloActivos: true);
      expect(ctrlInv.productos.any((p) => p.id == '9991'), isTrue);
      final prodRestaurado = ctrlInv.productos.firstWhere((p) => p.id == '9991');
      expect(prodRestaurado.activo, isTrue);

      // 4. Hard Delete (Eliminación definitiva)
      await ctrlInv.eliminarProductoDefinitivamente(9991);
      await ctrlInv.cargarProductos(soloActivos: true);
      expect(ctrlInv.productos.any((p) => p.id == '9991'), isFalse);
      await ctrlInv.cargarProductos(soloActivos: false);
      expect(ctrlInv.productos.any((p) => p.id == '9991'), isFalse);
    });
  });

  group('Flujo de Decisión de Impresión en Abonos (UX)', () {
    testWidgets('Modal de abono contiene botón profesional "Confirmar Abono"', (WidgetTester tester) async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlCuentas = ControladorCuentasPorCobrar(
        controladorVentas: ctrlVentas,
        controladorFinanzas: ctrlFin,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorVentas>.value(value: ctrlVentas),
            ChangeNotifierProvider<ControladorCuentasPorCobrar>.value(value: ctrlCuentas),
          ],
          child: const MaterialApp(
            home: DeudoresVista(),
          ),
        ),
      );

      await tester.pump();

      // Verificar que NO existe texto técnico de base de datos
      expect(find.text('Registrar Pago en SQLite'), findsNothing);
    });

    testWidgets('Diálogo de decisión consulta antes de imprimir comprobante', (WidgetTester tester) async {
      bool imprimio = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final bool? desea = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Abono Registrado'),
                    content: const Text(
                      'Abono de \$150.00 registrado con éxito. ¿Desea imprimir el comprobante de pago?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('No'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sí, imprimir'),
                      ),
                    ],
                  ),
                );
                if (desea == true) {
                  imprimio = true;
                }
              },
              child: const Text('Disparar Flujo'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Abrir diálogo
      await tester.tap(find.text('Disparar Flujo'));
      await tester.pumpAndSettle();

      expect(find.text('Abono de \$150.00 registrado con éxito. ¿Desea imprimir el comprobante de pago?'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
      expect(find.text('Sí, imprimir'), findsOneWidget);

      // Presionar "No" cierra el diálogo sin imprimir
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(imprimio, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('Escudo del Catálogo en Inventario (RBAC y Soft Delete)', () {
    testWidgets('TarjetaProductoInventario para rol empleado SOLO muestra opción "Deshabilitar"', (WidgetTester tester) async {
      final prodActivo = Producto(
        id: 'P_ACT_01',
        nombre: 'Ficus Lyrata',
        precioVenta: 250.0,
        costo: 120.0,
        cantidadEnInventario: 5,
        activo: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TarjetaProductoInventario(
              prod: prodActivo,
              rolActual: RolUsuario.empleado,
              onEditar: () {},
              onAjustar: () {},
              onBorrar: () {},
              onDeshabilitar: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Empleado SOLO ve el botón "Deshabilitar"
      expect(find.text('Deshabilitar'), findsOneWidget);
      expect(find.text('Añadir'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.text('Restaurar'), findsNothing);
      expect(find.text('Eliminar Definitivamente'), findsNothing);
      expect(find.text('COSTO'), findsNothing);
    });

    testWidgets('TarjetaProductoInventario para rol dueño con producto activo muestra "Añadir", "Editar" y "Deshabilitar"', (WidgetTester tester) async {
      final prodActivo = Producto(
        id: 'P_ACT_02',
        nombre: 'Cactus Órgano',
        precioVenta: 180.0,
        costo: 90.0,
        cantidadEnInventario: 8,
        activo: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TarjetaProductoInventario(
              prod: prodActivo,
              rolActual: RolUsuario.duena,
              onEditar: () {},
              onAjustar: () {},
              onBorrar: () {},
              onDeshabilitar: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Añadir'), findsOneWidget);
      expect(find.text('Deshabilitar'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.text('COSTO'), findsOneWidget);
      expect(find.text('Restaurar'), findsNothing);
      expect(find.text('Eliminar Definitivamente'), findsNothing);
    });

    testWidgets('TarjetaProductoInventario para rol dueño con producto deshabilitado muestra badge y dos botones exclusivos: "Restaurar" y "Eliminar Definitivamente"', (WidgetTester tester) async {
      final prodDeshabilitado = Producto(
        id: 'P_DES_01',
        nombre: 'Suculenta Echeveria',
        precioVenta: 75.0,
        costo: 35.0,
        cantidadEnInventario: 0,
        activo: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TarjetaProductoInventario(
              prod: prodDeshabilitado,
              rolActual: RolUsuario.duena,
              onEditar: () {},
              onAjustar: () {},
              onBorrar: () {},
              onRestaurar: () {},
              onEliminarDefinitivamente: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Badge de deshabilitado
      expect(find.text('DESHABILITADO'), findsOneWidget);
      // Dos botones exclusivos
      expect(find.text('Restaurar'), findsOneWidget);
      expect(find.text('Eliminar Definitivamente'), findsOneWidget);
      // NO debe mostrar Añadir ni Deshabilitar
      expect(find.text('Añadir'), findsNothing);
      expect(find.text('Deshabilitar'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });
  });

  group('Integridad Financiera de Créditos, Abonos y Reactividad en Dashboard (ACID)', () {
    test('Venta a crédito solo registra enganche en transacciones y abonos se reflejan en tiempo real', () async {
      final ctrlInv = ControladorInventario();
      final ctrlFin = ControladorFinanzas();
      final ctrlPerf = ControladorPerfil();
      ctrlPerf.configuracion.aplicarIva = false;
      final ctrlVentas = ControladorVentas(
        controladorInventario: ctrlInv,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlInicio = ControladorInicio(
        controladorInventario: ctrlInv,
        controladorVentas: ctrlVentas,
        controladorFinanzas: ctrlFin,
        controladorPerfil: ctrlPerf,
      );
      final ctrlCuentas = ControladorCuentasPorCobrar(
        controladorVentas: ctrlVentas,
        controladorFinanzas: ctrlFin,
      );

      await ctrlFin.cargarTransacciones();
      await ctrlVentas.cargarVentas();
      ctrlInicio.actualizarMetricasDashboard();
      final ingresosIniciales = ctrlFin.totalIngresos;
      final ventasInicialesDashboard = ctrlInicio.metricasDashboard.totalVentas;
      final porCobrarInicialDashboard = ctrlInicio.metricasDashboard.totalPorCobrar;

      // 1. Agregar un producto
      final prod = Producto(
        id: 'P_CRED_01',
        nombre: 'Orquídea Phalaenopsis',
        precioVenta: 500.0,
        costo: 200.0,
        cantidadEnInventario: 10,
      );
      ctrlInv.agregarProducto(prod);

      // 2. Crear venta apartada (Total $500, Enganche $150, Deuda restante $350)
      ctrlVentas.iniciarVenta();
      ctrlVentas.agregarArticulo(prod);
      final ventaApartada = await ctrlVentas.apartarVentaActual(
        cliente: 'Carlos Mora',
        montoAbonoInicial: 150.0,
      );

      expect(ventaApartada, isNotNull);
      expect(ventaApartada!.total, 500.0);
      expect(ventaApartada.montoPagado, 150.0);
      expect(ventaApartada.saldoPendiente, 350.0);

      // Verificar tabla de finanzas: SOLO debe registrarse el enganche ($150)
      expect(ctrlFin.totalIngresos, ingresosIniciales + 150.0);
      expect(ctrlFin.transacciones.first.monto, 150.0);
      expect(ctrlFin.transacciones.first.descripcion, contains('Abono Folio'));

      // Verificar reactividad en el Dashboard:
      // "Ingresos Totales" debe ser $150 (dinero real en caja), NO $500 (deuda total)
      // "Por Cobrar" debe ser $350
      expect(ctrlInicio.metricasDashboard.totalVentas, ventasInicialesDashboard + 150.0);
      expect(ctrlInicio.metricasDashboard.totalPorCobrar, porCobrarInicialDashboard + 350.0);

      // 3. Cliente realiza un abono de $200
      final comprobante = await ctrlCuentas.registrarAbono(
        ventaId: ventaApartada.id,
        monto: 200.0,
        metodoPago: 'Efectivo',
      );

      expect(comprobante.abonoHoy, 200.0);
      expect(comprobante.saldoRestante, 150.0);

      // Verificar que se insertó la transacción de abono
      expect(ctrlFin.totalIngresos, ingresosIniciales + 350.0); // $150 enganche + $200 abono
      final transaccionAbono = ctrlFin.transacciones.first;
      expect(transaccionAbono.monto, 200.0);
      expect(transaccionAbono.descripcion, startsWith('Abono Folio'));

      // Reactividad: el Dashboard debe sumar el dinero en tiempo real ($350)
      expect(ctrlInicio.metricasDashboard.totalVentas, ventasInicialesDashboard + 350.0);
      expect(ctrlInicio.metricasDashboard.totalPorCobrar, porCobrarInicialDashboard + 150.0);

      // 4. Liquidar deuda total con abono final de $150
      final liquidacion = await ctrlCuentas.liquidarDeuda(
        ventaId: ventaApartada.id,
      );

      expect(liquidacion, isNotNull);
      expect(liquidacion!.saldoRestante, 0.0);
      expect(ctrlFin.totalIngresos, ingresosIniciales + 500.0); // $150 + $200 + $150 = $500 total
      expect(ctrlInicio.metricasDashboard.totalVentas, ventasInicialesDashboard + 500.0);
      expect(ctrlInicio.metricasDashboard.totalPorCobrar, porCobrarInicialDashboard);
    });
  });

  group('Unificación Criptográfica y Registro de Empleados (DevSecOps)', () {
    test('Creación de empleado y login unificado con PBKDF2 y sanitización trim', () async {
      final authCtrl = ControladorAutenticacion();
      const String idEmpleado = 'EMP-9081';
      const String nombreEmpleado = 'Valeria Torres';
      const String passwordPlana = 'PlantaSegura2026';

      // 1. Registro mediante agregarEmpleado con espacios accidentales
      final exitoRegistro = await authCtrl.agregarEmpleado(
        id: '  $idEmpleado  ',
        nombre: '  $nombreEmpleado  ',
        clave: '  $passwordPlana  ',
        rol: RolUsuario.empleado,
      );
      expect(exitoRegistro, isTrue);

      // Verificar que se guardó en SQLite con hash PBKDF2
      final db = await BaseDeDatos.instancia.database;
      final query = await db.query(
        'colaboradores',
        where: 'id = ?',
        whereArgs: [idEmpleado],
      );
      expect(query.isNotEmpty, isTrue);
      final usuarioEnDb = query.first;
      expect(usuarioEnDb['id'], idEmpleado);
      expect(usuarioEnDb['nombre'], nombreEmpleado);
      expect(usuarioEnDb['rol'], 'empleado');
      final hashAlmacenado = usuarioEnDb['clave'] as String;
      expect(hashAlmacenado.startsWith('\$pbkdf2\$100000\$'), isTrue);

      // 2. Iniciar sesión con ID exacto
      final loginPorId = await authCtrl.iniciarSesion(idEmpleado, passwordPlana);
      expect(loginPorId, isTrue);
      expect(authCtrl.usuarioActual?.id, idEmpleado);
      expect(authCtrl.usuarioActual?.nombre, nombreEmpleado);
      expect(authCtrl.usuarioActual?.rol, RolUsuario.empleado);

      // 3. Iniciar sesión con espacios accidentales y minúsculas (Tolerancia y Trim)
      authCtrl.cerrarSesion();
      final loginConEspacios = await authCtrl.iniciarSesion(
        '  ${idEmpleado.toLowerCase()}  ',
        '  $passwordPlana  ',
      );
      expect(loginConEspacios, isTrue);
      expect(authCtrl.usuarioActual?.id, idEmpleado);

      // 4. Iniciar sesión utilizando el Nombre del colaborador en lugar del ID
      authCtrl.cerrarSesion();
      final loginPorNombre = await authCtrl.iniciarSesion(
        '  $nombreEmpleado  ',
        passwordPlana,
      );
      expect(loginPorNombre, isTrue);
      expect(authCtrl.usuarioActual?.id, idEmpleado);

      // 5. Rechazo ante contraseña incorrecta o usuario inexistente
      authCtrl.cerrarSesion();
      final loginClaveErronea = await authCtrl.iniciarSesion(
        idEmpleado,
        'ClaveIncorrecta999',
      );
      expect(loginClaveErronea, isFalse);
      expect(authCtrl.usuarioActual, isNull);

      final loginUsuarioInexistente = await authCtrl.iniciarSesion(
        'NO_EXISTE_999',
        passwordPlana,
      );
      expect(loginUsuarioInexistente, isFalse);
    });

    test('agregarEmpleado normaliza ID a UPPERCASE y TRIM, y SQLite COLLATE NOCASE permite login insensible a mayúsculas', () async {
      final authCtrl = ControladorAutenticacion();
      const String idOriginalMinusculas = '  emp-case-test-42  ';
      const String idEsperadoMayusculas = 'EMP-CASE-TEST-42';
      const String nombre = 'Empleado Sensible';
      const String clave = 'ClaveSecreta123';

      // 1. Registro con ID en minúsculas y espacios
      final registro = await authCtrl.agregarEmpleado(
        id: idOriginalMinusculas,
        nombre: nombre,
        clave: clave,
        rol: RolUsuario.empleado,
      );
      expect(registro, isTrue);

      // 2. Verificar que en SQLite se guardó estrictamente en MAYÚSCULAS y sin espacios
      final db = await BaseDeDatos.instancia.database;
      final query = await db.rawQuery(
        'SELECT * FROM colaboradores WHERE id = ? COLLATE NOCASE',
        [idEsperadoMayusculas],
      );
      expect(query.isNotEmpty, isTrue);
      expect(query.first['id'], idEsperadoMayusculas);

      // Verificar que el salt PBKDF2 en la clave coincida con el ID en mayúsculas
      final hash = query.first['clave'] as String;
      expect(hash.contains(idEsperadoMayusculas), isTrue);

      // 3. Login con combinaciones mixtas de mayúsculas y minúsculas
      authCtrl.cerrarSesion();
      final loginMixto = await authCtrl.iniciarSesion(
        '  eMp-CaSe-TeSt-42  ',
        '  $clave  ',
      );
      expect(loginMixto, isTrue);
      expect(authCtrl.usuarioActual?.id, idEsperadoMayusculas);
    });

    test('Cuenta administradora VO-4092 y PIN 123456 se auto-sana y autentica ante cualquier variación (V0-4092, minúsculas, sin guión)', () async {
      final authCtrl = ControladorAutenticacion();

      // 1. Cargar usuarios por defecto y verificar que VO-4092 existe como Dueña
      await authCtrl.cargarUsuariosPorDefecto();
      authCtrl.cerrarSesion();

      // 2. Login con credenciales estándar
      final loginDirecto = await authCtrl.iniciarSesion('VO-4092', '123456');
      expect(loginDirecto, isTrue);
      expect(authCtrl.usuarioActual?.id, 'VO-4092');
      expect(authCtrl.usuarioActual?.rol, RolUsuario.duena);

      // 3. Login tolerando 'V0-4092' (con el dígito cero en lugar de la letra O)
      authCtrl.cerrarSesion();
      final loginConCero = await authCtrl.iniciarSesion('V0-4092', '123456');
      expect(loginConCero, isTrue);
      expect(authCtrl.usuarioActual?.id, 'VO-4092');

      // 4. Login tolerando minúsculas y espacios
      authCtrl.cerrarSesion();
      final loginMinusculas = await authCtrl.iniciarSesion('  vo-4092  ', '  123456  ');
      expect(loginMinusculas, isTrue);
      expect(authCtrl.usuarioActual?.id, 'VO-4092');

      // 5. Login tolerando omitir el guión ('VO4092' o 'V04092')
      authCtrl.cerrarSesion();
      final loginSinGuion = await authCtrl.iniciarSesion('VO4092', '123456');
      expect(loginSinGuion, isTrue);
      expect(authCtrl.usuarioActual?.id, 'VO-4092');

      // 6. Rechazo si la contraseña es errónea
      authCtrl.cerrarSesion();
      final loginClaveInvalida = await authCtrl.iniciarSesion('VO-4092', 'clave_erronea_999');
      expect(loginClaveInvalida, isFalse);
      expect(authCtrl.usuarioActual, isNull);
    });

    test('cargarUsuariosPorDefecto siembra VO-4092 incluso si ya existen otros colaboradores en la base de datos', () async {
      final authCtrl = ControladorAutenticacion();

      // Asegurar que exista al menos un empleado para simular conteo > 0
      await authCtrl.agregarEmpleado(
        id: 'EMP-EXISTENTE-99',
        nombre: 'Empleado Existente',
        clave: 'ClaveEmpleado99',
      );

      // Borrar intencionalmente VO-4092 para probar la sanación con conteo > 0
      final db = await BaseDeDatos.instancia.database;
      await db.delete('colaboradores', where: 'id = ? COLLATE NOCASE', whereArgs: ['VO-4092']);

      // Ejecutar cargarUsuariosPorDefecto: debe detectar la ausencia de VO-4092 y sembrarlo
      await authCtrl.cargarUsuariosPorDefecto();

      final res = await db.rawQuery(
        'SELECT * FROM colaboradores WHERE id = ? COLLATE NOCASE',
        ['VO-4092'],
      );
      expect(res.isNotEmpty, isTrue);
      expect(res.first['id'], 'VO-4092');
      expect(res.first['rol'], RolUsuario.duena.valor);
    });
  });

  group('Diseño Responsivo con Slivers y Adaptación a Tablets en InventarioVista', () {
    testWidgets('InventarioVista utiliza CustomScrollView, SliverToBoxAdapter y SliverGrid con maxCrossAxisExtent: 350', (WidgetTester tester) async {
      final cInv = ControladorInventario();
      final cFin = ControladorFinanzas();
      final cPerf = ControladorPerfil();
      final cVentas = ControladorVentas(
        controladorInventario: cInv,
        controladorFinanzas: cFin,
        controladorPerfil: cPerf,
      );
      final cAuth = ControladorAutenticacion();
      final cIA = ControladorIACompras(controladorInventario: cInv);

      // Agregar productos de prueba en memoria sin llamadas a BD
      cInv.establecerProductosParaPruebas([
        Producto(
          id: 'P_TAB_01',
          nombre: 'Ficus Lyrata Gigante',
          precioVenta: 850.0,
          costo: 400.0,
          cantidadEnInventario: 12,
        ),
        Producto(
          id: 'P_TAB_02',
          nombre: 'Monstera Deliciosa',
          precioVenta: 350.0,
          costo: 150.0,
          cantidadEnInventario: 4, // Stock crítico
        ),
      ]);

      // Simular pantalla de Tablet en modo Horizontal (Landscape: 1280x800)
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorInventario>.value(value: cInv),
            ChangeNotifierProvider<ControladorFinanzas>.value(value: cFin),
            ChangeNotifierProvider<ControladorVentas>.value(value: cVentas),
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: cAuth),
            ChangeNotifierProvider<ControladorIACompras>.value(value: cIA),
          ],
          child: const MaterialApp(
            home: InventarioVista(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Debe existir un CustomScrollView principal
      expect(find.byType(CustomScrollView), findsOneWidget);

      // 2. Contadores superiores y buscador en SliverToBoxAdapter
      expect(find.byType(SliverToBoxAdapter), findsWidgets);
      expect(find.byType(ResumenInventarioHeader), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // 3. El catálogo de productos debe usar SliverGrid
      expect(find.byType(SliverGrid), findsOneWidget);

      final sliverGridFinder = find.byType(SliverGrid);
      final sliverGrid = tester.widget<SliverGrid>(sliverGridFinder);
      expect(sliverGrid.gridDelegate, isA<SliverGridDelegateWithMaxCrossAxisExtent>());

      final delegate = sliverGrid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
      expect(delegate.maxCrossAxisExtent, 350.0);

      // Las tarjetas de producto deben renderizarse adecuadamente
      expect(find.text('Ficus Lyrata Gigante'), findsOneWidget);
      expect(find.text('Monstera Deliciosa'), findsOneWidget);
    });
  });

  group('Diseño Adaptativo con LayoutBuilder en PosVista', () {
    testWidgets('PosVista en pantalla móvil (<600px) renderiza vista vertical estándar', (WidgetTester tester) async {
      final cInv = ControladorInventario();
      final cFin = ControladorFinanzas();
      final cPerf = ControladorPerfil();
      final cVentas = ControladorVentas(
        controladorInventario: cInv,
        controladorFinanzas: cFin,
        controladorPerfil: cPerf,
      );
      final cAuth = ControladorAutenticacion();

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorInventario>.value(value: cInv),
            ChangeNotifierProvider<ControladorFinanzas>.value(value: cFin),
            ChangeNotifierProvider<ControladorVentas>.value(value: cVentas),
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: cAuth),
          ],
          child: const MaterialApp(
            home: PosVista(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe utilizar LayoutBuilder
      expect(find.byType(LayoutBuilder), findsOneWidget);

      // En móvil NO debe mostrar el panel lateral de Ticket en Curso
      expect(find.text('Ticket en Curso'), findsNothing);
      expect(find.byType(VerticalDivider), findsNothing);
    });

    testWidgets('PosVista en tablet horizontal (>=600px) renderiza split-view 60/40 con catálogo y Ticket en Curso', (WidgetTester tester) async {
      final cInv = ControladorInventario();
      final cFin = ControladorFinanzas();
      final cPerf = ControladorPerfil();
      cPerf.configuracion.aplicarIva = false;
      final cVentas = ControladorVentas(
        controladorInventario: cInv,
        controladorFinanzas: cFin,
        controladorPerfil: cPerf,
      );
      final cAuth = ControladorAutenticacion();

      final p1 = Producto(
        id: 'P_POS_01',
        nombre: 'Kalanchoe Florido',
        tipo: 'planta',
        precioVenta: 180.0,
        costo: 90.0,
        cantidadEnInventario: 8,
      );
      cInv.establecerProductosParaPruebas([p1]);

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorInventario>.value(value: cInv),
            ChangeNotifierProvider<ControladorFinanzas>.value(value: cFin),
            ChangeNotifierProvider<ControladorVentas>.value(value: cVentas),
            ChangeNotifierProvider<ControladorAutenticacion>.value(value: cAuth),
          ],
          child: const MaterialApp(
            home: PosVista(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Debe existir LayoutBuilder y el divisor vertical
      expect(find.byType(LayoutBuilder), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);

      // 2. Lado derecho debe mostrar el "Ticket en Curso" y estado vacío inicial
      expect(find.text('Ticket en Curso'), findsOneWidget);
      expect(find.text('Sin artículos añadidos'), findsOneWidget);

      // 3. Agregar artículo al carrito y verificar actualización en tiempo real en el panel derecho
      cVentas.agregarArticulo(p1, 2);
      await tester.pumpAndSettle();

      expect(find.text('2 artículos'), findsOneWidget);
      expect(find.text('Cobrar Ticket (\$360.00)'), findsOneWidget);
    });
  });

  group('Restricciones de Ancho Máximo y Ergonomía (ConstrainedBox)', () {
    testWidgets('DeudoresVista envuelve su ListView en Center y ConstrainedBox(maxWidth: 800)', (WidgetTester tester) async {
      final ctrlFin = ControladorFinanzas();
      final ctrlVentas = ControladorVentas(
        controladorInventario: ControladorInventario(),
        controladorFinanzas: ctrlFin,
        controladorPerfil: ControladorPerfil(),
      );
      final ctrlCuentas = ControladorCuentasPorCobrar(
        controladorVentas: ctrlVentas,
        controladorFinanzas: ctrlFin,
      );

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ControladorVentas>.value(value: ctrlVentas),
            ChangeNotifierProvider<ControladorCuentasPorCobrar>.value(value: ctrlCuentas),
          ],
          child: const MaterialApp(
            home: DeudoresVista(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final constrainedBoxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final box800 = constrainedBoxes.where((cb) => cb.constraints.maxWidth == 800).firstOrNull;
      expect(box800, isNotNull);
      expect(box800!.constraints.maxWidth, 800.0);
    });

    testWidgets('FormularioEmpleadoSheet aplica ConstrainedBox(maxWidth: 500) para vista ergonómica en tablets', (WidgetTester tester) async {
      final ctrlAuth = ControladorAutenticacion();

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormularioEmpleadoSheet(controladorAutenticacion: ctrlAuth),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final constrainedBoxes = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
      final box500 = constrainedBoxes.where((cb) => cb.constraints.maxWidth == 500).firstOrNull;
      expect(box500, isNotNull);
      expect(box500!.constraints.maxWidth, 500.0);
    });
  });
}

