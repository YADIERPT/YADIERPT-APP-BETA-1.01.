import 'package:flutter/material.dart';

import '../../Modelos/producto.dart';
import '../../Tema/app_theme.dart';

class NotificacionesStockSheet extends StatelessWidget {
  final List<Producto> productosBajoStock;

  const NotificacionesStockSheet({
    super.key,
    required this.productosBajoStock,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notificaciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (productosBajoStock.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No hay alertas de inventario en este momento.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: productosBajoStock.length,
                  itemBuilder: (context, index) {
                    final p = productosBajoStock[index];
                    return ListTile(
                      leading: Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                      ),
                      title: Text(
                        'Stock Crítico: ${p.nombre}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Quedan ${p.cantidadEnInventario} unidades.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
