import 'package:flutter/material.dart';

import '../../Tema/app_theme.dart';

class ResumenInventarioHeader extends StatelessWidget {
  final int totalPlantas;
  final int stockCritico;
  final int totalSkus;
  final String filtroActivo;
  final ValueChanged<String> onFiltroSeleccionado;

  const ResumenInventarioHeader({
    super.key,
    required this.totalPlantas,
    required this.stockCritico,
    required this.totalSkus,
    required this.filtroActivo,
    required this.onFiltroSeleccionado,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3 botones de filtro interactivos: Plantas, Stock crítico y Artículos
        Row(
          children: [
            Expanded(
              child: _buildBotonFiltro(
                clave: 'plantas',
                icono: Icons.spa_outlined,
                colorIcono: AppColors.brightGreen,
                fondoIcono: AppColors.subtleGreen,
                valor: '$totalPlantas',
                etiqueta: 'Plantas',
                colorTextoValor: AppColors.textPrimary,
                seleccionado: filtroActivo == 'plantas',
                isLandscape: isLandscape,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildBotonFiltro(
                clave: 'critico',
                icono: Icons.warning_amber_rounded,
                colorIcono: AppColors.amber,
                fondoIcono: AppColors.subtleAmber,
                valor: '$stockCritico',
                etiqueta: 'Stock crítico',
                colorTextoValor: AppColors.warning,
                seleccionado: filtroActivo == 'critico',
                isLandscape: isLandscape,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildBotonFiltro(
                clave: 'articulos',
                icono: Icons.inventory_2_outlined,
                colorIcono: AppColors.turquoise,
                fondoIcono: AppColors.subtleTurquoise,
                valor: '$totalSkus',
                etiqueta: 'Artículos',
                colorTextoValor: AppColors.textPrimary,
                seleccionado: filtroActivo == 'articulos',
                isLandscape: isLandscape,
              ),
            ),
          ],
        ),
        SizedBox(height: isLandscape ? 8 : 12),

        // Panel "Sugerencias IA"
        Container(
          padding: EdgeInsets.all(isLandscape ? 8 : 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sugerencias IA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Espacio de sugerencias',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Recomendación del sistema: optimización de stock botánico disponible.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      minimumSize: const Size(60, 26),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'Descartar',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      minimumSize: const Size(60, 26),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Ver sugerencia',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBotonFiltro({
    required String clave,
    required IconData icono,
    required Color colorIcono,
    required Color fondoIcono,
    required String valor,
    required String etiqueta,
    required Color colorTextoValor,
    required bool seleccionado,
    required bool isLandscape,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onFiltroSeleccionado(clave),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(isLandscape ? 8 : 12),
          decoration: BoxDecoration(
            color: seleccionado
                ? AppColors.primaryContainer.withValues(alpha: 0.3)
                : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: seleccionado ? AppColors.primary : AppColors.border,
              width: seleccionado ? 2 : 1,
            ),
            boxShadow: seleccionado
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: fondoIcono,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icono,
                      color: colorIcono,
                      size: isLandscape ? 15 : 18,
                    ),
                  ),
                  if (seleccionado)
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                ],
              ),
              SizedBox(height: isLandscape ? 4 : 6),
              Text(
                valor,
                style: TextStyle(
                  fontSize: isLandscape ? 18 : 22,
                  fontWeight: FontWeight.w800,
                  color: colorTextoValor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isLandscape ? 10 : 11,
                  fontWeight:
                      seleccionado ? FontWeight.bold : FontWeight.w500,
                  color: seleccionado
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
