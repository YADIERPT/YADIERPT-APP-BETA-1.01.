import 'dart:math' as math;

import '../../Modelos/producto.dart';
import '../../Modelos/venta.dart';
import '../Modelos/calibracion_producto.dart';
import '../Modelos/recomendacion_compra.dart';

class ResultadoAnalisisIA {
  final List<RecomendacionCompra> recomendaciones;
  final Map<String, CalibracionProducto> calibraciones;

  const ResultadoAnalisisIA({
    required this.recomendaciones,
    required this.calibraciones,
  });
}

class MotorIARecomendacion {
  /// Analiza el inventario y las ventas históricas para generar recomendaciones
  /// matemáticamente y comercialmente congruentes para un vivero.
  static ResultadoAnalisisIA ejecutarAnalisis({
    required List<Producto> productos,
    required List<Venta> ventas,
    int horizonteReposicionDias = 14,
  }) {
    final Map<String, CalibracionProducto> calibraciones = {};
    final List<RecomendacionCompra> sugerencias = [];

    final hoy = DateTime.now();
    final hace7Dias = hoy.subtract(const Duration(days: 7));
    final hace30Dias = hoy.subtract(const Duration(days: 30));

    // 1. Filtrar ventas completadas
    final ventasCompletadas =
        ventas.where((v) => v.estado == EstadoVenta.completada).toList();

    // 2. Indexar ventas por producto y fecha
    final Map<String, Map<String, int>> ventasPorDia = {};
    final Map<String, int> unidadesUltimos7Dias = {};
    final Map<String, int> unidadesUltimos30Dias = {};
    final Map<String, int> unidadesHistoricasTotales = {};
    final Map<String, DateTime> primerVentaPorProducto = {};
    final Map<String, DateTime> ultimaVentaPorProducto = {};

    for (var venta in ventasCompletadas) {
      final claveDia =
          '${venta.fecha.year}-${venta.fecha.month.toString().padLeft(2, '0')}-${venta.fecha.day.toString().padLeft(2, '0')}';

      for (var articulo in venta.articulos) {
        final pId = articulo.producto.id;
        final cant = articulo.cantidad;

        ventasPorDia.putIfAbsent(pId, () => {});
        ventasPorDia[pId]![claveDia] =
            (ventasPorDia[pId]![claveDia] ?? 0) + cant;

        unidadesHistoricasTotales[pId] =
            (unidadesHistoricasTotales[pId] ?? 0) + cant;

        if (venta.fecha.isAfter(hace7Dias)) {
          unidadesUltimos7Dias[pId] = (unidadesUltimos7Dias[pId] ?? 0) + cant;
        }
        if (venta.fecha.isAfter(hace30Dias)) {
          unidadesUltimos30Dias[pId] =
              (unidadesUltimos30Dias[pId] ?? 0) + cant;
        }

        if (!primerVentaPorProducto.containsKey(pId) ||
            venta.fecha.isBefore(primerVentaPorProducto[pId]!)) {
          primerVentaPorProducto[pId] = venta.fecha;
        }

        if (!ultimaVentaPorProducto.containsKey(pId) ||
            venta.fecha.isAfter(ultimaVentaPorProducto[pId]!)) {
          ultimaVentaPorProducto[pId] = venta.fecha;
        }
      }
    }

    // 3. Analizar cada producto con rigurosa congruencia matemática
    for (var producto in productos) {
      final pId = producto.id;
      final int stock = math.max(0, producto.cantidadEnInventario);
      final int u7 = unidadesUltimos7Dias[pId] ?? 0;
      final int u30 = unidadesUltimos30Dias[pId] ?? 0;
      final int uTot = unidadesHistoricasTotales[pId] ?? 0;

      final double v7 = u7 / 7.0;
      final double v30 = u30 / 30.0;

      // Contar días con venta efectiva en los últimos 30 días
      int diasConVentaEn30 = 0;
      if (ventasPorDia.containsKey(pId)) {
        for (int i = 0; i < 30; i++) {
          final dia = hoy.subtract(Duration(days: i));
          final clave =
              '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';
          if ((ventasPorDia[pId]![clave] ?? 0) > 0) {
            diasConVentaEn30++;
          }
        }
      }

      final fechaInicio = primerVentaPorProducto[pId] ?? hace30Dias;
      // Ventana de observación mínima de 30 días para evitar proyecciones irreales en ventas de primer día
      final int diasObservacion =
          math.max(30, hoy.difference(fechaInicio).inDays);
      final double vHist = uTot / diasObservacion.toDouble();

      // Cálculo de velocidad diaria adaptado a la frecuencia real
      double velocidadDiaria = 0.0;
      if (u30 > 0) {
        if (diasConVentaEn30 <= 2) {
          // Ventas aisladas / esporádicas en el mes:
          // La tasa diaria es estrictamente el promedio mensual real
          velocidadDiaria = v30;
        } else {
          // Ventas recurrentes a lo largo de varios días:
          velocidadDiaria = (0.30 * v7) + (0.65 * v30) + (0.05 * vHist);
        }
      } else if (uTot > 0) {
        // Hubo ventas históricas pero ninguna en los últimos 30 días
        velocidadDiaria = 0.02 * vHist;
      }

      // Variabilidad diaria (desviación estándar)
      double variabilidad = 0.0;
      if (u30 > 0 && ventasPorDia.containsKey(pId)) {
        final ventasDias = ventasPorDia[pId]!;
        double sumaDiferenciasCuadradas = 0.0;
        for (int i = 0; i < 30; i++) {
          final dia = hoy.subtract(Duration(days: i));
          final clave =
              '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';
          final cantDia = (ventasDias[clave] ?? 0).toDouble();
          sumaDiferenciasCuadradas += math.pow(cantDia - v30, 2);
        }
        variabilidad = math.sqrt(sumaDiferenciasCuadradas / 30.0);
      }

      // Tendencia (aceleración reciente vs promedio mensual)
      double tendencia = 0.0;
      if (v30 > 0.01) {
        tendencia = (v7 - v30) / v30;
      }

      // Clasificación de rotación
      String nivelRotacion;
      if (velocidadDiaria >= 0.7 || (v7 >= 1.0 && u30 >= 10)) {
        nivelRotacion = 'ALTA';
      } else if (velocidadDiaria >= 0.2 || v7 >= 0.4) {
        nivelRotacion = 'MEDIA';
      } else if (uTot > 0) {
        nivelRotacion = 'BAJA';
      } else {
        nivelRotacion = 'NULA';
      }

      // Días de cobertura reales
      // Si la velocidad es casi nula y hay stock, la cobertura es holgada (999 días)
      final double diasCobertura = (velocidadDiaria >= 0.02)
          ? (stock / velocidadDiaria)
          : (stock > 0 ? 999.0 : 0.0);

      // Tiempo de reposición seleccionado para la simulación
      final int leadTimeProducto = horizonteReposicionDias;

      // Stock de seguridad proporcional y prudente
      int stockSeguridad = 0;
      if (u30 > 12) {
        final double zFactor = 1.28; // Cobertura 90% comercial
        final int ssCalculado =
            (zFactor * math.sqrt(leadTimeProducto) * variabilidad).ceil();
        // El stock de seguridad nunca debe superar el 25% del consumo mensual
        stockSeguridad =
            math.max(1, math.min(ssCalculado, (u30 * 0.25).ceil()));
      } else if (u30 >= 6) {
        stockSeguridad = 1;
      }

      // Demanda esperada durante el tiempo que tarda el proveedor
      final double demandaLeadTime = velocidadDiaria * leadTimeProducto;

      // Punto de Reorden (ROP): Demanda durante Lead Time + Stock de Seguridad
      final int rop = math.max(
        producto.umbralStockCritico,
        (demandaLeadTime + stockSeguridad).ceil(),
      );

      // Ponderación de rentabilidad y score de prioridad
      final double margenUnitario = producto.precioVenta - producto.costo;
      final double margenPorcentual = producto.precioVenta > 0
          ? (margenUnitario / producto.precioVenta) * 100
          : 0.0;

      double scorePrioridad = 0.0;
      if (stock == 0 && velocidadDiaria > 0.02) {
        scorePrioridad += 50.0;
      } else if (diasCobertura <= 3.0 && velocidadDiaria > 0.02) {
        scorePrioridad += 40.0;
      } else if (stock <= rop && velocidadDiaria > 0.02) {
        scorePrioridad += 25.0;
      }
      scorePrioridad += (velocidadDiaria * 15.0) + (margenPorcentual * 0.1);

      final calibracion = CalibracionProducto(
        productoId: pId,
        velocidadDiaria: double.parse(velocidadDiaria.toStringAsFixed(2)),
        variabilidad: double.parse(variabilidad.toStringAsFixed(2)),
        diasCobertura: double.parse(diasCobertura.toStringAsFixed(1)),
        tendencia: double.parse(tendencia.toStringAsFixed(2)),
        nivelRotacion: nivelRotacion,
        scorePrioridad: double.parse(scorePrioridad.toStringAsFixed(2)),
        ultimaCalibracion: hoy,
        totalUnidadesHistoricas: uTot,
      );
      calibraciones[pId] = calibracion;

      // =========================================================
      // MOTOR DE RECOMENDACIÓN CONGRUENTE (LÓGICA DE NEGOCIO REAL)
      // =========================================================

      // Caso A: Alerta crítica de margen (Costo >= Precio de Venta)
      if (producto.precioVenta > 0 && producto.costo >= producto.precioVenta) {
        sugerencias.add(
          RecomendacionCompra(
            id: 'REC-$pId-${hoy.millisecondsSinceEpoch}',
            productoId: pId,
            nombreProducto: producto.nombre,
            tipo: producto.tipo,
            stockActual: stock,
            umbralStockCritico: producto.umbralStockCritico,
            cantidadSugerida: 0, // No comprar a pérdida
            costoUnitario: producto.costo,
            precioVenta: producto.precioVenta,
            costoTotalEstimado: 0.0,
            gananciaEstimada: 0.0,
            margenPorcentual: margenPorcentual,
            nivelUrgencia: NivelUrgencia.critico,
            diasHastaAgotamiento: diasCobertura,
            motivoRazonado:
                'Alerta de margen: El costo (\$${producto.costo.toStringAsFixed(2)}) supera o iguala el precio (\$${producto.precioVenta.toStringAsFixed(2)}). Ajusta tu precio antes de adquirir más piezas.',
            fechaGeneracion: hoy,
            velocidadDiaria: velocidadDiaria,
          ),
        );
        continue;
      }

      // Caso B: Producto con rotación activa (u30 > 0)
      if (velocidadDiaria >= 0.02 && u30 > 0) {
        // ¿El stock actual realmente está en riesgo dentro del ciclo de reposición?
        final bool requiereCompra = (stock <= rop ||
            stock == 0 ||
            diasCobertura <= (leadTimeProducto * 1.2));

        if (requiereCompra) {
          // Objetivo de stock: Cubrir la demanda del proveedor + stock de seguridad,
          // garantizando además el umbral mínimo de exhibición del negocio.
          final int inventarioObjetivo = math.max(
            producto.umbralStockCritico,
            (demandaLeadTime + stockSeguridad).ceil(),
          );

          int cantidadSugerida = math.max(1, inventarioObjetivo - stock);

          // Anclaje al volumen real de venta (Sanity check para ventas bajas y medianas):
          // Si vendiste 3 piezas, jamás recomendar comprar 18.
          // El pedido debe restituir lo vendido o completar el umbral mínimo de exhibición.
          if (u30 <= 15) {
            final int deficitUmbral =
                math.max(0, producto.umbralStockCritico - stock);
            final int reposicionVentas = math.max(0, u30 - stock);
            final int topeRazonable = math.max(deficitUmbral, reposicionVentas);

            final int maximoPermitido = math.max(1, topeRazonable);
            if (cantidadSugerida > maximoPermitido) {
              cantidadSugerida = maximoPermitido;
            }
          }

          if (cantidadSugerida > 0) {
            NivelUrgencia nivelUrgencia;
            String motivo;

            if (stock == 0) {
              nivelUrgencia = NivelUrgencia.critico;
              if (u30 <= 10) {
                motivo =
                    'Producto agotado. Registras $u30 ${u30 == 1 ? 'venta reciente' : 'ventas recientes'} y te has quedado sin stock. Sugerimos reponer $cantidadSugerida ${cantidadSugerida == 1 ? 'unidad' : 'unidades'} para surtir a tus clientes sin sobrecargar inventario.';
              } else {
                motivo =
                    'Producto agotado con demanda activa (~${velocidadDiaria.toStringAsFixed(1)} unid/día). Pide $cantidadSugerida unid. para cubrir los $leadTimeProducto días de abastecimiento del proveedor.';
              }
            } else if (diasCobertura <= 3.0) {
              nivelUrgencia = NivelUrgencia.critico;
              if (u30 <= 10) {
                motivo =
                    'Agotamiento inminente: Quedan solo $stock unid. frente a $u30 ventas recientes. Se sugiere pedir +$cantidadSugerida unid. para reabastecer a tiempo considerando $leadTimeProducto días de envío.';
              } else {
                motivo =
                    'Agotamiento inminente: Quedan solo $stock unid. (cobertura de ~${diasCobertura.toStringAsFixed(1)} días). Con entrega en $leadTimeProducto días, es urgente pedir +$cantidadSugerida unid. para evitar desabasto.';
              }
            } else if (diasCobertura <= leadTimeProducto) {
              nivelUrgencia = NivelUrgencia.alto;
              motivo =
                  'Momento óptimo de pedido: El inventario ($stock unid.) durará ~${diasCobertura.toStringAsFixed(1)} días, tiempo que demora el proveedor (~$leadTimeProducto días). Pedir +$cantidadSugerida unid. evitará quiebre de stock.';
            } else {
              nivelUrgencia = NivelUrgencia.moderado;
              motivo =
                  'Planificación preventiva: Quedan existencias para ~${diasCobertura.toStringAsFixed(1)} días con ritmo de ~${(velocidadDiaria * 7).toStringAsFixed(1)} unid/semana. Se aconseja programar lote de +$cantidadSugerida unid.';
            }

            if (tendencia > 0.25 && u30 > 10) {
              motivo +=
                  ' La demanda reciente subió un ${(tendencia * 100).toStringAsFixed(0)}%.';
            }

            final costoTotal = cantidadSugerida * producto.costo;
            final gananciaTotal =
                cantidadSugerida * (producto.precioVenta - producto.costo);

            sugerencias.add(
              RecomendacionCompra(
                id: 'REC-$pId-${hoy.millisecondsSinceEpoch}',
                productoId: pId,
                nombreProducto: producto.nombre,
                tipo: producto.tipo,
                stockActual: stock,
                umbralStockCritico: producto.umbralStockCritico,
                cantidadSugerida: cantidadSugerida,
                costoUnitario: producto.costo,
                precioVenta: producto.precioVenta,
                costoTotalEstimado: costoTotal,
                gananciaEstimada: gananciaTotal,
                margenPorcentual: margenPorcentual,
                nivelUrgencia: nivelUrgencia,
                diasHastaAgotamiento: diasCobertura,
                motivoRazonado: motivo,
                fechaGeneracion: hoy,
                velocidadDiaria: velocidadDiaria,
              ),
            );
          }
        }
      }

      // Caso C: Producto de baja rotación (Sin ventas en los últimos 30 días)
      else if (uTot > 0 && u30 == 0) {
        // Si el stock ya es crítico pero no se vende, NO sugerir compra inflada
        if (stock <= producto.umbralStockCritico) {
          sugerencias.add(
            RecomendacionCompra(
              id: 'REC-$pId-${hoy.millisecondsSinceEpoch}',
              productoId: pId,
              nombreProducto: producto.nombre,
              tipo: producto.tipo,
              stockActual: stock,
              umbralStockCritico: producto.umbralStockCritico,
              cantidadSugerida: 0, // Congruente: ¡No gastar capital en productos que no se mueven!
              costoUnitario: producto.costo,
              precioVenta: producto.precioVenta,
              costoTotalEstimado: 0.0,
              gananciaEstimada: 0.0,
              margenPorcentual: margenPorcentual,
              nivelUrgencia: NivelUrgencia.bajaRotacion,
              diasHastaAgotamiento: 999.0,
              motivoRazonado:
                  'Baja rotación: Quedan $stock unid. y no se ha registrado ninguna venta en los últimos 30 días. No se recomienda adquirir más piezas para no inmovilizar dinero ni arriesgar merma biológica.',
              fechaGeneracion: hoy,
              velocidadDiaria: 0.0,
            ),
          );
        }
      }

      // Caso D: Producto nuevo o sin ventas registradas aún
      else if (uTot == 0) {
        if (stock == 0) {
          // Agotado y nuevo: sugerir un lote inicial mínimo de prueba
          final int lotePrueba = math.max(1, producto.umbralStockCritico);
          sugerencias.add(
            RecomendacionCompra(
              id: 'REC-$pId-${hoy.millisecondsSinceEpoch}',
              productoId: pId,
              nombreProducto: producto.nombre,
              tipo: producto.tipo,
              stockActual: 0,
              umbralStockCritico: producto.umbralStockCritico,
              cantidadSugerida: lotePrueba,
              costoUnitario: producto.costo,
              precioVenta: producto.precioVenta,
              costoTotalEstimado: lotePrueba * producto.costo,
              gananciaEstimada:
                  lotePrueba * (producto.precioVenta - producto.costo),
              margenPorcentual: margenPorcentual,
              nivelUrgencia: NivelUrgencia.moderado,
              diasHastaAgotamiento: 0.0,
              motivoRazonado:
                  'Sin existencias y sin histórico de ventas. Si deseas exhibirlo, pide un lote inicial mínimo de prueba de $lotePrueba unid.',
              fechaGeneracion: hoy,
              velocidadDiaria: 0.0,
            ),
          );
        } else if (stock <= producto.umbralStockCritico) {
          // Tiene stock pero aún no hay ventas: observar antes de comprar más
          sugerencias.add(
            RecomendacionCompra(
              id: 'REC-$pId-${hoy.millisecondsSinceEpoch}',
              productoId: pId,
              nombreProducto: producto.nombre,
              tipo: producto.tipo,
              stockActual: stock,
              umbralStockCritico: producto.umbralStockCritico,
              cantidadSugerida: 0, // Congruente: esperar a que se venda antes de comprar
              costoUnitario: producto.costo,
              precioVenta: producto.precioVenta,
              costoTotalEstimado: 0.0,
              gananciaEstimada: 0.0,
              margenPorcentual: margenPorcentual,
              nivelUrgencia: NivelUrgencia.bajaRotacion,
              diasHastaAgotamiento: 999.0,
              motivoRazonado:
                  'Producto en exhibición con $stock unid. aún sin ventas. Monitorea su aceptación comercial antes de invertir en más compras.',
              fechaGeneracion: hoy,
              velocidadDiaria: 0.0,
            ),
          );
        }
      }
    }

    // Ordenar de forma congruente:
    // 1. Críticos primero
    // 2. Altos segundo
    // 3. Moderados tercero
    // 4. Baja rotación al final
    sugerencias.sort((a, b) {
      final pesoUrgencia = {
        NivelUrgencia.critico: 4,
        NivelUrgencia.alto: 3,
        NivelUrgencia.moderado: 2,
        NivelUrgencia.bajaRotacion: 1,
      };

      final urgA = pesoUrgencia[a.nivelUrgencia] ?? 0;
      final urgB = pesoUrgencia[b.nivelUrgencia] ?? 0;

      if (urgA != urgB) {
        return urgB.compareTo(urgA);
      }

      // Priorizar los que sí requieren compra activa frente a los de cantidad 0
      if (a.cantidadSugerida > 0 && b.cantidadSugerida == 0) return -1;
      if (a.cantidadSugerida == 0 && b.cantidadSugerida > 0) return 1;

      final scoreA = calibraciones[a.productoId]?.scorePrioridad ?? 0.0;
      final scoreB = calibraciones[b.productoId]?.scorePrioridad ?? 0.0;
      return scoreB.compareTo(scoreA);
    });

    return ResultadoAnalisisIA(
      recomendaciones: sugerencias,
      calibraciones: calibraciones,
    );
  }
}
