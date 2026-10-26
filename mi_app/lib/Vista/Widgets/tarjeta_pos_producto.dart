import 'dart:io';
import 'package:flutter/material.dart';

import '../../Modelos/producto.dart';
import '../../Tema/app_theme.dart';

class TarjetaPosProducto extends StatelessWidget {
  final Producto producto;
  final int cantidadEnTicket;
  final VoidCallback onAgregar;
  final VoidCallback onIncrementar;
  final VoidCallback onDecrementar;
  final VoidCallback onSinUnidades;

  const TarjetaPosProducto({
    super.key,
    required this.producto,
    required this.cantidadEnTicket,
    required this.onAgregar,
    required this.onIncrementar,
    required this.onDecrementar,
    required this.onSinUnidades,
  });

  @override
  Widget build(BuildContext context) {
    final bool enTicket = cantidadEnTicket > 0;
    final bool sinUnidades = producto.cantidadEnInventario == 0;

    return GestureDetector(
      onTap: () {
        if (sinUnidades) {
          onSinUnidades();
          return;
        }
        onAgregar();
      },
      child: Opacity(
        opacity: sinUnidades ? 0.65 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enTicket ? AppColors.brightGreen : AppColors.border,
              width: enTicket ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.secondarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: producto.imagenes.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: producto.imagenes.first.startsWith('http')
                                  ? Image.network(
                                      producto.imagenes.first,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Icon(
                                        Icons.local_florist,
                                        size: 36,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : Image.file(
                                      File(producto.imagenes.first),
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Icon(
                                        Icons.local_florist,
                                        size: 36,
                                        color: AppColors.primary,
                                      ),
                                    ),
                            )
                          : Icon(
                              Icons.local_florist,
                              size: 36,
                              color: AppColors.primary,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    producto.nombre,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    producto.notas.isNotEmpty ? producto.notas : 'Planta natural',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '\$${producto.precioVenta.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppColors.brightGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (sinUnidades)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.subtleCoral,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Sin unidades',
                                style: TextStyle(
                                  color: AppColors.coral,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          '${producto.cantidadEnInventario} u.',
                          style: TextStyle(
                            color: producto.esStockCritico
                                ? AppColors.amber
                                : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (enTicket)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onDecrementar,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '$cantidadEnTicket',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onIncrementar,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
