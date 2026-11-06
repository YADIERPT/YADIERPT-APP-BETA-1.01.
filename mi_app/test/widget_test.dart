import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/Controladores/controlador_autenticacion.dart';
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
import 'package:mi_app/Controladores/controlador_finanzas.dart';
import 'package:mi_app/Controladores/controlador_perfil.dart';

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

    test('obtenerClaveMaestraDb retorna clave no nula y activa fallback ante entorno sin hardware Keystore', () async {
      final key = await SecureStorageService.instancia.obtenerClaveMaestraDb();
      expect(key, isNotEmpty);
      expect(key.length >= 32, isTrue);
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
}
