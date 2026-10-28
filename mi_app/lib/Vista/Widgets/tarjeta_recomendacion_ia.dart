import 'package:flutter/material.dart';

import '../../IA/Controladores/controlador_ia_compras.dart';
import '../../IA/Modelos/recomendacion_compra.dart';
import '../../Controladores/controlador_inventario.dart';
import '../../Tema/app_theme.dart';
import '../../Tema/app_svg_icons.dart';

class TarjetaRecomendacionIA extends StatelessWidget {
  final RecomendacionCompra recomendacion;
  final ControladorIACompras controladorIA;
  final ControladorInventario controladorInventario;
  final VoidCallback? onActualizado;

  const TarjetaRecomendacionIA({
    super.key,
    required this.recomendacion,
    required this.controladorIA,
    required this.controladorInventario,
    this.onActualizado,
  });

  Color _obtenerColorUrgencia() {
    switch (recomendacion.nivelUrgencia) {
      case NivelUrgencia.critico:
        return AppColors.coral;
      case NivelUrgencia.alto:
        return AppColors.amber;
      case NivelUrgencia.moderado:
        return AppColors.turquoise;
      case NivelUrgencia.bajaRotacion:
        return AppColors.textSecondary;
    }
  }

  String _obtenerSvgUrgencia() {
    switch (recomendacion.nivelUrgencia) {
      case NivelUrgencia.critico:
        return AppSvgIcons.alertaCritica;
      case NivelUrgencia.alto:
        return AppSvgIcons.alertaModerada;
      case NivelUrgencia.moderado:
        return AppSvgIcons.tendenciaAlza;
      case NivelUrgencia.bajaRotacion:
        return AppSvgIcons.bajaRotacion;
    }
  }

  void _mostrarDialogoReabastecer(BuildContext context) {
    int cantidad = recomendacion.cantidadSugerida;
    final controller = TextEditingController(text: '$cantidad');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              SvgIconWidget(
                recomendacion.esPlanta
                    ? AppSvgIcons.planta
                    : AppSvgIcons.articulo,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reabastecer ${recomendacion.nombreProducto}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La IA sugiere comprar ${recomendacion.cantidadSugerida} unidades para mantener cobertura segura.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Cantidad a ingresar al stock',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final int? ingresada = int.tryParse(controller.text);
                if (ingresada != null && ingresada > 0) {
                  final prod = controladorInventario
                      .obtenerProducto(recomendacion.productoId);
                  if (prod != null) {
                    final nuevoTotal = prod.cantidadEnInventario + ingresada;
                    await controladorInventario.actualizarExistenciasYUmbral(
                      prod.id,
                      nuevoTotal,
                      prod.umbralStockCritico,
                    );
                    await controladorIA
                        .marcarComoAplicada(recomendacion.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                    onActualizado?.call();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Inventario actualizado: +$ingresada unid. de ${recomendacion.nombreProducto}',
                          ),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Confirmar Ingreso'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorUrgencia = _obtenerColorUrgencia();
    final svgUrgencia = _obtenerSvgUrgencia();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: recomendacion.esCritico
              ? colorUrgencia.withValues(alpha: 0.5)
              : AppColors.border,
          width: recomendacion.esCritico ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabecera: Badges de Tipo y Nivel de Urgencia
          Row(
            children: [
              // Badge Urgencia
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorUrgencia.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorUrgencia.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgIconWidget(svgUrgencia, size: 12, color: colorUrgencia),
                    const SizedBox(width: 4),
                    Text(
                      recomendacion.nivelUrgencia.etiqueta.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorUrgencia,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Badge Tipo (Planta o Artículo) con SVG real
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: recomendacion.esPlanta
                      ? AppColors.subtleGreen
                      : AppColors.subtleTurquoise,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgIconWidget(
                      recomendacion.esPlanta
                          ? AppSvgIcons.planta
                          : AppSvgIcons.articulo,
                      size: 11,
                      color: recomendacion.esPlanta
                          ? AppColors.brightGreen
                          : AppColors.turquoise,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      recomendacion.esPlanta ? 'PLANTA' : 'ARTÍCULO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: recomendacion.esPlanta
                            ? AppColors.brightGreen
                            : AppColors.turquoise,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Stock actual vs Sugerido
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    children: [
                      const TextSpan(text: 'Stock: '),
                      TextSpan(
                        text: '${recomendacion.stockActual}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: recomendacion.stockActual <=
                                  recomendacion.umbralStockCritico
                              ? AppColors.coral
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Nombre del Producto & Cantidad Recomendada
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  recomendacion.nombreProducto,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (recomendacion.sugiereCompra) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgIconWidget(AppSvgIcons.carrito,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        'Comprar +${recomendacion.cantidadSugerida}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondarySurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgIconWidget(AppSvgIcons.bajaRotacion,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'No Recomprar',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // 3. Métricas Financieras (Inversión estimada, Margen, Días de Cobertura)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricaItem(
                  'Inversión Est.',
                  recomendacion.sugiereCompra
                      ? '\$${recomendacion.costoTotalEstimado.toStringAsFixed(2)}'
                      : '\$0.00',
                  AppColors.textPrimary,
                ),
                _buildSeparador(),
                _buildMetricaItem(
                  'Ganancia Est.',
                  recomendacion.sugiereCompra
                      ? '\$${recomendacion.gananciaEstimada.toStringAsFixed(2)}'
                      : '\$0.00',
                  recomendacion.sugiereCompra
                      ? AppColors.brightGreen
                      : AppColors.textSecondary,
                ),
                _buildSeparador(),
                _buildMetricaItem(
                  'Margen',
                  '${recomendacion.margenPorcentual.toStringAsFixed(0)}%',
                  AppColors.turquoise,
                ),
                _buildSeparador(),
                _buildMetricaItem(
                  'Agotamiento',
                  recomendacion.stockActual == 0
                      ? 'Agotado'
                      : (recomendacion.diasHastaAgotamiento >= 999
                          ? 'Sin salida'
                          : '~${recomendacion.diasHastaAgotamiento.toStringAsFixed(1)}d'),
                  (recomendacion.stockActual == 0 ||
                          recomendacion.diasHastaAgotamiento <= 3)
                      ? AppColors.coral
                      : AppColors.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 4. Explicación de la IA (Razonamiento Botánico)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SvgIconWidget(AppSvgIcons.iaChispas,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    recomendacion.motivoRazonado,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 5. Botones de Acción
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (recomendacion.esPendiente) ...[
                TextButton.icon(
                  onPressed: () async {
                    await controladorIA
                        .descartarRecomendacion(recomendacion.id);
                    onActualizado?.call();
                  },
                  icon: SvgIconWidget(AppSvgIcons.papelera,
                      size: 14, color: AppColors.textSecondary),
                  label: Text(
                    'Descartar',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (recomendacion.sugiereCompra) ...[
                  ElevatedButton.icon(
                    onPressed: () => _mostrarDialogoReabastecer(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: SvgIconWidget(AppSvgIcons.articulo,
                        size: 15, color: Colors.white),
                    label: const Text(
                      'Ingresar Stock',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: () => _mostrarDialogoReabastecer(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: SvgIconWidget(AppSvgIcons.articulo,
                        size: 13, color: AppColors.textSecondary),
                    label: Text(
                      'Reabastecer Opcional',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ] else ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgIconWidget(
                      recomendacion.estado == EstadoRecomendacion.aplicada
                          ? AppSvgIcons.check
                          : AppSvgIcons.papelera,
                      size: 13,
                      color: recomendacion.estado == EstadoRecomendacion.aplicada
                          ? AppColors.brightGreen
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      recomendacion.estado == EstadoRecomendacion.aplicada
                          ? 'Stock ingresado'
                          : 'Descartada',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            recomendacion.estado == EstadoRecomendacion.aplicada
                                ? AppColors.brightGreen
                                : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricaItem(String titulo, String valor, Color colorValor) {
    return Column(
      children: [
        Text(
          titulo,
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: colorValor,
          ),
        ),
      ],
    );
  }

  Widget _buildSeparador() {
    return Container(
      width: 1,
      height: 20,
      color: AppColors.border,
    );
  }
}
