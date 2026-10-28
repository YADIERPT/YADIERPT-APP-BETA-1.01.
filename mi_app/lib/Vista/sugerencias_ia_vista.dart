import 'package:flutter/material.dart';

import '../IA/Controladores/controlador_ia_compras.dart';
import '../IA/Modelos/recomendacion_compra.dart';
import '../Controladores/controlador_inventario.dart';
import '../Controladores/controlador_ventas.dart';
import '../Tema/app_theme.dart';
import '../Tema/app_svg_icons.dart';
import 'Widgets/tarjeta_recomendacion_ia.dart';

class SugerenciasIAVista extends StatefulWidget {
  final ControladorIACompras controladorIA;
  final ControladorInventario controladorInventario;
  final ControladorVentas controladorVentas;

  const SugerenciasIAVista({
    super.key,
    required this.controladorIA,
    required this.controladorInventario,
    required this.controladorVentas,
  });

  @override
  State<SugerenciasIAVista> createState() => _SugerenciasIAVistaState();
}

class _SugerenciasIAVistaState extends State<SugerenciasIAVista> {
  String _filtroSeleccionado = 'todos'; // 'todos', 'criticos', 'plantas', 'articulos', 'descartadas'

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controladorIA, ThemeManager.instance]),
      builder: (context, _) {
        final ia = widget.controladorIA;
        final bool cargando = ia.cargando;

        List<RecomendacionCompra> lista = ia.recomendaciones;

        // Filtrar lista de forma congruente
        if (_filtroSeleccionado == 'criticos') {
          lista = lista
              .where((r) =>
                  r.esCritico &&
                  r.estado == EstadoRecomendacion.pendiente &&
                  r.sugiereCompra)
              .toList();
        } else if (_filtroSeleccionado == 'plantas') {
          lista = lista
              .where((r) =>
                  r.esPlanta &&
                  r.estado == EstadoRecomendacion.pendiente &&
                  r.sugiereCompra)
              .toList();
        } else if (_filtroSeleccionado == 'articulos') {
          lista = lista
              .where((r) =>
                  !r.esPlanta &&
                  r.estado == EstadoRecomendacion.pendiente &&
                  r.sugiereCompra)
              .toList();
        } else if (_filtroSeleccionado == 'bajaRotacion') {
          lista = lista
              .where((r) =>
                  !r.sugiereCompra && r.estado == EstadoRecomendacion.pendiente)
              .toList();
        } else if (_filtroSeleccionado == 'descartadas') {
          lista = lista
              .where((r) => r.estado == EstadoRecomendacion.descartada)
              .toList();
        } else {
          // 'todos' (solo pendientes)
          lista = lista
              .where((r) => r.estado == EstadoRecomendacion.pendiente)
              .toList();
        }

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new,
                  size: 18, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SvgIconWidget(AppSvgIcons.iaChispas,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Sugerencias de Compra IA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Calibración adaptativa en local para viveros',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Recalibrar con ventas históricas',
                icon: cargando
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(Icons.refresh, color: AppColors.primary),
                onPressed: cargando
                    ? null
                    : () async {
                        await ia.ejecutarCalibracionCompleta(
                          widget.controladorVentas.ventas,
                          horizonteDias: ia.horizonteReposicionDias,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                '✓ IA recalibrada con éxito con las últimas ventas',
                              ),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        }
                      },
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Tarjetas de Resumen Financiero Inteligente
                _buildResumenTarjetas(ia),
                const SizedBox(height: 16),

                // 2. Selector Adaptativo de Tiempo de Abastecimiento (Lead Time)
                _buildSelectorLeadTime(ia),
                const SizedBox(height: 16),

                // 3. Filtros Rápidos
                _buildChipsFiltro(ia),
                const SizedBox(height: 14),

                // 4. Encabezado de Lista
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recomendaciones Calculadas (${lista.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (ia.ultimaCalibracion != null)
                      Text(
                        'Actualizado: ${_formatearHora(ia.ultimaCalibracion!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // 5. Lista de Recomendaciones
                if (cargando) ...[
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ] else if (lista.isEmpty) ...[
                  _buildEstadoVacio(),
                ] else ...[
                  ...lista.map(
                    (rec) => TarjetaRecomendacionIA(
                      recomendacion: rec,
                      controladorIA: widget.controladorIA,
                      controladorInventario: widget.controladorInventario,
                      onActualizado: () => setState(() {}),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResumenTarjetas(ControladorIACompras ia) {
    return Row(
      children: [
        Expanded(
          child: _buildTarjetaKpi(
            titulo: 'Inversión Sugerida',
            valor: '\$${ia.inversionTotalEstimada.toStringAsFixed(2)}',
            svgIcono: AppSvgIcons.monedas,
            color: AppColors.primary,
            fondo: AppColors.primaryContainer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTarjetaKpi(
            titulo: 'Ganancia Est.',
            valor: '\$${ia.gananciaProyectadaTotal.toStringAsFixed(2)}',
            svgIcono: AppSvgIcons.tendenciaAlza,
            color: AppColors.brightGreen,
            fondo: AppColors.subtleGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTarjetaKpi(
            titulo: 'Críticos',
            valor: '${ia.totalCriticos}',
            svgIcono: AppSvgIcons.alertaCritica,
            color: AppColors.coral,
            fondo: AppColors.subtleAmber,
          ),
        ),
      ],
    );
  }

  Widget _buildTarjetaKpi({
    required String titulo,
    required String valor,
    required String svgIcono,
    required Color color,
    required Color fondo,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: fondo,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SvgIconWidget(svgIcono, size: 14, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorLeadTime(ControladorIACompras ia) {
    final opciones = [7, 14, 21, 30];

    return Container(
      padding: const EdgeInsets.all(12),
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
              SvgIconWidget(AppSvgIcons.camionEnvio,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Tiempo de llegada del proveedor (Lead Time)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'En viveros el abastecimiento varía por temporadas y tipo de planta. Ajusta el plazo estimado para recalibrar el stock de seguridad:',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: opciones.map((dias) {
              final seleccionado = ia.horizonteReposicionDias == dias;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(
                      '$dias días',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                        color: seleccionado ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    selected: seleccionado,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.secondarySurface,
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    onSelected: (val) {
                      if (val) {
                        ia.cambiarHorizonteReposicion(
                          dias,
                          widget.controladorVentas.ventas,
                        );
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChipsFiltro(ControladorIACompras ia) {
    final int noRecomprar =
        ia.recomendacionesActivas.where((r) => !r.sugiereCompra).length;

    final filtros = [
      {
        'clave': 'todos',
        'label': 'Todos (${ia.recomendacionesActivas.length})',
        'svg': AppSvgIcons.iaChispas,
      },
      {
        'clave': 'criticos',
        'label': 'Críticos (${ia.totalCriticos})',
        'svg': AppSvgIcons.alertaCritica,
      },
      {
        'clave': 'plantas',
        'label': 'Plantas (${ia.totalPlantasRecomendadas})',
        'svg': AppSvgIcons.planta,
      },
      {
        'clave': 'articulos',
        'label': 'Artículos (${ia.totalArticulosRecomendados})',
        'svg': AppSvgIcons.articulo,
      },
      if (noRecomprar > 0)
        {
          'clave': 'bajaRotacion',
          'label': 'No Recomprar ($noRecomprar)',
          'svg': AppSvgIcons.bajaRotacion,
        },
      {
        'clave': 'descartadas',
        'label': 'Descartados',
        'svg': AppSvgIcons.papelera,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filtros.map((f) {
          final clave = f['clave'] as String;
          final label = f['label'] as String;
          final svg = f['svg'] as String;
          final seleccionado = _filtroSeleccionado == clave;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              avatar: SvgIconWidget(
                svg,
                size: 13,
                color: seleccionado ? Colors.white : AppColors.textSecondary,
              ),
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                  color: seleccionado ? Colors.white : AppColors.textPrimary,
                ),
              ),
              selected: seleccionado,
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.secondarySurface,
              showCheckmark: false,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _filtroSeleccionado = clave;
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          SvgIconWidget(AppSvgIcons.planta, size: 48, color: AppColors.brightGreen),
          const SizedBox(height: 12),
          Text(
            'Inventario en equilibrio botánico',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No hay productos en riesgo de desabasto para el horizonte seleccionado. Las ventas registradas están respaldadas con stock suficiente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatearHora(DateTime fecha) {
    final h = fecha.hour.toString().padLeft(2, '0');
    final m = fecha.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
