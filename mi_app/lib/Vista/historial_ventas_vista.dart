import 'package:flutter/material.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_ventas.dart';

class HistorialVentasVista extends StatelessWidget {
  final ControladorVentas controladorVentas;

  const HistorialVentasVista({super.key, required this.controladorVentas});

  @override
  Widget build(BuildContext context) {
    final ventas = controladorVentas.ventas.reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Historial de Ventas'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
      ),
      body: ventas.isEmpty
          ? const Center(child: Text('No hay ventas registradas.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ventas.length,
              itemBuilder: (context, index) {
                final v = ventas[index];
                return Card(
                  color: AppColors.surfaceContainerLowest,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.outlineVariant),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.receipt_long,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Ticket: ${v.id}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${v.articulos.length} articulos - ${v.fecha.toString().substring(0, 16)}',
                    ),
                    trailing: Text(
                      '\$${v.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
