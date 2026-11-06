import 'dart:io';
import 'package:flutter/material.dart';

import '../../Modelos/producto.dart';
import '../../Modelos/colaborador.dart';
import '../../Tema/app_theme.dart';
import 'role_guard.dart';

class TarjetaProductoInventario extends StatelessWidget {
  final Producto prod;
  final VoidCallback onEditar;
  final VoidCallback onAjustar;
  final VoidCallback onBorrar;
  final bool puedeModificar;
  final RolUsuario? rolActual;

  const TarjetaProductoInventario({
    super.key,
    required this.prod,
    required this.onEditar,
    required this.onAjustar,
    required this.onBorrar,
    this.puedeModificar = true,
    this.rolActual,
  });

  bool get _estaAutorizadoModificar =>
      puedeModificar && (rolActual?.puedeModificarInventario ?? true);

  @override
  Widget build(BuildContext context) {
    final bool isCritical = prod.esStockCritico;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: prod.imagenes.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: prod.imagenes.first.startsWith('http')
                            ? Image.network(
                                prod.imagenes.first,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Icon(
                                  prod.esPlanta
                                      ? Icons.spa_outlined
                                      : Icons.inventory_2_outlined,
                                  color: AppColors.primary,
                                  size: 32,
                                ),
                              )
                            : Image.file(
                                File(prod.imagenes.first),
                                fit: BoxFit.cover,
                              ),
                      )
                    : Icon(
                        prod.esPlanta
                            ? Icons.spa_outlined
                            : Icons.inventory_2_outlined,
                        color: AppColors.primary,
                        size: 32,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            prod.nombre,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (_estaAutorizadoModificar)
                          RoleGuard.gerencia(
                            rolActual: rolActual,
                            modo: RoleGuardMode.ocultar,
                            child: GestureDetector(
                              onTap: onEditar,
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: prod.esPlanta
                                ? AppColors.subtleGreen
                                : AppColors.subtleTurquoise,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            prod.tipo.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: prod.esPlanta
                                  ? AppColors.brightGreen
                                  : AppColors.turquoise,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isCritical
                                ? AppColors.subtleCoral
                                : AppColors.secondarySurface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isCritical
                                  ? AppColors.error
                                  : AppColors.border,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCritical
                                    ? Icons.warning_amber_rounded
                                    : Icons.inventory_2_outlined,
                                size: 10,
                                color: isCritical
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${prod.cantidadEnInventario} ${prod.esPlanta ? "plantas" : "unid."}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isCritical
                                      ? AppColors.error
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PRECIO VENTA',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '\$${prod.precioVenta.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (_estaAutorizadoModificar)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'COSTO',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '\$${prod.costo.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (prod.notas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.secondarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                prod.notas,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (_estaAutorizadoModificar)
            RoleGuard.gerencia(
              rolActual: rolActual,
              modo: RoleGuardMode.ocultar,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: onAjustar,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Añadir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        onPressed: onBorrar,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 16,
                        ),
                        label: const Text('Borrar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
