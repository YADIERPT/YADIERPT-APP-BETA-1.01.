import 'package:flutter/material.dart';

import '../../Modelos/venta.dart';
import '../../Tema/app_theme.dart';

class TarjetaHistorialVenta extends StatelessWidget {
  final Venta venta;

  const TarjetaHistorialVenta({
    super.key,
    required this.venta,
  });

  @override
  Widget build(BuildContext context) {
    final String folio = venta.id.length > 6
        ? venta.id.substring(venta.id.length - 6)
        : venta.id;
    final int totalUnidades = venta.articulos.fold(
      0,
      (sum, a) => sum + a.cantidad,
    );
    final String nombresProductos = venta.articulos.isNotEmpty
        ? venta.articulos.map((a) => a.producto.nombre).join(', ')
        : 'Venta General';
    final String hora =
        '${venta.fecha.hour.toString().padLeft(2, '0')}:${venta.fecha.minute.toString().padLeft(2, '0')} hrs';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Nombre de productos y Monto
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  nombresProductos,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+\$${venta.total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brightGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Fila intermedia: Unidades vendidas y Método de pago
          Row(
            children: [
              Text(
                '$totalUnidades ${totalUnidades == 1 ? "unidad" : "unidades"}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.subtleGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Efectivo',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brightGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Fila inferior: Usuario cajero, Hora y Folio
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Cajero: Administrador',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Folio #$folio',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                hora,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
