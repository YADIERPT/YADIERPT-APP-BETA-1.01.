import 'package:flutter/material.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_perfil.dart';
import 'historial_ventas_vista.dart';
import 'empleados_vista.dart';
import 'configuracion_financiera_vista.dart';
import 'seguridad_vista.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_autenticacion.dart';

class PerfilVista extends StatelessWidget {
  final ControladorPerfil controladorPerfil;
  final ControladorVentas controladorVentas;
  final ControladorAutenticacion controladorAutenticacion;
  final VoidCallback onLogout;

  const PerfilVista({
    super.key,
    required this.controladorPerfil,
    required this.controladorVentas,
    required this.controladorAutenticacion,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Profile Header
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                ),
                child: const Icon(
                  Icons.person,
                  size: 50,
                  color: AppColors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Administrador',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const Text(
                'Vivero Principal',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // Settings Sections
              _buildSectionTitle('Preferencias'),
              _buildListTile(
                Icons.dark_mode_outlined,
                'Tema Visual',
                'Claro / Oscuro (Automatico)',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text(
                        'Tema Automático',
                        style: TextStyle(color: AppColors.primary),
                      ),
                      content: const Text(
                        'ViverApp respeta la configuracion de color de tu sistema operativo. Si cambias el modo oscuro en los ajustes de tu celular, la app se actualizara de inmediato.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Entendido',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _buildListTile(
                Icons.notifications_active_outlined,
                'Alertas y Notificaciones',
                'Configurar alertas de stock',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text(
                        'Alertas de Stock',
                        style: TextStyle(color: AppColors.primary),
                      ),
                      content: const Text(
                        'El sistema actual te alerta automaticamente y muestra un punto rojo cuando cualquier producto en el inventario baja a 5 unidades o menos.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Aceptar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Negocio'),
              _buildListTile(
                Icons.storefront_outlined,
                'Configuracion Financiera',
                'IVA y Tipos de cambio',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConfiguracionFinancieraVista(
                      controladorPerfil: controladorPerfil,
                    ),
                  ),
                ),
              ),
              _buildListTile(
                Icons.people_outline,
                'Empleados',
                'Gestionar perfiles y permisos',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmpleadosVista(
                      controladorAutenticacion: controladorAutenticacion,
                    ),
                  ),
                ),
              ),
              _buildListTile(
                Icons.receipt_long_outlined,
                'Historial de Ventas',
                'Ver reporte de ingresos',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HistorialVentasVista(
                      controladorVentas: controladorVentas,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('Cuenta'),
              _buildListTile(
                Icons.security_outlined,
                'Seguridad',
                'Cambiar contrasena y PIN',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SeguridadVista(
                      controladorAutenticacion: controladorAutenticacion,
                    ),
                  ),
                ),
              ),
              _buildListTile(
                Icons.help_outline,
                'Soporte y Ayuda',
                'Acerca de ViverApp',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text(
                        'Soporte ViverApp',
                        style: TextStyle(color: AppColors.primary),
                      ),
                      content: const Text(
                        'ViverApp POS\nVersion: 1.1.0\n\nSi experimentas problemas, requieres restaurar datos o necesitas nuevas funciones, por favor contacta al desarrollador de tu sistema.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Cerrar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text(
                    'Cerrar Sesion',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cerrar Sesion'),
                        content: const Text(
                          '¿Estas seguro que deseas cerrar sesion?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onLogout();
                            },
                            child: const Text(
                              'Cerrar Sesion',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceContainerHigh, width: 1),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColors.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.outlineVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}
