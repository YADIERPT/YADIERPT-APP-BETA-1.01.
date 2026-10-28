import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../Controladores/controlador_inicio.dart';
import '../../Controladores/controlador_inventario.dart';
import '../../Controladores/controlador_ventas.dart';
import '../../Controladores/controlador_autenticacion.dart';
import '../../Modelos/venta.dart';
import '../../Tema/app_theme.dart';
import '../historial_ventas_vista.dart';

class DashboardVista extends StatefulWidget {
  final ControladorInicio controladorInicio;
  final ControladorInventario controladorInventario;
  final ControladorVentas controladorVentas;
  final ControladorAutenticacion controladorAutenticacion;
  final Function(int) alNavegar;

  const DashboardVista({
    super.key,
    required this.controladorInicio,
    required this.controladorInventario,
    required this.controladorVentas,
    required this.controladorAutenticacion,
    required this.alNavegar,
  });

  @override
  State<DashboardVista> createState() => _DashboardVistaState();
}

class _DashboardVistaState extends State<DashboardVista> {
  String _periodoSeleccionado = 'Hoy';

  @override
  Widget build(BuildContext context) {
    final productosBajoStock = widget.controladorInventario.productos
        .where((p) => p.esStockCritico)
        .toList();

    final hoy = DateTime.now();
    final List<Venta> ventasPeriodo;
    if (_periodoSeleccionado == 'Semana') {
      final hace7Dias = hoy.subtract(const Duration(days: 7));
      ventasPeriodo = widget.controladorVentas.ventas
          .where((v) =>
              v.estado == EstadoVenta.completada &&
              v.fecha.isAfter(hace7Dias))
          .toList();
    } else if (_periodoSeleccionado == 'Mes') {
      final hace30Dias = hoy.subtract(const Duration(days: 30));
      ventasPeriodo = widget.controladorVentas.ventas
          .where((v) =>
              v.estado == EstadoVenta.completada &&
              v.fecha.isAfter(hace30Dias))
          .toList();
    } else {
      ventasPeriodo = widget.controladorVentas.ventas
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

    final ventasRecientes = ventasPeriodo.reversed.take(4).toList();

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
    final String horaTooltip = pDestacado['hora'];
    final double montoTooltip = pDestacado['monto'];
    final int ventasTooltip = pDestacado['conteo'];

    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: AppColors.surface,
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ingresos Totales',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      Text(
                                        '\$${totalVentas.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.brightGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.secondarySurface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: ['Hoy', 'Semana', 'Mes'].map((opcion) {
                                final bool activa = _periodoSeleccionado == opcion;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _periodoSeleccionado = opcion;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: activa
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      opcion,
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
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.darkGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$horaTooltip • \$${montoTooltip.toStringAsFixed(2)} ($ventasTooltip ventas)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 72,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children:
                                    puntosGrafico.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final p = entry.value;
                                  final bool isDestacado = idx == idxDestacado;
                                  double factor = maxMonto > 0
                                      ? (p['monto'] / maxMonto)
                                      : 0.0;
                                  double factorAltura = math.max(0.12, factor);

                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.bottomCenter,
                                              child: FractionallySizedBox(
                                                heightFactor: factorAltura,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: isDestacado
                                                        ? AppColors.brightGreen
                                                        : (ThemeManager.instance.isDarkMode
                                                            ? const Color(0xFF2C2C2E)
                                                            : AppColors.secondarySurface),
                                                    borderRadius:
                                                        const BorderRadius
                                                            .vertical(
                                                      top: Radius.circular(4),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            p['hora'],
                                            style: TextStyle(
                                              color: isDestacado
                                                  ? AppColors.brightGreen
                                                  : AppColors.textSecondary,
                                              fontSize: 9,
                                              fontWeight: isDestacado
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 8),

                    Divider(height: 1, color: AppColors.border),

                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '$cantidadVentas',
                                  style: TextStyle(
                                    color: AppColors.turquoise,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ventas',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
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
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '\$${ticketPromedio.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: AppColors.amber,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ticket prom.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
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
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${productosBajoStock.length}',
                                  style: TextStyle(
                                    color: productosBajoStock.isNotEmpty
                                        ? AppColors.warning
                                        : AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Stock bajo',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (productosBajoStock.isNotEmpty) ...[
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.subtleAmber,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.subtleAmber,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Alerta: Productos con stock bajo',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.amber,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${productosBajoStock.length}',
                                style: TextStyle(
                                  color: AppColors.onWarning,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...productosBajoStock.take(3).map((prod) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.border,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.spa_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      prod.nombre,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${prod.cantidadEnInventario} u. disponibles',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => widget.alNavegar(2),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.warning,
                                  foregroundColor: AppColors.onWarning,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  minimumSize: const Size(60, 28),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Reponer',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Últimas ventas',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistorialVentasVista(
                            controladorVentas: widget.controladorVentas,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            'Ver historial',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: ventasRecientes.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 28.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 40,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Aún no hay ventas el día de hoy',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cuando registres una venta, aparecerá aquí.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: ventasRecientes.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var venta = entry.value;
                          int cantidadArticulos = venta.articulos.fold(
                            0,
                            (sum, art) => sum + art.cantidad,
                          );
                          final String folio = venta.id.length > 5
                              ? venta.id.substring(venta.id.length - 5)
                              : venta.id;
                          final String hora =
                              '${venta.fecha.hour.toString().padLeft(2, '0')}:${venta.fecha.minute.toString().padLeft(2, '0')} hrs';

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: idx < ventasRecientes.length - 1
                                  ? Border(
                                      bottom: BorderSide(
                                        color: AppColors.border,
                                        width: 0.5,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.subtleGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.payments_outlined,
                                    color: AppColors.brightGreen,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Venta #$folio',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '$cantidadArticulos artículos · $hora',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\$${venta.total.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: AppColors.brightGreen,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
