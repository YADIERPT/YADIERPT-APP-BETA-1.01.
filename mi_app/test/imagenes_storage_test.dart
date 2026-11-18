import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:mi_app/BaseDatos/base_datos.dart';
import 'package:mi_app/Modelos/producto.dart';
import 'package:mi_app/Servicios/servicio_almacenamiento_imagenes.dart';
import 'package:mi_app/Servicios/servicio_conectividad.dart';
import 'package:mi_app/Controladores/controlador_sincronizacion.dart';
import 'package:mi_app/Vista/Widgets/imagen_producto_widget.dart';
import 'package:mi_app/Tema/app_svg_icons.dart';

const k1x1Png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Fase 6: Imágenes y Supabase Storage en Planteapp (Offline-First)', () {
    late Directory tempTestDir;
    late Database db;

    setUp(() async {
      tempTestDir = await Directory.systemTemp.createTemp('planteapp_img_test_');
      ServicioAlmacenamientoImagenes.instancia.setMockDirectorio(tempTestDir);

      db = await openDatabase(
        inMemoryDatabasePath,
        version: 15,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE productos (
              id TEXT PRIMARY KEY,
              uuid TEXT UNIQUE,
              nombre TEXT NOT NULL,
              notas TEXT DEFAULT '',
              precioVenta REAL NOT NULL,
              costo REAL NOT NULL,
              cantidadEnInventario INTEGER NOT NULL,
              umbralStockCritico INTEGER DEFAULT 5,
              tipo TEXT DEFAULT 'planta',
              imagenes TEXT DEFAULT '',
              activo INTEGER DEFAULT 1,
              updated_at TEXT NOT NULL,
              deleted_at TEXT,
              sync_estado TEXT DEFAULT 'pendiente',
              dispositivo_id TEXT
            )
          ''');

          await d.execute('''
            CREATE TABLE cola_imagenes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              producto_uuid TEXT NOT NULL,
              ruta_local_principal TEXT NOT NULL,
              ruta_local_miniatura TEXT NOT NULL,
              intentos INTEGER NOT NULL DEFAULT 0,
              ultimo_error TEXT,
              created_at TEXT NOT NULL
            )
          ''');
          await d.execute('CREATE INDEX idx_cola_img_producto ON cola_imagenes (producto_uuid)');

          await d.execute('''
            CREATE TABLE cola_sincronizacion (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              tabla TEXT NOT NULL,
              registro_uuid TEXT NOT NULL,
              operacion TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              intentos INTEGER NOT NULL DEFAULT 0,
              ultimo_error TEXT,
              created_at TEXT NOT NULL
            )
          ''');

          await d.execute('''
            CREATE TABLE config_sync (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              dispositivo_id TEXT NOT NULL,
              ultimo_pull_por_tabla TEXT NOT NULL DEFAULT '{}',
              ultima_sync_exitosa TEXT,
              sync_habilitada INTEGER NOT NULL DEFAULT 1
            )
          ''');
          await d.execute('''
            INSERT INTO config_sync (id, dispositivo_id, sync_habilitada)
            VALUES (1, 'dispositivo-test-img-uuid', 1)
          ''');
        },
      );
      BaseDeDatos.instancia.setDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
      BaseDeDatos.instancia.setDatabaseForTesting(null);
      ServicioAlmacenamientoImagenes.instancia.setMockDirectorio(null);
      ServicioAlmacenamientoImagenes.instancia.setMockClient(null);
      if (tempTestDir.existsSync()) {
        try {
          tempTestDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('1. Procesamiento local y generación de imagen principal y miniatura (Offline-First)', () async {
      final productoUuid = const Uuid().v4();
      final archivoOriginal = File('${tempTestDir.path}/foto_camara_raw.jpg');
      await archivoOriginal.writeAsBytes(List.generate(1024, (i) => i % 256));

      final procesada = await ServicioAlmacenamientoImagenes.instancia.procesarYGuardarLocal(
        archivoOriginal: archivoOriginal,
        productoUuid: productoUuid,
      );

      expect(procesada.archivoPrincipal.existsSync(), isTrue);
      expect(procesada.archivoMiniatura.existsSync(), isTrue);
      expect(procesada.archivoPrincipal.path.endsWith('_principal.webp'), isTrue);
      expect(procesada.archivoMiniatura.path.endsWith('_thumb.webp'), isTrue);

      // Verificación de método de alto nivel prepararImagenParaProducto
      final rutas = await ServicioAlmacenamientoImagenes.instancia.prepararImagenParaProducto(
        rutaOriginal: archivoOriginal.path,
        productoUuid: productoUuid,
      );

      expect(rutas.length, 2);
      expect(rutas[0].endsWith('_principal.webp'), isTrue);
      expect(rutas[1].endsWith('_thumb.webp'), isTrue);

      // Verificar que assets locales empaquetados se respetan sin procesar
      final rutasAsset = await ServicioAlmacenamientoImagenes.instancia.prepararImagenParaProducto(
        rutaOriginal: 'assets/plantas/suculenta.png',
        productoUuid: productoUuid,
      );
      expect(rutasAsset, ['assets/plantas/suculenta.png']);
    });

    test('2. Caché local síncrono y asíncrono en disco sin conexión a internet', () async {
      final productoUuid = const Uuid().v4();
      final rutaPrincipal = await ServicioAlmacenamientoImagenes.instancia.obtenerRutaEsperadaLocal(
        productoUuid,
        esMiniatura: false,
      );
      final rutaMiniatura = await ServicioAlmacenamientoImagenes.instancia.obtenerRutaEsperadaLocal(
        productoUuid,
        esMiniatura: true,
      );

      final filePrincipal = File(rutaPrincipal);
      await filePrincipal.writeAsBytes([1, 2, 3, 4, 5]);
      final fileMiniatura = File(rutaMiniatura);
      await fileMiniatura.writeAsBytes([6, 7, 8]);

      // Comprobación síncrona instantánea (60 FPS sin esperar Future)
      final cacheSincrono = ServicioAlmacenamientoImagenes.instancia.obtenerArchivoCacheSincrono(
        productoUuid,
        esMiniatura: false,
      );
      expect(cacheSincrono, isNotNull);
      expect(cacheSincrono!.existsSync(), isTrue);
      expect(cacheSincrono.lengthSync(), 5);

      final thumbSincrono = ServicioAlmacenamientoImagenes.instancia.obtenerArchivoCacheSincrono(
        productoUuid,
        esMiniatura: true,
      );
      expect(thumbSincrono, isNotNull);
      expect(thumbSincrono!.lengthSync(), 3);

      // Comprobación asíncrona
      final cacheAsync = await ServicioAlmacenamientoImagenes.instancia.obtenerArchivoCache(
        productoUuid,
        esMiniatura: false,
      );
      expect(cacheAsync, isNotNull);
      expect(cacheAsync!.path, rutaPrincipal);

      // UUID inexistente retorna null con suavidad
      final inexistente = await ServicioAlmacenamientoImagenes.instancia.obtenerArchivoCache('uuid-fantasma');
      expect(inexistente, isNull);
    });

    test('3. Cola de imágenes outbox: encolado y persistencia en modo sin conexión', () async {
      final productoUuid = const Uuid().v4();
      final rutaP = '${tempTestDir.path}/${productoUuid}_principal.webp';
      final rutaM = '${tempTestDir.path}/${productoUuid}_thumb.webp';
      await File(rutaP).writeAsBytes([10, 20]);
      await File(rutaM).writeAsBytes([30]);

      // Simular que no hay conexión
      ServicioConectividad.instancia.setMockConexion(false);

      await ServicioAlmacenamientoImagenes.instancia.encolarSubida(
        productoUuid: productoUuid,
        rutaPrincipal: rutaP,
        rutaMiniatura: rutaM,
      );

      // La imagen debe estar resguardada en SQLite en cola_imagenes
      final pendientes = await db.query('cola_imagenes');
      expect(pendientes.length, 1);
      expect(pendientes.first['producto_uuid'], productoUuid);
      expect(pendientes.first['intentos'], 0);
      expect(pendientes.first['ruta_local_principal'], rutaP);

      // Procesar cola sin red no debe eliminar el elemento
      final subidas = await ServicioAlmacenamientoImagenes.instancia.procesarColaSubida();
      expect(subidas, 0);

      final pendientesDespues = await db.query('cola_imagenes');
      expect(pendientesDespues.length, 1);
    });

    test('4. ControladorSincronizacion incluye cola_imagenes en cambios pendientes y reintentos', () async {
      await db.insert('cola_sincronizacion', {
        'tabla': 'productos',
        'registro_uuid': 'prod-123',
        'operacion': 'upsert',
        'payload_json': '{}',
        'intentos': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      await db.insert('cola_imagenes', {
        'producto_uuid': 'prod-img-456',
        'ruta_local_principal': '/path/p.webp',
        'ruta_local_miniatura': '/path/m.webp',
        'intentos': 1,
        'ultimo_error': 'SocketException: Connection refused',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      final ctrl = ControladorSincronizacion();
      await ctrl.actualizarContadorPendientes();

      // Debe sumar 1 cambio en cola_sincronizacion + 1 en cola_imagenes = 2
      expect(ctrl.cambiosPendientes, 2);

      await ctrl.cargarDetallesCompletos();
      expect(ctrl.registroErrores.isNotEmpty, isTrue);
      expect(ctrl.registroErrores.any((e) => e['tabla'] == 'storage_productos'), isTrue);

      ctrl.dispose();
    });

    testWidgets('5.1 ImagenProductoWidget: Fallback botánico sin imagen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImagenProductoWidget(
              producto: Producto(
                id: '1',
                nombre: 'Planta de Prueba',
                precioVenta: 100,
                costo: 50,
                tipo: 'planta',
                imagenes: [],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SvgIconWidget), findsOneWidget);
    });

    testWidgets('5.2 ImagenProductoWidget: Archivo local', (tester) async {
      final archivoTest = File('${tempTestDir.path}/test_view.webp');
      archivoTest.writeAsBytesSync(k1x1Png);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImagenProductoWidget(
              imagenes: [archivoTest.path],
              esPlanta: false,
            ),
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('5.3 ImagenProductoWidget: Activo bundle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImagenProductoWidget(
              imagenes: ['assets/images/planta_default.png'],
              esPlanta: false,
            ),
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('6. ImagenProductoWidget: Renderizado offline desde caché de disco cuando la URL es remota', (tester) async {
      final productoUuid = const Uuid().v4();
      final rutaThumb = '${tempTestDir.path}/${productoUuid}_thumb.webp';
      final fileThumb = File(rutaThumb);
      fileThumb.writeAsBytesSync(k1x1Png);

      // URL remota simulada de Supabase Storage
      final urlRemota = 'https://supabase.biznaga.co/storage/v1/object/public/productos/$productoUuid/miniatura.webp';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImagenProductoWidget(
              productoUuid: productoUuid,
              imagenes: [urlRemota],
              usarMiniatura: true,
              esPlanta: true,
            ),
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
