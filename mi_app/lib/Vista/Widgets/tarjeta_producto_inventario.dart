import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Controladores/controlador_autenticacion.dart';
import '../../Modelos/producto.dart';
import '../../Modelos/colaborador.dart';
import '../../Tema/app_theme.dart';
import '../../Tema/app_svg_icons.dart';

class TarjetaProductoInventario extends StatelessWidget {
  final Producto prod;
  final VoidCallback onEditar;
  final VoidCallback onAjustar;
  final VoidCallback onBorrar;
  final VoidCallback? onDeshabilitar;
  final VoidCallback? onRestaurar;
  final VoidCallback? onEliminarDefinitivamente;
  final bool puedeModificar;
  final RolUsuario? rolActual;

  const TarjetaProductoInventario({
    super.key,
    required this.prod,
    required this.onEditar,
    required this.onAjustar,
    required this.onBorrar,
    this.onDeshabilitar,
    this.onRestaurar,
    this.onEliminarDefinitivamente,
    this.puedeModificar = true,
    this.rolActual,
  });

  RolUsuario _obtenerRol(BuildContext context) {
    if (rolActual != null) return rolActual!;
    try {
      return context.read<ControladorAutenticacion>().usuarioActual?.rol ??
          RolUsuario.empleado;
    } catch (_) {
      return RolUsuario.empleado;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCritical = prod.esStockCritico;
    final RolUsuario rol = _obtenerRol(context);
    final bool esDueno = rol.esDuena || rol.esDueno;
    final bool esEmpleado = rol.esEmpleado;
    final bool estaActivo = prod.activo;

    return RepaintBoundary(
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: estaActivo ? AppColors.border : AppColors.amber.withValues(alpha: 0.4),
            width: 1,
          ),
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
                  child: _buildImagenProducto(76, 76),
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
                                color: estaActivo
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!estaActivo)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.subtleAmber,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.amber.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility_off_outlined,
                                    size: 13,
                                    color: AppColors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'DESHABILITADO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.amber,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (esDueno && puedeModificar)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onEditar,
                                borderRadius: BorderRadius.circular(8),
                                child: Tooltip(
                                  message: 'Editar producto',
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.secondarySurface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.border,
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
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
                          if (esDueno && puedeModificar)
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

            // Fila de Botones Condicionales ("Escudo del Catálogo" y Roles)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _buildBotonesAccion(
                esDueno: esDueno,
                esEmpleado: esEmpleado,
                estaActivo: estaActivo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye los botones de acción aplicando estrictamente la regla "Escudo del Catálogo":
  /// - [Empleado]: Solo opción "Deshabilitar" (Soft Delete). No ve deshabilitados ni borra físico.
  /// - [Dueño] (Activo): "Añadir" existencias y "Deshabilitar".
  /// - [Dueño] (Deshabilitado): Dos botones exclusivos: "Restaurar" y "Eliminar Definitivamente".
  Widget _buildBotonesAccion({
    required bool esDueno,
    required bool esEmpleado,
    required bool estaActivo,
  }) {
    // REGLA 1: Producto Deshabilitado (Solo accesible por el Dueño)
    if (!estaActivo && esDueno) {
      return Row(
        children: [
          // Botón Exclusivo: Restaurar (activo = 1)
          Expanded(
            flex: 1,
            child: ElevatedButton.icon(
              onPressed: onRestaurar,
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('Restaurar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botón Exclusivo: Eliminar Definitivamente (Hard Delete en SQLite)
          Expanded(
            flex: 1,
            child: ElevatedButton.icon(
              onPressed: onEliminarDefinitivamente ?? onBorrar,
              icon: const Icon(Icons.delete_forever, size: 16),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Eliminar Definitivamente'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        ],
      );
    }

    // REGLA 2: Si el rol es 'empleado', SOLO debe mostrar la opción "Deshabilitar" (Soft Delete)
    if (esEmpleado) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onDeshabilitar ?? onBorrar,
          icon: const Icon(Icons.visibility_off_outlined, size: 16),
          label: const Text('Deshabilitar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.amber,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    // REGLA 3: Dueño con producto activo (Añadir Stock + Deshabilitar)
    return Row(
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
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: onDeshabilitar ?? onBorrar,
            icon: const Icon(Icons.visibility_off_outlined, size: 16),
            label: const Text('Deshabilitar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        ),
      ],
    );
  }

  /// Construye la imagen del producto 100% offline.
  /// Soporta rutas locales de assets ('assets/...') o archivos guardados en el dispositivo ('/data/...').
  /// En caso de no existir o fallar, renderiza un ícono botánico SVG nativo sin requerir internet.
  Widget _buildImagenProducto(double width, double height) {
    if (prod.imagenes.isNotEmpty && prod.imagenes.first.trim().isNotEmpty) {
      final imgPath = prod.imagenes.first.trim();
      if (imgPath.startsWith('assets/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            imgPath,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(),
          ),
        );
      } else {
        final file = File(imgPath);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(),
          ),
        );
      }
    }
    return _buildPlaceholderIcon();
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: SvgIconWidget(
        prod.esPlanta ? AppSvgIcons.planta : AppSvgIcons.articulo,
        size: 32,
        color: AppColors.primary,
      ),
    );
  }
}
