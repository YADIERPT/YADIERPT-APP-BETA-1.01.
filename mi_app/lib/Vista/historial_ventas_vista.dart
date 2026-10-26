import 'package:flutter/material.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_ventas.dart';
import '../Modelos/venta.dart';
import 'Widgets/tarjeta_historial_venta.dart';

class HistorialVentasVista extends StatefulWidget {
  final ControladorVentas controladorVentas;

  const HistorialVentasVista({super.key, required this.controladorVentas});

  @override
  State<HistorialVentasVista> createState() => _HistorialVentasVistaState();
}

class _HistorialVentasVistaState extends State<HistorialVentasVista> {
  String _periodoSeleccionado = 'Hoy';

  List<Venta> _filtrarVentasPorPeriodo() {
    final todas = widget.controladorVentas.ventas
        .where((v) => v.estado == EstadoVenta.completada);
    final ahora = DateTime.now();

    if (_periodoSeleccionado == 'Hoy') {
      return todas.where((v) {
        return v.fecha.year == ahora.year &&
            v.fecha.month == ahora.month &&
            v.fecha.day == ahora.day;
      }).toList();
    } else if (_periodoSeleccionado == 'Semana Pasada') {
      final hace7Dias = ahora.subtract(const Duration(days: 7));
      return todas.where((v) {
        return v.fecha.isAfter(hace7Dias) && v.fecha.isBefore(ahora);
      }).toList();
    } else {
      // Mes Pasado
      final hace30Dias = ahora.subtract(const Duration(days: 30));
      return todas.where((v) {
        return v.fecha.isAfter(hace30Dias) && v.fecha.isBefore(ahora);
      }).toList();
    }
  }

  double _calcularVariacion(double totalActual) {
    final todas = widget.controladorVentas.ventas
        .where((v) => v.estado == EstadoVenta.completada);
    final ahora = DateTime.now();
    double totalAnterior = 0.0;

    if (_periodoSeleccionado == 'Hoy') {
      final ayer = ahora.subtract(const Duration(days: 1));
      final ventasAyer = todas.where((v) {
        return v.fecha.year == ayer.year &&
            v.fecha.month == ayer.month &&
            v.fecha.day == ayer.day;
      });
      totalAnterior = ventasAyer.fold(0.0, (sum, v) => sum + v.total);
    } else if (_periodoSeleccionado == 'Semana Pasada') {
      final hace14Dias = ahora.subtract(const Duration(days: 14));
      final hace7Dias = ahora.subtract(const Duration(days: 7));
      final ventasPrev = todas.where((v) {
        return v.fecha.isAfter(hace14Dias) && v.fecha.isBefore(hace7Dias);
      });
      totalAnterior = ventasPrev.fold(0.0, (sum, v) => sum + v.total);
    } else {
      final hace60Dias = ahora.subtract(const Duration(days: 60));
      final hace30Dias = ahora.subtract(const Duration(days: 30));
      final ventasPrev = todas.where((v) {
        return v.fecha.isAfter(hace60Dias) && v.fecha.isBefore(hace30Dias);
      });
      totalAnterior = ventasPrev.fold(0.0, (sum, v) => sum + v.total);
    }

    if (totalAnterior > 0) {
      return ((totalActual - totalAnterior) / totalAnterior) * 100;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        final ventasFiltradas = _filtrarVentasPorPeriodo().reversed.toList();
        final double ventaAcumulada =
            ventasFiltradas.fold(0.0, (sum, v) => sum + v.total);
        final int pedidosCompletados = ventasFiltradas.length;
        final double ticketPromedio = pedidosCompletados > 0
            ? ventaAcumulada / pedidosCompletados
            : 0.0;
        final double variacion = _calcularVariacion(ventaAcumulada);

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            title: Text(
              'Historial de Ventas',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            backgroundColor: AppColors.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Pestañas de período: "Hoy", "Semana Pasada", "Mes Pasado"
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children:
                      ['Hoy', 'Semana Pasada', 'Mes Pasado'].map((opcion) {
                    final bool activa = _periodoSeleccionado == opcion;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _periodoSeleccionado = opcion;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: activa
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: activa
                                ? [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              opcion,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: activa
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: activa
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Bloque de resumen del período seleccionado
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color:
                      ThemeManager.instance.isDarkMode ? null : AppColors.card,
                  gradient: ThemeManager.instance.isDarkMode
                      ? AppColors.darkCardGradient
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Venta acumulada ($_periodoSeleccionado)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '\$${ventaAcumulada.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: variacion >= 0
                                ? AppColors.subtleGreen
                                : AppColors.subtleCoral,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                variacion >= 0
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                size: 13,
                                color: variacion >= 0
                                    ? AppColors.brightGreen
                                    : AppColors.coral,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                variacion >= 0
                                    ? '+${variacion.toStringAsFixed(1)}%'
                                    : '${variacion.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: variacion >= 0
                                      ? AppColors.brightGreen
                                      : AppColors.coral,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'vs anterior',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$pedidosCompletados',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Pedidos completados',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 28,
                          width: 1,
                          color: AppColors.border,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\$${ticketPromedio.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Ticket promedio',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Sección "Detalle de operaciones"
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Detalle de operaciones',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.secondarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pedidosCompletados ventas registradas',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Lista de ventas o estado vacío
              if (ventasFiltradas.isEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 42,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Sin ventas en este periodo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No se registraron transacciones para el periodo seleccionado.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...ventasFiltradas.map((v) => TarjetaHistorialVenta(venta: v)),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
