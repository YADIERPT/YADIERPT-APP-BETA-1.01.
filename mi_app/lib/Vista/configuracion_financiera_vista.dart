import 'package:flutter/material.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_perfil.dart';
import '../Constantes/limites.dart';

class ConfiguracionFinancieraVista extends StatefulWidget {
  final ControladorPerfil controladorPerfil;

  const ConfiguracionFinancieraVista({
    super.key,
    required this.controladorPerfil,
  });

  @override
  State<ConfiguracionFinancieraVista> createState() =>
      _ConfiguracionFinancieraVistaState();
}

class _ConfiguracionFinancieraVistaState
    extends State<ConfiguracionFinancieraVista> {
  late bool _aplicarIva;
  late double _iva;

  @override
  void initState() {
    super.initState();
    _aplicarIva = widget.controladorPerfil.configuracion.aplicarIva;
    _iva = widget.controladorPerfil.configuracion.porcentajeIvaDefecto;
  }

  void _editarPorcentajeIva() {
    final double valorActualPorc = (_iva * 100);
    final controller = TextEditingController(
      text: valorActualPorc == valorActualPorc.roundToDouble()
          ? valorActualPorc.toInt().toString()
          : valorActualPorc.toStringAsFixed(2),
    );
    String? errorTexto;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Porcentaje de IVA',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingresa el porcentaje de IVA aplicado por defecto a las ventas (0% a ${LimitesApp.maxPorcentajeIva.toInt()}%):',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FormateadorMonetario(max: LimitesApp.maxPorcentajeIva),
                    ],
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Porcentaje de IVA',
                      suffixText: '%',
                      suffixStyle: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      errorText: errorTexto,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.secondarySurface,
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
                    final texto = controller.text.trim();
                    final valor = double.tryParse(texto);
                    if (valor == null ||
                        valor < 0 ||
                        valor > LimitesApp.maxPorcentajeIva) {
                      setDialogState(() {
                        errorTexto =
                            'Ingresa un valor entre 0 y ${LimitesApp.maxPorcentajeIva.toInt()}%';
                      });
                      return;
                    }

                    final double ivaDecimal = valor / 100.0;
                    try {
                      await widget.controladorPerfil
                          .actualizarPorcentajeIva(ivaDecimal);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        setState(() {
                          _iva = ivaDecimal;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                const Text('IVA actualizado correctamente'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() {
                        errorTexto = 'Error: $e';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        final double displayPorcentaje = _iva * 100;
        final String displayTexto =
            displayPorcentaje == displayPorcentaje.roundToDouble()
                ? '${displayPorcentaje.toInt()}%'
                : '${displayPorcentaje.toStringAsFixed(2)}%';

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            title: Text(
              'Configuración Financiera',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppColors.surface,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        'Aplicar IVA a las ventas',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Si se desactiva, los tickets no cobrarán impuestos.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      value: _aplicarIva,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) async {
                        await widget.controladorPerfil.alternarAplicarIva(val);
                        setState(() => _aplicarIva = val);
                      },
                    ),
                    Divider(height: 1, color: AppColors.border),
                    ListTile(
                      title: Text(
                        'Porcentaje de IVA actual: $displayTexto',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Toca para editar el porcentaje del impuesto estándar.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing:
                          Icon(Icons.edit_outlined, color: AppColors.primary),
                      onTap: _editarPorcentajeIva,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
