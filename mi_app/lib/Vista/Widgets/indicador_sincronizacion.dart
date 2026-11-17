import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Controladores/controlador_sincronizacion.dart';

/// Widget para la barra de navegación superior que refleja el estado de la sincronización en la nube.
class IndicadorSincronizacion extends StatelessWidget {
  const IndicadorSincronizacion({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ControladorSincronizacion>(
      builder: (context, controlador, _) {
        final estado = controlador.estadoUI;

        if (estado == EstadoSincronizacionUI.modoLocalPuro) {
          return const SizedBox.shrink(); // En modo local puro no satura la barra de acciones
        }

        Widget icono;
        String tooltip;

        switch (estado) {
          case EstadoSincronizacionUI.sincronizando:
            icono = const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            );
            tooltip = 'Sincronizando con la nube...';
            break;

          case EstadoSincronizacionUI.sinConexion:
            icono = const Icon(
              Icons.cloud_off_rounded,
              color: Colors.grey,
              size: 22,
            );
            tooltip = 'Sin conexión a internet (operando 100% offline)';
            break;

          case EstadoSincronizacionUI.error:
            icono = const Icon(
              Icons.cloud_sync_rounded,
              color: Colors.amber,
              size: 22,
            );
            tooltip = 'Aviso de sincronización: ${controlador.ultimoError ?? "reintentando"}';
            break;

          case EstadoSincronizacionUI.pendiente:
            icono = Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  color: Colors.blueAccent,
                  size: 22,
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
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
            tooltip = '${controlador.cambiosPendientes} cambios locales pendientes de subir';
            break;

          case EstadoSincronizacionUI.sincronizado:
          default:
            icono = const Icon(
              Icons.cloud_done_rounded,
              color: Color(0xFF2E7D32), // Verde botánico
              size: 22,
            );
            tooltip = 'Sincronizado con Supabase';
            break;
        }

        return IconButton(
          icon: icono,
          tooltip: tooltip,
          splashRadius: 20,
          onPressed: () {
            controlador.sincronizarManual();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tooltip),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
    );
  }
}
