import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_autenticacion.dart';
import '../Modelos/colaborador.dart';
import 'Widgets/role_guard.dart';
import 'Widgets/dialogo_seguridad_admin.dart';
import 'Widgets/formulario_empleado_sheet.dart';

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
    // 1. Barrera de seguridad: Verificación obligatoria de contraseña de Dueña/Admin
    final bool autorizada = await DialogoSeguridadAdmin.verificar(
      context: context,
      controladorAutenticacion: widget.controladorAutenticacion,
    );

    if (!autorizada) return;

    // 2. Si la validación es correcta, navegar al formulario
    if (!mounted) return;
    final bool guardado = await FormularioEmpleadoSheet.mostrar(
      context: context,
      controladorAutenticacion: widget.controladorAutenticacion,
    );

    if (guardado) {
      // 3. Reactividad inmediata
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
      // 3. Reactividad inmediata
      await _cargarEmpleados();
      _mostrarToast('Perfil de "${emp.nombre}" actualizado correctamente');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolActual = widget.controladorAutenticacion.usuarioActual?.rol;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Empleados',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _iniciarRegistroEmpleado,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text(
          'Nuevo Empleado',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RoleGuard(
        rolesPermitidos: const [RolUsuario.duena, RolUsuario.gerente],
        rolActual: rolActual,
        modo: RoleGuardMode.placeholder,
        titulo: 'Gestión de Personal Reservada',
        mensaje:
            'Solo la Dueña y la Gerencia tienen autorización para consultar y administrar el catálogo de colaboradores y sus accesos.',
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
                                        : emp.rol.esGerente
                                            ? AppColors.subtleTurquoise
                                            : AppColors.primaryContainer,
                                    child: Icon(
                                      emp.rol.esDuena
                                          ? Icons.star_rounded
                                          : emp.rol.esGerente
                                              ? Icons.manage_accounts
                                              : Icons.person,
                                      color: emp.rol.esDuena
                                          ? AppColors.amber
                                          : emp.rol.esGerente
                                              ? AppColors.turquoise
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
                                  Icon(
                                    Icons.edit_outlined,
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

