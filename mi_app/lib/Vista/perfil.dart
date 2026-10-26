import 'package:flutter/material.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_perfil.dart';
import 'historial_ventas_vista.dart';
import 'empleados_vista.dart';
import 'configuracion_financiera_vista.dart';
import 'seguridad_vista.dart';
import 'configuracion_biometrica_vista.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_autenticacion.dart';
import '../Controladores/controlador_biometrico.dart';

class PerfilVista extends StatefulWidget {
  final ControladorPerfil controladorPerfil;
  final ControladorVentas controladorVentas;
  final ControladorAutenticacion controladorAutenticacion;
  final ControladorBiometrico? controladorBiometrico;
  final VoidCallback onLogout;

  const PerfilVista({
    super.key,
    required this.controladorPerfil,
    required this.controladorVentas,
    required this.controladorAutenticacion,
    this.controladorBiometrico,
    required this.onLogout,
  });

  @override
  State<PerfilVista> createState() => _PerfilVistaState();
}

class _PerfilVistaState extends State<PerfilVista> {
  String _obtenerTextoTema(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
      case ThemeMode.system:
        return 'Automático (Sistema)';
    }
  }

  void _mostrarDialogoTema() {
    ThemeMode modoSeleccionado = ThemeManager.instance.themeMode;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Tema Visual',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: RadioGroup<ThemeMode>(
                groupValue: modoSeleccionado,
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => modoSeleccionado = val);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      activeColor: AppColors.primary,
                      title: Text(
                        'Claro',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      activeColor: AppColors.primary,
                      title: Text(
                        'Oscuro',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      activeColor: AppColors.primary,
                      title: Text(
                        'Automático (Sistema)',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
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
                    await ThemeManager.instance.setThemeMode(modoSeleccionado);
                    if (mounted) setState(() {});
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Guardar cambios'),
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
        final usuario = widget.controladorAutenticacion.usuarioActual;
        final nombreUsuario = usuario?.nombre ?? 'Administrador';
        final rolUsuario = usuario != null
            ? (usuario.rol == 'admin' ? 'Administrador' : 'Colaborador')
            : 'Administrador';

        return Scaffold(
          backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              // Profile Header
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2.5),
                ),
                child: Icon(
                  Icons.person,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                nombreUsuario,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$rolUsuario · Vivero Principal',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Settings Sections
              _buildSectionTitle('Preferencias'),
              _buildListTile(
                Icons.dark_mode_outlined,
                'Tema Visual',
                _obtenerTextoTema(ThemeManager.instance.themeMode),
                iconBgColor: AppColors.subtleTurquoise,
                iconColor: AppColors.turquoise,
                onTap: _mostrarDialogoTema,
              ),
              _buildListTile(
                Icons.notifications_active_outlined,
                'Alertas y Notificaciones',
                'Configurar alertas de stock',
                iconBgColor: AppColors.subtleAmber,
                iconColor: AppColors.amber,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        'Alertas de Stock',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Text(
                        'El sistema te alerta automáticamente cuando un producto baja a su umbral de stock crítico configurado (por defecto 5 unidades o menos). Puedes personalizar el umbral de cada planta desde el botón Añadir en Inventario.',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Aceptar'),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('Negocio'),
              _buildListTile(
                Icons.storefront_outlined,
                'Configuración Financiera',
                'IVA y Parámetros fiscales',
                iconBgColor: AppColors.subtleGreen,
                iconColor: AppColors.brightGreen,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConfiguracionFinancieraVista(
                      controladorPerfil: widget.controladorPerfil,
                    ),
                  ),
                ),
              ),
              _buildListTile(
                Icons.people_outline,
                'Empleados',
                'Gestionar perfiles y permisos',
                iconBgColor: AppColors.subtleTurquoise,
                iconColor: AppColors.turquoise,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmpleadosVista(
                      controladorAutenticacion: widget.controladorAutenticacion,
                    ),
                  ),
                ),
              ),
              _buildListTile(
                Icons.receipt_long_outlined,
                'Historial de Ventas',
                'Ver reporte de operaciones',
                iconBgColor: AppColors.subtleGreen,
                iconColor: AppColors.brightGreen,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HistorialVentasVista(
                      controladorVentas: widget.controladorVentas,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('Cuenta y Acceso'),
              _buildListTile(
                Icons.fingerprint,
                'Lector de Huellas y Biometría',
                (widget.controladorBiometrico?.tieneHuellaRegistrada ?? false)
                    ? 'Huella activa · ${widget.controladorBiometrico!.config.tipoConexion.toUpperCase()}'
                    : 'Configurar huella, WiFi, Bluetooth o Cable',
                iconBgColor: AppColors.subtleGreen,
                iconColor: AppColors.brightGreen,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConfiguracionBiometricaVista(
                      controladorBiometrico: widget.controladorBiometrico ??
                          ControladorBiometrico(),
                      controladorAutenticacion: widget.controladorAutenticacion,
                    ),
                  ),
                ).then((_) => setState(() {})),
              ),
              _buildListTile(
                Icons.security_outlined,
                'Seguridad',
                'Cambiar contraseña y PIN',
                iconBgColor: AppColors.subtleAmber,
                iconColor: AppColors.amber,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SeguridadVista(
                      controladorAutenticacion: widget.controladorAutenticacion,
                    ),
                  ),
                ),
              ),
              _buildListTile(
                Icons.help_outline,
                'Soporte y Ayuda',
                'Acerca de Planteapp / Vivero',
                iconBgColor: AppColors.subtleTurquoise,
                iconColor: AppColors.turquoise,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        'Soporte ViverApp',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Text(
                        'Planteapp POS\nVersión: 2.0\n\nSistema punto de venta e inventario botánico.',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            'Cerrar',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout, color: AppColors.error),
                  label: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 15,
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
                        backgroundColor: AppColors.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Text(
                          'Cerrar Sesión',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        content: Text(
                          '¿Estás seguro que deseas cerrar sesión?',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              widget.onLogout();
                            },
                            child: const Text(
                              'Cerrar Sesión',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  },
);
}

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
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
    Color? iconBgColor,
    Color? iconColor,
  }) {
    final Color bg = iconBgColor ?? AppColors.subtleGreen;
    final Color fg = iconColor ?? AppColors.brightGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: fg, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}
