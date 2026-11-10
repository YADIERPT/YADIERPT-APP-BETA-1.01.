import 'package:flutter/material.dart';

import '../../Modelos/colaborador.dart';
import '../../Tema/app_theme.dart';

/// Modo de respuesta ante la falta de permisos de un usuario
enum RoleGuardMode {
  /// Oculta completamente el elemento en el árbol de widgets (retorna SizedBox.shrink)
  ocultar,

  /// Muestra una vista elegante de "Acceso Restringido" acorde a la identidad visual
  placeholder,
}

/// Widget de protección de interfaz de usuario basado en roles (RBAC).
///
/// Evalúa el [rolActual] contra los [rolesPermitidos]. Si el usuario cuenta
/// con los permisos requeridos, renderiza el [child]. De lo contrario,
/// aplica el comportamiento configurado en [modo] o renderiza [fallback].
class RoleGuard extends StatelessWidget {
  final Widget child;
  final List<RolUsuario> rolesPermitidos;
  final RolUsuario? rolActual;
  final RoleGuardMode modo;
  final Widget? fallback;
  final String? titulo;
  final String? mensaje;
  final String? textoAccion;
  final VoidCallback? onAccion;

  const RoleGuard({
    super.key,
    required this.child,
    required this.rolesPermitidos,
    this.rolActual,
    this.modo = RoleGuardMode.ocultar,
    this.fallback,
    this.titulo,
    this.mensaje,
    this.textoAccion,
    this.onAccion,
  });

  /// Constructor de conveniencia exclusivo para la Dueña y Gerencia (exclusivo Dueño en política 2 roles)
  const RoleGuard.gerencia({
    super.key,
    required this.child,
    this.rolActual,
    this.modo = RoleGuardMode.ocultar,
    this.fallback,
    this.titulo,
    this.mensaje,
    this.textoAccion,
    this.onAccion,
  }) : rolesPermitidos = const [RolUsuario.duena];

  /// Constructor de conveniencia exclusivo para el Dueño/a del vivero
  const RoleGuard.soloDuena({
    super.key,
    required this.child,
    this.rolActual,
    this.modo = RoleGuardMode.ocultar,
    this.fallback,
    this.titulo,
    this.mensaje,
    this.textoAccion,
    this.onAccion,
  }) : rolesPermitidos = const [RolUsuario.duena];

  const RoleGuard.soloDueno({
    super.key,
    required this.child,
    this.rolActual,
    this.modo = RoleGuardMode.ocultar,
    this.fallback,
    this.titulo,
    this.mensaje,
    this.textoAccion,
    this.onAccion,
  }) : rolesPermitidos = const [RolUsuario.duena];

  bool get estaAutorizado =>
      rolActual != null && rolesPermitidos.contains(rolActual);

  @override
  Widget build(BuildContext context) {
    if (estaAutorizado) {
      return child;
    }

    if (fallback != null) {
      return fallback!;
    }

    if (modo == RoleGuardMode.ocultar) {
      return const SizedBox.shrink();
    }

    return AccesoDenegadoView(
      rolActual: rolActual,
      rolesRequeridos: rolesPermitidos,
      titulo: titulo,
      mensaje: mensaje,
      textoAccion: textoAccion,
      onAccion: onAccion,
    );
  }
}

/// Pantalla / Tarjeta de estado vacío cuando el usuario no cuenta con autorización.
///
/// Diseñada con una paleta desaturada y sobria acorde a la identidad botánica
/// de Planteapp (sin saturaciones rojas agresivas, con tonos card/border tranquilos).
class AccesoDenegadoView extends StatelessWidget {
  final RolUsuario? rolActual;
  final List<RolUsuario> rolesRequeridos;
  final String? titulo;
  final String? mensaje;
  final String? textoAccion;
  final VoidCallback? onAccion;

  const AccesoDenegadoView({
    super.key,
    this.rolActual,
    this.rolesRequeridos = const [RolUsuario.duena],
    this.titulo,
    this.mensaje,
    this.textoAccion,
    this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    final rolNombre = rolActual?.etiqueta ?? 'Sin asignar';
    final rolesRequeridosTexto =
        rolesRequeridos.map((r) => r.etiqueta).join(' o ');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        physics: const BouncingScrollPhysics(),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícono de escudo con tonos tranquilos (ámbar/dorado calmado)
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.subtleAmber,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 34,
                  color: AppColors.amber,
                ),
              ),
              const SizedBox(height: 18),

              // Título
              Text(
                titulo ?? 'Acceso Restringido',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),

              // Insignia del Rol Actual
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Text(
                  'Tu rol actual: $rolNombre',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Mensaje explicativo
              Text(
                mensaje ??
                    'Esta sección está reservada exclusivamente para el perfil de $rolesRequeridosTexto. Tu cuenta no posee los privilegios necesarios para ver o modificar esta información.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),

              // Botón de acción opcional (ej: regresar o ir al POS)
              if (onAccion != null) ...[
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: onAccion,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(
                      textoAccion ?? 'Ir al Punto de Venta',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

