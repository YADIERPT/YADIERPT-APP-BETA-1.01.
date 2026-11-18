import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Controladores/controlador_autenticacion.dart';
import '../../Modelos/producto.dart';
import '../../Modelos/colaborador.dart';
import '../../Tema/app_theme.dart';
import '../../Utilidades/formateador.dart';
import 'miniatura_producto_widget.dart';

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
  final bool resaltado;
  final String? highlightProductId;
  final VoidCallback? onResplandorTerminado;

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
    this.resaltado = false,
    this.highlightProductId,
    this.onResplandorTerminado,
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
    final bool estaActivo = prod.activo;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool esTarjetaCompacta =
              constraints.maxWidth.isFinite && constraints.maxWidth < 260;
          final double thumbSize = esTarjetaCompacta ? 60 : 76;
          final double gapHorizontal = esTarjetaCompacta ? 8 : 12;
          final double btnEditSize = esTarjetaCompacta ? 40 : 42;

          final bool esResaltado =
              resaltado || (highlightProductId != null && prod.id == highlightProductId);
          final Color colorDestacado = isCritical
              ? AppColors.amber.withValues(alpha: 0.35)
              : AppColors.brightGreen.withValues(alpha: 0.30);
          final Color colorNormal = AppColors.card;

          return TweenAnimationBuilder<Color?>(
            key: ValueKey('resplandor_${prod.id}'),
            tween: ColorTween(
              begin: esResaltado ? colorDestacado : colorNormal,
              end: colorNormal,
            ),
            duration: const Duration(seconds: 2),
            curve: Curves.easeOutCubic,
            onEnd: () {
              if (esResaltado) {
                onResplandorTerminado?.call();
              }
            },
            builder: (context, colorAnimado, child) {
              final bool tieneResplandor =
                  esResaltado && (colorAnimado != colorNormal);
              return Container(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorAnimado ?? colorNormal,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: tieneResplandor
                        ? (isCritical ? AppColors.amber : AppColors.brightGreen)
                        : (estaActivo
                            ? AppColors.border
                            : AppColors.amber.withValues(alpha: 0.4)),
                    width: tieneResplandor ? 2.0 : 1.0,
                  ),
                  boxShadow: tieneResplandor
                      ? [
                          BoxShadow(
                            color: (isCritical
                                    ? AppColors.amber
                                    : AppColors.brightGreen)
                                .withValues(alpha: 0.28),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: AppColors.secondarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildImagenProducto(thumbSize, thumbSize),
                    ),
                    SizedBox(width: gapHorizontal),
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
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.subtleAmber,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.amber
                                            .withValues(alpha: 0.5),
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
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'DESHABILITADO',
                                              maxLines: 1,
                                              softWrap: false,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.amber,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (puedeModificar)
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: onEditar,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Tooltip(
                                      message: 'Editar producto',
                                      child: Container(
                                        width: btnEditSize,
                                        height: btnEditSize,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppColors.secondarySurface,
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                    Flexible(
                                      child: Text(
                                        '${prod.cantidadEnInventario} ${prod.esPlanta ? "plantas" : "unid."}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isCritical
                                              ? AppColors.error
                                              : AppColors.textPrimary,
                                        ),
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
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PRECIO VENTA',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        formatoMoneda(prod.precioVenta),
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (esDueno && puedeModificar) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'COSTO',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          formatoMoneda(prod.costo),
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                    estaActivo: estaActivo,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Construye los botones de acción aplicando el "Escudo del Catálogo":
  /// - [Dueño y Empleado] (Activo): Botón verde "Añadir" (Stock) y botón exclusivo "Deshabilitar" (Soft Delete).
  /// - [Dueño] (Deshabilitado): Dos botones exclusivos: "Restaurar" y "Eliminar Definitivamente".
  /// - [Empleado] (Deshabilitado): Nunca tiene acceso a "Restaurar" ni "Eliminar Definitivamente".
  Widget _buildBotonesAccion({
    required bool esDueno,
    required bool estaActivo,
  }) {
    // REGLA 1: Producto Deshabilitado (Exclusivo Dueño: Restaurar / Eliminar Definitivamente)
    if (!estaActivo) {
      if (!esDueno) {
        return const SizedBox.shrink();
      }
      return Row(
        children: [
          // Botón Exclusivo: Restaurar (activo = 1)
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: onRestaurar,
              icon: const Icon(Icons.restore, size: 16),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Restaurar',
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botón Exclusivo: Eliminar Definitivamente (Hard Delete en SQLite)
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: onEliminarDefinitivamente ?? onBorrar,
              icon: const Icon(Icons.delete_forever, size: 16),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Eliminar Definitivamente',
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ),
        ],
      );
    }

    // REGLA 2: Producto Activo (Mismo flujo operativo para Dueño y Empleado)
    // Ambos ven el botón verde "Añadir" (Stock) y la única acción destructiva permitida es "Deshabilitar".
    return Row(
      children: [
        if (puedeModificar) ...[
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: onAjustar,
              icon: const Icon(Icons.add, size: 16),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Añadir',
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: onDeshabilitar ?? onBorrar,
            icon: const Icon(Icons.visibility_off_outlined, size: 16),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Deshabilitar',
                maxLines: 1,
                softWrap: false,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          ),
        ),
      ],
    );
  }

  /// Construye la imagen del producto optimizada en memoria (Anti-OOM).
  /// Soporta URLs remotas de Supabase Storage (CachedNetworkImage), activos locales y
  /// archivos en disco decodificados a baja resolución (150px) sin bloquear el hilo UI.
  Widget _buildImagenProducto(double width, double height) {
    return MiniaturaProductoWidget(
      producto: prod,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(12),
    );
  }
}
