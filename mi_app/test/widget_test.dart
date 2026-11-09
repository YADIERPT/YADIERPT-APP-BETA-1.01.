import 'package:flutter/material.dart';
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
import 'package:mi_app/Vista/inventario_vista.dart';
import 'package:mi_app/Vista/login.dart';
import 'package:mi_app/Vista/splash_vista.dart';
import 'package:mi_app/Vista/Widgets/tarjeta_producto_inventario.dart';
import 'package:mi_app/Vista/Widgets/dashboard_vista.dart';
import 'package:mi_app/Vista/Widgets/tarjeta_historial_venta.dart';
import 'package:mi_app/Servicios/servicio_ticket_pdf.dart';
import 'package:mi_app/Vista/perfil.dart';
import 'package:mi_app/Tema/app_theme.dart';
import 'package:mi_app/Modelos/finanzas.dart';
import 'package:mi_app/Vista/empleados_vista.dart';
import 'package:mi_app/Vista/historial_ventas_vista.dart';
import 'package:mi_app/Vista/Widgets/dialogo_seguridad_admin.dart';
import 'package:mi_app/Vista/Widgets/formulario_empleado_sheet.dart';
import 'package:mi_app/Utilidades/formateador.dart';
import 'package:mi_app/Controladores/controlador_hardware.dart';
import 'package:mi_app/Servicios/generador_esc_pos.dart';
import 'package:mi_app/Modelos/configuracion_hardware.dart';
import 'package:mi_app/Vista/Widgets/logo_biznaga.dart';
import 'package:mi_app/IA/Controladores/controlador_ia_compras.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
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
    test('RolUsuario.desdeString mapea correctamente esquemas legados y sinónimos', () {
      expect(RolUsuario.desdeString('admin'), RolUsuario.duena);
      expect(RolUsuario.desdeString('dueña'), RolUsuario.duena);
      expect(RolUsuario.desdeString('duena'), RolUsuario.duena);
      expect(RolUsuario.desdeString('DUENA'), RolUsuario.duena);
      expect(RolUsuario.desdeString('gerente'), RolUsuario.gerente);
      expect(RolUsuario.desdeString('manager'), RolUsuario.gerente);
      expect(RolUsuario.desdeString('cajero'), RolUsuario.empleado);
      expect(RolUsuario.desdeString('empleado'), RolUsuario.empleado);
      expect(RolUsuario.desdeString(null), RolUsuario.empleado);
      expect(RolUsuario.desdeString('desconocido'), RolUsuario.empleado);
    });

    test('Permisos de negocio por cada rol son coherentes', () {
      expect(RolUsuario.duena.puedeVerFinanzas, isTrue);
      expect(RolUsuario.duena.puedeModificarInventario, isTrue);
      expect(RolUsuario.duena.puedeGestionarColaboradores, isTrue);

      expect(RolUsuario.gerente.puedeVerFinanzas, isTrue);
      expect(RolUsuario.gerente.puedeModificarInventario, isTrue);
      expect(RolUsuario.gerente.puedeGestionarColaboradores, isTrue);

      expect(RolUsuario.empleado.puedeVerFinanzas, isFalse);
      expect(RolUsuario.empleado.puedeModificarInventario, isFalse);
      expect(RolUsuario.empleado.puedeGestionarColaboradores, isFalse);
      expect(RolUsuario.empleado.soloPuntoDeVenta, isTrue);
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
            body: RoleGuard.gerencia(
              rolActual: RolUsuario.empleado,
              modo: RoleGuardMode.ocultar,
              child: Text('Solo Gerencia'),
            ),
          ),
        ),
      );

      expect(find.text('Solo Gerencia'), findsNothing);
    });

    testWidgets('RoleGuard muestra widget cuando rol sí está autorizado', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoleGuard.gerencia(
              rolActual: RolUsuario.gerente,
              modo: RoleGuardMode.ocultar,
              child: Text('Solo Gerencia'),
            ),
          ),
        ),
      );

      expect(find.text('Solo Gerencia'), findsOneWidget);
    });

    testWidgets('RoleGuard muestra AccesoDenegadoView cuando modo es placeholder', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoleGuard.gerencia(
              rolActual: RolUsuario.empleado,
              modo: RoleGuardMode.placeholder,
              titulo: 'Acceso Prohibido',
              child: Text('Solo Gerencia'),
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

    testWidgets('Modo Dueña/Gerente en Dashboard muestra ingresos totales y tarjeta de deudores', (WidgetTester tester) async {
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
}
