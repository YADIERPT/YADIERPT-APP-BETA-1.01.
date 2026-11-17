import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Controladores/controlador_sincronizacion.dart';
import '../../Tema/app_theme.dart';

/// Widget para la barra de navegación superior que refleja el estado de la sincronización en la nube.
class IndicadorSincronizacion extends StatelessWidget {
  final VoidCallback? onTapOverride;

  const IndicadorSincronizacion({super.key, this.onTapOverride});

  @override
  Widget build(BuildContext context) {
    ControladorSincronizacion? controlador;
    try {
      controlador = Provider.of<ControladorSincronizacion?>(context);
    } catch (_) {}
    if (controlador == null) {
      try {
        controlador = Provider.of<ControladorSincronizacion>(context, listen: true);
      } catch (_) {
        controlador = null;
      }
    }

    if (controlador == null) {
      return const SizedBox.shrink();
    }

    return _construirContenido(context, controlador);
  }

  Widget _construirContenido(
    BuildContext context,
    ControladorSincronizacion controlador,
  ) {
    final estado = controlador.estadoUI;

    if (estado == EstadoSincronizacionUI.modoLocalPuro) {
      return const SizedBox.shrink(); // En modo local puro no satura la barra de acciones
    }

    Widget icono;
    String tooltip;

    if (!controlador.syncHabilitada) {
      icono = Icon(
        Icons.cloud_off_outlined,
        color: AppColors.textSecondary,
        size: 20,
      );
      tooltip = 'Sincronización automática en pausa (desactivada en ajustes)';
    } else {
      switch (estado) {
        case EstadoSincronizacionUI.sincronizando:
          icono = SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brightGreen),
            ),
          );
          tooltip = 'Sincronizando con la nube...';
          break;

        case EstadoSincronizacionUI.sinConexion:
          icono = Icon(
            Icons.cloud_off_rounded,
            color: AppColors.textSecondary,
            size: 20,
          );
          tooltip = 'Sin conexión a internet (operando 100% offline)';
          break;

        case EstadoSincronizacionUI.error:
          icono = Icon(
            Icons.cloud_sync_rounded,
            color: AppColors.amber,
            size: 20,
          );
          tooltip =
              'Aviso de sincronización: ${controlador.ultimoError ?? "reintentando"}';
          break;

        case EstadoSincronizacionUI.pendiente:
          icono = Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.coral,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text(
                    '${controlador.cambiosPendientes}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          );
          tooltip =
              '${controlador.cambiosPendientes} cambios locales pendientes de subir';
          break;

        case EstadoSincronizacionUI.sincronizado:
        default:
          icono = Icon(
            Icons.cloud_done_rounded,
            color: AppColors.brightGreen,
            size: 20,
          );
          tooltip = 'Sincronizado con Supabase';
          break;
      }
    }

    return IconButton(
      key: const ValueKey('boton_indicador_sincronizacion'),
      icon: icono,
      tooltip: tooltip,
      splashRadius: 20,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () {
        if (onTapOverride != null) {
          onTapOverride!();
          return;
        }

        controlador.sincronizarManual();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tooltip),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}
