import 'package:flutter_test/flutter_test.dart';
import 'package:mi_app/IA/Modelos/recomendacion_compra.dart';
import 'package:mi_app/IA/Motores/motor_ia_recomendacion.dart';
import 'package:mi_app/Modelos/producto.dart';
import 'package:mi_app/Modelos/venta.dart';

void main() {
  group('Pruebas del Motor de IA de Recomendación y Calibración Local', () {
    late Producto monstera;
    late Producto maceta;
    late Producto suculentaHueso;

    setUp(() {
      monstera = Producto(
        id: 'BOT-001',
        nombre: 'Monstera Deliciosa',
        precioVenta: 250.0,
        costo: 100.0,
        cantidadEnInventario: 2, // Stock muy bajo
        umbralStockCritico: 5,
        tipo: 'planta',
      );

      maceta = Producto(
        id: 'ART-001',
        nombre: 'Maceta Cerámica 20cm',
        precioVenta: 120.0,
        costo: 50.0,
        cantidadEnInventario: 4,
        umbralStockCritico: 6,
        tipo: 'articulo',
      );

      suculentaHueso = Producto(
        id: 'BOT-002',
        nombre: 'Cactus Raro (Baja Rotación)',
        precioVenta: 300.0,
        costo: 200.0,
        cantidadEnInventario: 1,
        umbralStockCritico: 5,
        tipo: 'planta',
      );
    });

    test('Calibra alta demanda y clasifica como CRÍTICO cuando el stock se agota', () {
      final hoy = DateTime.now();
      final ventas = <Venta>[];

      // Simulamos ventas frecuentes de Monstera en los últimos 5 días
      for (int i = 0; i < 5; i++) {
        final venta = Venta(
          id: 'V-00$i',
          fecha: hoy.subtract(Duration(days: i)),
          estado: EstadoVenta.completada,
          articulos: [
            ArticuloVenta(
              producto: monstera,
              cantidad: 3,
              precioUnitario: monstera.precioVenta,
            ),
          ],
        );
        ventas.add(venta);
      }

      final resultado = MotorIARecomendacion.ejecutarAnalisis(
        productos: [monstera, maceta, suculentaHueso],
        ventas: ventas,
        horizonteReposicionDias: 14,
      );

      final calMonstera = resultado.calibraciones['BOT-001'];
      expect(calMonstera, isNotNull);
      expect(calMonstera!.velocidadDiaria, greaterThan(0.5));
      expect(calMonstera.nivelRotacion, 'ALTA');

      final recMonstera = resultado.recomendaciones
          .firstWhere((r) => r.productoId == 'BOT-001');
      expect(recMonstera.nivelUrgencia, NivelUrgencia.critico);
      expect(recMonstera.cantidadSugerida, greaterThanOrEqualTo(10));
      expect(recMonstera.motivoRazonado, contains('Agotamiento inminente'));
    });

    test('Detecta producto de baja rotación y advierte no inmovilizar capital', () {
      final hace60Dias = DateTime.now().subtract(const Duration(days: 60));
      final ventas = [
        Venta(
          id: 'V-OLD',
          fecha: hace60Dias,
          estado: EstadoVenta.completada,
          articulos: [
            ArticuloVenta(
              producto: suculentaHueso,
              cantidad: 1,
              precioUnitario: suculentaHueso.precioVenta,
            ),
          ],
        ),
      ];

      final resultado = MotorIARecomendacion.ejecutarAnalisis(
        productos: [suculentaHueso],
        ventas: ventas,
        horizonteReposicionDias: 14,
      );

      final recHueso = resultado.recomendaciones
          .firstWhere((r) => r.productoId == 'BOT-002');
      expect(recHueso.nivelUrgencia, NivelUrgencia.bajaRotacion);
      expect(recHueso.cantidadSugerida, 0); // Congruente: no sugiere comprar lo que no se vende
      expect(recHueso.motivoRazonado, contains('Baja rotación'));
    });

    test('Alerta si el costo supera o iguala al precio de venta y no sugiere comprar a pérdida', () {
      final productoPerdida = Producto(
        id: 'BOT-999',
        nombre: 'Planta con Precio Erróneo',
        precioVenta: 50.0,
        costo: 60.0, // Costo mayor al precio
        cantidadEnInventario: 1,
        umbralStockCritico: 5,
        tipo: 'planta',
      );

      final resultado = MotorIARecomendacion.ejecutarAnalisis(
        productos: [productoPerdida],
        ventas: [],
        horizonteReposicionDias: 14,
      );

      final rec = resultado.recomendaciones.first;
      expect(rec.cantidadSugerida, 0);
      expect(rec.motivoRazonado, contains('Alerta de margen'));
    });

    test('Adapta la cantidad sugerida según el horizonte de abastecimiento del vivero', () {
      final hoy = DateTime.now();
      final ventas = [
        Venta(
          id: 'V-01',
          fecha: hoy.subtract(const Duration(days: 1)),
          estado: EstadoVenta.completada,
          articulos: [
            ArticuloVenta(
              producto: maceta,
              cantidad: 10,
              precioUnitario: maceta.precioVenta,
            ),
          ],
        ),
      ];

      // Caso 1: Proveedor rápido (7 días)
      final resCorto = MotorIARecomendacion.ejecutarAnalisis(
        productos: [maceta],
        ventas: ventas,
        horizonteReposicionDias: 7,
      );
      final cantCorto = resCorto.recomendaciones.first.cantidadSugerida;

      // Caso 2: Proveedor lejano / viverista foráneo (30 días)
      final resLargo = MotorIARecomendacion.ejecutarAnalisis(
        productos: [maceta],
        ventas: ventas,
        horizonteReposicionDias: 30,
      );
      final cantLargo = resLargo.recomendaciones.first.cantidadSugerida;

      expect(cantLargo, greaterThan(cantCorto));
    });

    test('Si se venden 3 unidades con stock 0 y umbral 3, sugiere exactamente 3 unidades y nunca cantidades exageradas (como 18)', () {
      final plantaVentaPuntual = Producto(
        id: 'BOT-PUNTUAL-01',
        nombre: 'Ficus Pandurata',
        precioVenta: 180.0,
        costo: 80.0,
        cantidadEnInventario: 0,
        umbralStockCritico: 3,
        tipo: 'planta',
      );

      final hoy = DateTime.now();
      final ventas = [
        Venta(
          id: 'V-TEST-3',
          fecha: hoy.subtract(const Duration(hours: 4)),
          estado: EstadoVenta.completada,
          articulos: [
            ArticuloVenta(
              producto: plantaVentaPuntual,
              cantidad: 3,
              precioUnitario: plantaVentaPuntual.precioVenta,
            ),
          ],
        ),
      ];

      final resultado = MotorIARecomendacion.ejecutarAnalisis(
        productos: [plantaVentaPuntual],
        ventas: ventas,
        horizonteReposicionDias: 14,
      );

      final rec = resultado.recomendaciones
          .firstWhere((r) => r.productoId == 'BOT-PUNTUAL-01');

      // Congruencia estricta: vendió 3 y stock es 0 -> repone exactamente 3 (no 18)
      expect(rec.cantidadSugerida, equals(3));
      expect(rec.cantidadSugerida, lessThanOrEqualTo(5));
      expect(rec.motivoRazonado, contains('Registras 3 ventas recientes'));
      expect(rec.motivoRazonado, contains('sin sobrecargar inventario'));
    });

    test('Si se venden 3 unidades pero queda stock 1 (umbral 3), sugiere reponer 2 unidades', () {
      final orquidea = Producto(
        id: 'BOT-ORQ-01',
        nombre: 'Orquídea Blanca',
        precioVenta: 200.0,
        costo: 90.0,
        cantidadEnInventario: 1, // Queda 1 en stock
        umbralStockCritico: 3,
        tipo: 'planta',
      );

      final hoy = DateTime.now();
      final ventas = [
        Venta(
          id: 'V-ORQ-3',
          fecha: hoy.subtract(const Duration(days: 1)),
          estado: EstadoVenta.completada,
          articulos: [
            ArticuloVenta(
              producto: orquidea,
              cantidad: 3,
              precioUnitario: orquidea.precioVenta,
            ),
          ],
        ),
      ];

      final resultado = MotorIARecomendacion.ejecutarAnalisis(
        productos: [orquidea],
        ventas: ventas,
        horizonteReposicionDias: 14,
      );

      final rec = resultado.recomendaciones
          .firstWhere((r) => r.productoId == 'BOT-ORQ-01');

      // Falta reponer 2 unidades para alcanzar el umbral de 3
      expect(rec.cantidadSugerida, equals(2));
    });
  });
}
