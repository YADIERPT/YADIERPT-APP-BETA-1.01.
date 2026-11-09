import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_perfil.dart';
import 'historial_ventas_vista.dart';
import 'deudores_vista.dart';
import 'empleados_vista.dart';
import 'configuracion_financiera_vista.dart';
import 'seguridad_acceso_vista.dart';
import 'hardware_vista.dart';
import 'seguridad_vista.dart';
import 'configuracion_biometrica_vista.dart';
import 'Widgets/verificacion_seguridad_sheet.dart';
import 'Widgets/role_guard.dart';
import 'Widgets/app_logo.dart';
import 'Widgets/logo_biznaga.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_autenticacion.dart';
import '../Controladores/controlador_biometrico.dart';

class PerfilVista extends StatefulWidget {
  final VoidCallback onLogout;

  const PerfilVista({
    super.key,
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
    final cAuth = context.watch<ControladorAutenticacion>();
    final cBiometrico = context.watch<ControladorBiometrico>();

    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        final usuario = cAuth.usuarioActual;
        final nombreUsuario = usuario?.nombre ?? 'Administrador';
        final rolUsuario = usuario?.rol.etiqueta ?? 'Administrador';

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: AppColors.surface,
          floatingActionButton: null,
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
              // [SOLICITUD TÉCNICA]: Apartado de Alertas y Notificaciones ocultado/desactivado
              // _buildListTile(
              //   Icons.notifications_active_outlined,
              //   'Alertas y Notificaciones',
              //   'Configurar alertas de stock',
              //   iconBgColor: AppColors.subtleAmber,
              //   iconColor: AppColors.amber,
              //   onTap: () {
              //     showDialog(
              //       context: context,
              //       builder: (ctx) => AlertDialog(
              //         backgroundColor: AppColors.card,
              //         shape: RoundedRectangleBorder(
              //           borderRadius: BorderRadius.circular(16),
              //         ),
              //         title: Text(
              //           'Alertas de Stock',
              //           style: TextStyle(
              //             color: AppColors.primary,
              //             fontWeight: FontWeight.bold,
              //           ),
              //         ),
              //         content: Text(
              //           'El sistema te alerta automáticamente cuando un producto baja a su umbral de stock crítico configurado (por defecto 5 unidades o menos). Puedes personalizar el umbral de cada planta desde el botón Añadir en Inventario.',
              //           style: TextStyle(color: AppColors.textPrimary),
              //         ),
              //         actions: [
              //           ElevatedButton(
              //             onPressed: () => Navigator.pop(ctx),
              //             style: ElevatedButton.styleFrom(
              //               backgroundColor: AppColors.primary,
              //               foregroundColor: Colors.white,
              //             ),
              //             child: const Text('Aceptar'),
              //           ),
              //         ],
              //       ),
              //     );
              //   },
              // ),

              const SizedBox(height: 16),
              _buildSectionTitle('Negocio'),
              RoleGuard.gerencia(
                rolActual: usuario?.rol,
                modo: RoleGuardMode.ocultar,
                child: _buildListTile(
                  Icons.storefront_outlined,
                  'Configuración Financiera',
                  'IVA y Parámetros fiscales',
                  iconBgColor: AppColors.subtleGreen,
                  iconColor: AppColors.brightGreen,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConfiguracionFinancieraVista(
                        controladorPerfil: context.read<ControladorPerfil>(),
                      ),
                    ),
                  ),
                ),
              ),
              RoleGuard.gerencia(
                rolActual: usuario?.rol,
                modo: RoleGuardMode.ocultar,
                child: _buildListTile(
                  Icons.people_outline,
                  'Empleados',
                  'Gestionar perfiles y permisos',
                  iconBgColor: AppColors.subtleTurquoise,
                  iconColor: AppColors.turquoise,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmpleadosVista(
                        controladorAutenticacion: context.read<ControladorAutenticacion>(),
                      ),
                    ),
                  ),
                ),
              ),
              _buildListTile(
                Icons.account_balance_wallet_outlined,
                'Cuentas por Cobrar (Deudores)',
                'Apartados y seguimiento de saldos',
                iconBgColor: AppColors.subtleAmber,
                iconColor: AppColors.amber,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeudoresVista(
                      controladorVentas: context.read<ControladorVentas>(),
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
                      controladorVentas: context.read<ControladorVentas>(),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('Cuenta y Acceso'),
              _buildListTile(
                Icons.shield_outlined,
                'Seguridad y Acceso',
                cBiometrico.tieneHuellaRegistrada
                    ? 'Huella activa · Contraseña protegida'
                    : 'Acceso biométrico y contraseña',
                iconBgColor: AppColors.subtleGreen,
                iconColor: AppColors.brightGreen,
                onTap: () async {
                  final bool verificado = await VerificacionSeguridadSheet.solicitar(
                    context: context,
                    controladorAutenticacion: context.read<ControladorAutenticacion>(),
                    controladorBiometrico: context.read<ControladorBiometrico>(),
                    titulo: 'Acceso a Seguridad',
                    motivo: 'Confirma tu identidad para configurar biometría o cambiar tu contraseña.',
                  );
                  if (!verificado || !context.mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SeguridadAccesoVista(
                        controladorAutenticacion: context.read<ControladorAutenticacion>(),
                        controladorBiometrico: context.read<ControladorBiometrico>(),
                      ),
                    ),
                  ).then((_) => setState(() {}));
                },
              ),
              RoleGuard.gerencia(
                rolActual: usuario?.rol,
                modo: RoleGuardMode.ocultar,
                child: _buildListTile(
                  Icons.devices_other_outlined,
                  'Hardware y Periféricos',
                  'Lector de huellas, impresoras y conexiones',
                  iconBgColor: AppColors.subtleAmber,
                  iconColor: AppColors.amber,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HardwareVista(
                        controladorBiometrico: context.read<ControladorBiometrico>(),
                      ),
                    ),
                  ).then((_) => setState(() {})),
                ),
              ),
              _buildListTile(
                Icons.help_outline,
                'Soporte y Ayuda',
                'Acerca de Planteapp / Versión 1.0.0',
                iconBgColor: AppColors.subtleTurquoise,
                iconColor: AppColors.turquoise,
                onTap: () => mostrarDialogoSoporte(context),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
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
      ),
    );
  }
}

/// Muestra el panel corporativo y adaptativo de Soporte y Ayuda de Planteapp (Versión 1.0.0).
void mostrarDialogoSoporte(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AnimatedBuilder(
        animation: ThemeManager.instance,
        builder: (context, _) {
          return Dialog(
            backgroundColor: AppColors.card,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.border, width: 1),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Logotipo Corporativo con insignia
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const LogoBiznaga(size: 48),
                    ),
                    const SizedBox(height: 14),

                    // 2. Nombre del Sistema y Versión Oficial
                    Text(
                      'Soporte Planteapp',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.brightGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Versión: 1.0.0 Oficial (Biznaga Kíix)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Terminal Punto de Venta (POS) y gestión de inventario botánico 100% offline.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 18),
                    Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 14),

                    // 3. Canales de Contacto Profesionales
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'CANALES DE ATENCIÓN Y CONTACTO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildContactoItem(
                      icono: Icons.alternate_email_rounded,
                      titulo: 'soporte@planteapp.com.mx',
                      subtitulo: 'Correo de asistencia técnica',
                      colorFondo: AppColors.subtleGreen,
                      colorIcono: AppColors.brightGreen,
                    ),
                    const SizedBox(height: 6),
                    _buildContactoItem(
                      icono: Icons.phone_outlined,
                      titulo: '+52 800 123 4567',
                      subtitulo: 'Línea de soporte telefónico',
                      colorFondo: AppColors.subtleAmber,
                      colorIcono: AppColors.amber,
                    ),
                    const SizedBox(height: 6),
                    _buildContactoItem(
                      icono: Icons.language_rounded,
                      titulo: 'www.planteapp.com.mx',
                      subtitulo: 'Sitio web oficial y manuales',
                      colorFondo: AppColors.subtleTurquoise,
                      colorIcono: AppColors.turquoise,
                    ),
                    const SizedBox(height: 6),
                    _buildContactoItem(
                      icono: Icons.business_outlined,
                      titulo: 'Planteapp Solutions',
                      subtitulo: 'Desarrollo e ingeniería de software',
                      colorFondo: AppColors.secondarySurface,
                      colorIcono: AppColors.textPrimary,
                    ),

                    const SizedBox(height: 22),

                    // 4. Botón de Acción Cerrar
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Cerrar',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildContactoItem({
  required IconData icono,
  required String titulo,
  required String subtitulo,
  required Color colorFondo,
  required Color colorIcono,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.secondarySurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border, width: 0.6),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colorFondo,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, size: 18, color: colorIcono),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitulo,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
