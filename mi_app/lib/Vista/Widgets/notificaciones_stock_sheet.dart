import 'package:flutter/material.dart';

import '../../Modelos/producto.dart';
import '../../Tema/app_theme.dart';

/// Modal Bottom Sheet adaptativo para notificaciones y alertas de inventario.
///
/// Respeta dinámicamente el tema de la aplicación (Modo Oscuro, Claro o Sistema)
/// y permite interactuar con cada notificación para cerrar el modal y redirigir
/// al usuario a la vista de Inventario.
class NotificacionesStockSheet extends StatelessWidget {
  final List<Producto> productosBajoStock;
  final VoidCallback? onNavegarAInventario;
  final void Function(Producto producto)? onSeleccionarProducto;

  const NotificacionesStockSheet({
    super.key,
    required this.productosBajoStock,
    this.onNavegarAInventario,
    this.onSeleccionarProducto,
  });

  /// Método estático utilitario para abrir el modal de forma estandarizada.
  static Future<void> mostrar({
    required BuildContext context,
    required List<Producto> productosBajoStock,
    VoidCallback? onNavegarAInventario,
    void Function(Producto producto)? onSeleccionarProducto,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF242424) : const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => NotificacionesStockSheet(
        productosBajoStock: productosBajoStock,
        onNavegarAInventario: onNavegarAInventario,
        onSeleccionarProducto: onSeleccionarProducto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Colores dinámicos adaptados al tema actual
    final Color colorFondo = isDark ? const Color(0xFF242424) : const Color(0xFFFFFFFF);
    final Color colorFondoItem = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F5F0);
    final Color colorBordeItem = isDark ? const Color(0xFF383838) : const Color(0xFFEAE5DC);
    final Color colorTextoPrimario = isDark ? const Color(0xFFF4F4F4) : const Color(0xFF171717);
    final Color colorTextoSecundario = isDark ? const Color(0xFFA0A0A0) : const Color(0xFF737373);
    final Color colorHandle = isDark ? const Color(0xFF4A4A4A) : const Color(0xFFD6D1C7);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colorFondo,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicador de arrastre superior (Drag Handle)
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorHandle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Encabezado del modal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Notificaciones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorTextoPrimario,
                      ),
                    ),
                  ],
                ),
                if (productosBajoStock.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${productosBajoStock.length} críticas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFF3C769) : const Color(0xFF8D6200),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Contenido: Lista de alertas o estado vacío
            if (productosBajoStock.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 48,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Inventario al día',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorTextoPrimario,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No hay alertas de stock crítico en este momento.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorTextoSecundario,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: productosBajoStock.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = productosBajoStock[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          // 1. Cerrar el modal actual
                          Navigator.of(context).pop();

                          // 2. Redirigir al usuario al Inventario
                          if (onSeleccionarProducto != null) {
                            onSeleccionarProducto!(p);
                          } else if (onNavegarAInventario != null) {
                            onNavegarAInventario!();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colorFondoItem,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorBordeItem,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Icono de alerta con fondo tonal
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.warning,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Información del producto y existencias
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Stock Crítico: ${p.nombre}',
                                      style: TextStyle(
                                        color: colorTextoPrimario,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Quedan ${p.cantidadEnInventario} ${p.cantidadEnInventario == 1 ? "unidad" : "unidades"} · Toca para gestionar',
                                      style: TextStyle(
                                        color: colorTextoSecundario,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Flecha de navegación interactiva
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: colorTextoSecundario,
                              ),
                            ],
                          ),
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
