import '../Modelos/resumen_inicio.dart';
import '../Modelos/venta.dart';
import '../IA/Controladores/controlador_ia_compras.dart';
import 'controlador_inventario.dart';
import 'controlador_ventas.dart';
import 'controlador_finanzas.dart';
import 'controlador_perfil.dart';
import 'controlador_biometrico.dart';

import 'package:flutter/foundation.dart';

import '../Modelos/producto.dart';
import '../Modelos/resumen_inicio.dart';
import '../Modelos/venta.dart';
import '../IA/Controladores/controlador_ia_compras.dart';
import 'controlador_inventario.dart';
import 'controlador_ventas.dart';
import 'controlador_finanzas.dart';
import 'controlador_perfil.dart';
import 'controlador_biometrico.dart';

/// DTO inmutable que encapsula las métricas precomputadas para el Dashboard.
/// Alivia al método `build()` de la UI de iteraciones, filtros y ordenamientos en cada frame.
class MetricasDashboard {
  final String periodo;
  final double totalVentas;
  final int cantidadVentas;
  final double ticketPromedio;
  final List<Venta> ventasRecientes;
  final List<Venta> deudoresPendientes;
  final double totalPorCobrar;
  final List<Venta> deudoresRecientes;
  final List<Map<String, dynamic>> puntosGrafico;
  final double maxMonto;
  final String horaTooltip;
  final double montoTooltip;
  final int ventasTooltip;
  final int idxDestacado;
  final List<Producto> productosBajoStock;

  const MetricasDashboard({
    required this.periodo,
    required this.totalVentas,
    required this.cantidadVentas,
    required this.ticketPromedio,
    required this.ventasRecientes,
    required this.deudoresPendientes,
    required this.totalPorCobrar,
    required this.deudoresRecientes,
    required this.puntosGrafico,
    required this.maxMonto,
    required this.horaTooltip,
    required this.montoTooltip,
    required this.ventasTooltip,
    this.idxDestacado = 3,
    required this.productosBajoStock,
  });

  static const vacio = MetricasDashboard(
    periodo: 'Hoy',
    totalVentas: 0.0,
    cantidadVentas: 0,
    ticketPromedio: 0.0,
    ventasRecientes: [],
    deudoresPendientes: [],
    totalPorCobrar: 0.0,
    deudoresRecientes: [],
    puntosGrafico: [],
    maxMonto: 0.0,
    horaTooltip: '12:00',
    montoTooltip: 0.0,
    ventasTooltip: 0,
    idxDestacado: 3,
    productosBajoStock: [],
  );
}

class ControladorInicio extends ChangeNotifier {
  final ControladorInventario controladorInventario;
  final ControladorVentas controladorVentas;
  final ControladorFinanzas controladorFinanzas;
  final ControladorPerfil controladorPerfil;
  final ControladorBiometrico controladorBiometrico;
  final ControladorIACompras controladorIA;

  String _periodoSeleccionado = 'Hoy';
  MetricasDashboard _metricasDashboard = MetricasDashboard.vacio;

  String get periodoSeleccionado => _periodoSeleccionado;
  MetricasDashboard get metricasDashboard => _metricasDashboard;

  ControladorInicio({
    required this.controladorInventario,
    required this.controladorVentas,
    required this.controladorFinanzas,
    required this.controladorPerfil,
    ControladorBiometrico? controladorBiometrico,
    ControladorIACompras? controladorIA,
  })  : controladorBiometrico =
            controladorBiometrico ?? ControladorBiometrico(),
        controladorIA = controladorIA ??
            ControladorIACompras(controladorInventario: controladorInventario) {
    // Escucha reactiva: recalcula métricas solo cuando el inventario o las ventas cambian
    controladorVentas.addListener(actualizarMetricasDashboard);
    controladorInventario.addListener(actualizarMetricasDashboard);
  }

  @override
  void dispose() {
    controladorVentas.removeListener(actualizarMetricasDashboard);
    controladorInventario.removeListener(actualizarMetricasDashboard);
    super.dispose();
  }

  void cambiarPeriodo(String nuevoPeriodo) {
    if (_periodoSeleccionado != nuevoPeriodo) {
      _periodoSeleccionado = nuevoPeriodo;
      actualizarMetricasDashboard();
    }
  }

  /// Ejecuta todas las agregaciones financieras, filtros temporales y ordenamientos
  /// en un único paso y guarda el resultado memoizado en memoria.
  void actualizarMetricasDashboard() {
    final productosBajoStock = controladorInventario.productos
        .where((p) => p.esStockCritico)
        .toList();

    final hoy = DateTime.now();
    final List<Venta> ventasPeriodo;

    if (_periodoSeleccionado == 'Semana') {
      final hace7Dias = hoy.subtract(const Duration(days: 7));
      ventasPeriodo = controladorVentas.ventas
          .where((v) =>
              v.estado == EstadoVenta.completada &&
              v.fecha.isAfter(hace7Dias))
          .toList();
    } else if (_periodoSeleccionado == 'Mes') {
      final hace30Dias = hoy.subtract(const Duration(days: 30));
      ventasPeriodo = controladorVentas.ventas
          .where((v) =>
              v.estado == EstadoVenta.completada &&
              v.fecha.isAfter(hace30Dias))
          .toList();
    } else {
      ventasPeriodo = controladorVentas.ventas
          .where((v) =>
              v.estado == EstadoVenta.completada &&
              v.fecha.year == hoy.year &&
              v.fecha.month == hoy.month &&
              v.fecha.day == hoy.day)
          .toList();
    }

    final double totalVentas =
        ventasPeriodo.fold(0.0, (sum, v) => sum + v.total);
    final int cantidadVentas = ventasPeriodo.length;
    final double ticketPromedio =
        cantidadVentas > 0 ? totalVentas / cantidadVentas : 0.0;

    final ventasOrdenadas = [...ventasPeriodo]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final ventasRecientes = ventasOrdenadas.take(4).toList();

    final deudoresPendientes = controladorVentas.ventas
        .where((v) =>
            v.estado == EstadoVenta.apartada ||
            (v.estado != EstadoVenta.cancelada && v.tieneSaldoPendiente))
        .toList();

    final double totalPorCobrar = deudoresPendientes.fold(
      0.0,
      (sum, v) => sum + v.saldoPendiente,
    );

    final deudoresOrdenados = [...deudoresPendientes]
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final deudoresRecientes = deudoresOrdenados.take(4).toList();

    final List<Map<String, dynamic>> puntosGrafico = [
      {'hora': '8:00', 'monto': 0.0, 'conteo': 0},
      {'hora': '10:00', 'monto': 0.0, 'conteo': 0},
      {'hora': '12:00', 'monto': 0.0, 'conteo': 0},
      {'hora': '14:00', 'monto': 0.0, 'conteo': 0},
      {'hora': '16:00', 'monto': 0.0, 'conteo': 0},
      {'hora': '18:00', 'monto': 0.0, 'conteo': 0},
    ];

    for (var v in ventasPeriodo) {
      int hr = v.fecha.hour;
      int idx = -1;
      if (hr < 9) {
        idx = 0;
      } else if (hr < 11) {
        idx = 1;
      } else if (hr < 13) {
        idx = 2;
      } else if (hr < 15) {
        idx = 3;
      } else if (hr < 17) {
        idx = 4;
      } else {
        idx = 5;
      }

      if (idx != -1) {
        puntosGrafico[idx]['monto'] += v.total;
        puntosGrafico[idx]['conteo'] += 1;
      }
    }

    double maxMonto = 0;
    int idxDestacado = 3;
    for (int i = 0; i < puntosGrafico.length; i++) {
      if (puntosGrafico[i]['monto'] > maxMonto) {
        maxMonto = puntosGrafico[i]['monto'];
        idxDestacado = i;
      }
    }

    final pDestacado = puntosGrafico[idxDestacado];

    _metricasDashboard = MetricasDashboard(
      periodo: _periodoSeleccionado,
      totalVentas: totalVentas,
      cantidadVentas: cantidadVentas,
      ticketPromedio: ticketPromedio,
      ventasRecientes: ventasRecientes,
      deudoresPendientes: deudoresPendientes,
      totalPorCobrar: totalPorCobrar,
      deudoresRecientes: deudoresRecientes,
      puntosGrafico: puntosGrafico,
      maxMonto: maxMonto,
      horaTooltip: pDestacado['hora'],
      montoTooltip: pDestacado['monto'],
      ventasTooltip: pDestacado['conteo'],
      idxDestacado: idxDestacado,
      productosBajoStock: productosBajoStock,
    );

    notifyListeners();
  }

  Future<void> inicializarDatosOffline() async {
    await controladorPerfil.cargarConfiguracion();
    await controladorInventario.cargarProductos();
    await controladorFinanzas.cargarTransacciones();
    await controladorVentas.cargarVentas();
    await controladorBiometrico.inicializar();
    await controladorIA.inicializar(controladorVentas.ventas);
    actualizarMetricasDashboard();
  }

  ResumenInicio generarResumenDelDia() {
    final hoy = DateTime.now();
    final inicioDelDia = DateTime(hoy.year, hoy.month, hoy.day);
    final finDelDia = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);

    final rendimientoHoy = controladorFinanzas.calcularRendimientoPorFecha(
      inicioDelDia,
      finDelDia,
    );

    int ventasCompletadas = 0;
    int ventasApartadas = 0;

    for (var venta in controladorVentas.ventas) {
      if (venta.fecha.isAfter(inicioDelDia) &&
          venta.fecha.isBefore(finDelDia)) {
        if (venta.estado == EstadoVenta.completada) {
          ventasCompletadas++;
        } else if (venta.estado == EstadoVenta.apartada) {
          ventasApartadas++;
        }
      }
    }

    int totalProductos = 0;
    for (var producto in controladorInventario.productos) {
      totalProductos += producto.cantidadEnInventario;
    }

    return ResumenInicio(
      totalProductosInventario: totalProductos,
      ventasCompletadasHoy: ventasCompletadas,
      ventasApartadas: ventasApartadas,
      ingresosHoy: rendimientoHoy.totalIngresos,
      gananciasHoy: rendimientoHoy.gananciasNetas,
    );
  }
}
