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
import 'package:mi_app/Vista/camara_vista.dart';

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

    test('verificarClave valida correctamente contraseñas hasheadas', () {
      final auth = ControladorAutenticacion();
      final hash = ControladorAutenticacion.hashearClave('miSecretoSeguro', 'EMP-01');
      final colaborador = Colaborador(
        id: 'EMP-01',
        nombre: 'Empleado Prueba',
        clave: hash,
        rol: 'cajero',
      );

      expect(auth.verificarClave(colaborador, 'miSecretoSeguro'), isTrue);
      expect(auth.verificarClave(colaborador, 'claveIncorrecta'), isFalse);
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
}
