import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_autenticacion.dart';
import '../Modelos/colaborador.dart';
import 'Widgets/role_guard.dart';
import 'Widgets/dialogo_seguridad_admin.dart';
import 'Widgets/formulario_empleado_sheet.dart';

/// Alias semántico para la vista de gestión de usuarios / colaboradores
typedef UsuariosVista = EmpleadosVista;

class EmpleadosVista extends StatefulWidget {
  final ControladorAutenticacion controladorAutenticacion;

  const EmpleadosVista({super.key, required this.controladorAutenticacion});

  @override
  State<EmpleadosVista> createState() => _EmpleadosVistaState();
}

class _EmpleadosVistaState extends State<EmpleadosVista> {
  List<Colaborador> _empleados = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarEmpleados();
  }

  Future<void> _cargarEmpleados() async {
    final emp = await widget.controladorAutenticacion.obtenerColaboradores();
    if (mounted) {
      setState(() {
        _empleados = emp;
        _cargando = false;
      });
    }
  }

  void _mostrarToast(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              esError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: esError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Inicia el flujo de registro de nuevo empleado con barrera de seguridad
  Future<void> _iniciarRegistroEmpleado() async {
    // 1. Barrera de seguridad: Verificación obligatoria de contraseña de Dueño/Admin
    final bool autorizada = await DialogoSeguridadAdmin.verificar(
      context: context,
      controladorAutenticacion: widget.controladorAutenticacion,
    );

    if (!autorizada) return;

    // 2. Si la validación es correcta, desplegar modal de registro
    if (!mounted) return;
    final bool guardado = await FormularioEmpleadoSheet.mostrar(
      context: context,
      controladorAutenticacion: widget.controladorAutenticacion,
    );

    if (guardado) {
      await _cargarEmpleados();
      _mostrarToast('Colaborador registrado correctamente');
    }
  }

  /// Inicia el flujo de edición de empleado existente con barrera de seguridad
  Future<void> _iniciarEdicionEmpleado(Colaborador emp) async {
    // 1. Barrera de seguridad previa
    final bool autorizada = await DialogoSeguridadAdmin.verificar(
      context: context,
      controladorAutenticacion: widget.controladorAutenticacion,
    );

    if (!autorizada) return;

    // 2. Navegar al formulario de edición
    if (!mounted) return;
    final bool guardado = await FormularioEmpleadoSheet.mostrar(
      context: context,
      empleadoExistente: emp,
      controladorAutenticacion: widget.controladorAutenticacion,
    );

    if (guardado) {
      await _cargarEmpleados();
      _mostrarToast('Perfil de "${emp.nombre}" actualizado correctamente');
    }
  }

  /// Elimina un colaborador con confirmación y Protección Anti-Suicidio
  Future<void> _confirmarEliminarEmpleado(Colaborador emp) async {
    // 1. Protección Anti-Suicidio en la Vista: Nunca permitir auto-eliminación
    final usuarioActual = widget.controladorAutenticacion.usuarioActual;
    if (usuarioActual != null && usuarioActual.id == emp.id) {
      _mostrarToast(
        'Protección Anti-Suicidio: No puedes eliminar tu propia cuenta activa.',
        esError: true,
      );
      return;
    }

    // 2. Diálogo de confirmación explícito
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Text(
              'Eliminar Colaborador',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar a "${emp.nombre}" (${emp.rol.etiqueta})?\n\nEsta acción revocará su acceso al sistema y no se puede deshacer.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // 3. Ejecución segura a través del controlador
    try {
      final exito = await widget.controladorAutenticacion.eliminarColaborador(emp.id);
      if (exito) {
        await _cargarEmpleados();
        _mostrarToast('Colaborador "${emp.nombre}" eliminado correctamente');
      }
    } catch (e) {
      _mostrarToast(
        e.toString().replaceAll('Exception: ', ''),
        esError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolActual = widget.controladorAutenticacion.usuarioActual?.rol;
    final usuarioActualId = widget.controladorAutenticacion.usuarioActual?.id;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Gestión de Empleados',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      floatingActionButton: rolActual?.esDuena == true
          ? FloatingActionButton.extended(
              onPressed: _iniciarRegistroEmpleado,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: const Text(
                'Nuevo Empleado',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: RoleGuard(
        rolesPermitidos: const [RolUsuario.duena],
        rolActual: rolActual,
        modo: RoleGuardMode.placeholder,
        titulo: 'Gestión de Personal Reservada',
        mensaje:
            'Solo el Dueño tiene autorización para consultar y administrar el catálogo de colaboradores y sus accesos.',
        textoAccion: 'Regresar',
        onAccion: () => Navigator.pop(context),
        child: _cargando
            ? Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _empleados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No hay empleados registrados en el sistema',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: _empleados.length,
                    itemBuilder: (context, index) {
                      final emp = _empleados[index];
                      // Regla de Protección Anti-Suicidio:
                      final bool esSesionActiva =
                          usuarioActualId != null && usuarioActualId == emp.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _iniciarEdicionEmpleado(emp),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: emp.rol.esDuena
                                        ? AppColors.subtleAmber
                                        : AppColors.primaryContainer,
                                    child: Icon(
                                      emp.rol.esDuena
                                          ? Icons.star_rounded
                                          : Icons.person,
                                      color: emp.rol.esDuena
                                          ? AppColors.amber
                                          : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          emp.nombre,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.secondarySurface,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                emp.rol.etiqueta.toUpperCase(),
                                                style: TextStyle(
                                                  color: emp.rol.esDuena
                                                      ? AppColors.amber
                                                      : AppColors.textSecondary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'ID: ${emp.id}',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Acciones por usuario con Protección Anti-Suicidio
                                  if (esSesionActiva)
                                    Tooltip(
                                      message:
                                          'Sesión activa (No puedes auto-eliminarte)',
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.subtleGreen,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppColors.primary
                                                .withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.shield_rounded,
                                              size: 14,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Tú',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: AppColors.error,
                                        size: 20,
                                      ),
                                      tooltip: 'Eliminar colaborador',
                                      onPressed: () =>
                                          _confirmarEliminarEmpleado(emp),
                                    ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    color: AppColors.textSecondary,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}


