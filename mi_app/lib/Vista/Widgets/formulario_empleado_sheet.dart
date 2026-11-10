import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Controladores/controlador_autenticacion.dart';
import '../../Modelos/colaborador.dart';
import '../../Tema/app_theme.dart';

/// Modal / Formulario para el registro y edición de empleados en SQLite
class FormularioEmpleadoSheet extends StatefulWidget {
  final Colaborador? empleadoExistente;
  final ControladorAutenticacion controladorAutenticacion;

  const FormularioEmpleadoSheet({
    super.key,
    this.empleadoExistente,
    required this.controladorAutenticacion,
  });

  /// Método estático para abrir el formulario en un BottomSheet
  static Future<bool> mostrar({
    required BuildContext context,
    Colaborador? empleadoExistente,
    required ControladorAutenticacion controladorAutenticacion,
  }) async {
    final bool? guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => FormularioEmpleadoSheet(
        empleadoExistente: empleadoExistente,
        controladorAutenticacion: controladorAutenticacion,
      ),
    );

    return guardado ?? false;
  }

  @override
  State<FormularioEmpleadoSheet> createState() => _FormularioEmpleadoSheetState();
}

class _FormularioEmpleadoSheetState extends State<FormularioEmpleadoSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _claveCtrl;
  late RolUsuario _rolSeleccionado;
  bool _ocultarClave = true;
  bool _guardando = false;

  bool get esEdicion => widget.empleadoExistente != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(
      text: widget.empleadoExistente?.nombre ?? '',
    );
    _claveCtrl = TextEditingController();
    _rolSeleccionado = widget.empleadoExistente?.rol ?? RolUsuario.empleado;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _claveCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarEmpleado() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final nombre = _nombreCtrl.text.trim();
      final clave = _claveCtrl.text.trim();

      // 1. Detección de sesión activa para Protección Anti-Degradación
      final usuarioActual = () {
        try {
          return context.read<ControladorAutenticacion>().usuarioActual;
        } catch (_) {
          return widget.controladorAutenticacion.usuarioActual;
        }
      }();

      final bool esMismoUsuarioActivo = esEdicion &&
          usuarioActual != null &&
          widget.empleadoExistente!.id == usuarioActual.id;

      if (esEdicion) {
        // Protección Anti-Degradación: Si el usuario en sesión activa se edita a sí mismo,
        // su rol se mantiene inalterable (RolUsuario.duena), evitando pérdida permanente de privilegios.
        final rolFinal = esMismoUsuarioActivo
            ? widget.empleadoExistente!.rol
            : _rolSeleccionado;

        final empActualizado = widget.empleadoExistente!.copyWith(
          nombre: nombre,
          rol: rolFinal,
        );

        await widget.controladorAutenticacion.actualizarColaborador(
          empActualizado,
          nuevaClave: clave.isNotEmpty ? clave : null,
        );
      } else {
        // Generar un ID único corto para el nuevo empleado (ej. EMP-1823)
        final sufijo = DateTime.now().millisecondsSinceEpoch.toString();
        final nuevoId = 'EMP-${sufijo.substring(sufijo.length - 4)}';

        final nuevoEmp = Colaborador(
          id: nuevoId,
          nombre: nombre,
          clave: clave,
          rol: _rolSeleccionado,
        );

        await widget.controladorAutenticacion.registrarColaborador(nuevoEmp);
      }

      // Reactividad: refrescar la lista de empleados inmediatamente via Provider
      if (mounted) {
        await widget.controladorAutenticacion.obtenerColaboradores();
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar empleado: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Validación de sesión activa: ¿Es el usuario actual editándose a sí mismo?
    final usuarioActual = () {
      try {
        return context.read<ControladorAutenticacion>().usuarioActual;
      } catch (_) {
        return widget.controladorAutenticacion.usuarioActual;
      }
    }();

    final bool esMismoUsuarioActivo = esEdicion &&
        usuarioActual != null &&
        widget.empleadoExistente!.id == usuarioActual.id;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Asa de arrastre
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Encabezado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            esEdicion ? Icons.edit_note : Icons.person_add_alt_1,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                esEdicion ? 'Editar Empleado' : 'Nuevo Empleado',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                esEdicion
                                    ? 'ID: ${widget.empleadoExistente!.id}'
                                    : 'Ingresa los datos del nuevo colaborador',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Campo: Nombre
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Nombre completo *',
                  labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
                  filled: true,
                  fillColor: AppColors.secondarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Campo: Rol con Protección Anti-Degradación
              if (esMismoUsuarioActivo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.secondarySurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_rounded, color: AppColors.amber, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rol: Dueño (No modificable)',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Protección Anti-Degradación: No puedes revocar tu propio acceso administrativo.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.subtleAmber,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'TÚ',
                          style: TextStyle(
                            color: AppColors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<RolUsuario>(
                  value: _rolSeleccionado,
                  isExpanded: true,
                  dropdownColor: AppColors.card,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Rol en Planteapp *',
                    labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                    filled: true,
                    fillColor: AppColors.secondarySurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: RolUsuario.duena,
                      child: Text('Dueño (Acceso Total y Seguridad)'),
                    ),
                    DropdownMenuItem(
                      value: RolUsuario.empleado,
                      child: Text('Empleado (Punto de Venta / POS)'),
                    ),
                  ],
                  onChanged: (RolUsuario? nuevoRol) {
                    if (nuevoRol != null) {
                      setState(() => _rolSeleccionado = nuevoRol);
                    }
                  },
                ),
              const SizedBox(height: 14),

              // Campo: Contraseña
              TextFormField(
                controller: _claveCtrl,
                obscureText: _ocultarClave,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: esEdicion
                      ? 'Nueva contraseña (opcional)'
                      : 'Contraseña de acceso *',
                  helperText: esEdicion
                      ? 'Déjalo en blanco para mantener la contraseña actual'
                      : 'Se encriptará con PBKDF2 y salt único',
                  helperStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  prefixIcon: Icon(Icons.key_outlined, color: AppColors.primary, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _ocultarClave ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _ocultarClave = !_ocultarClave),
                  ),
                  filled: true,
                  fillColor: AppColors.secondarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                validator: (v) {
                  if (!esEdicion && (v == null || v.trim().isEmpty)) {
                    return 'La contraseña es obligatoria para nuevos empleados';
                  }
                  if (v != null && v.trim().isNotEmpty && v.trim().length < 4) {
                    return 'La contraseña debe tener al menos 4 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 22),

              // Botón de Guardar
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardarEmpleado,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(esEdicion ? Icons.save : Icons.person_add, size: 20),
                  label: Text(
                    esEdicion ? 'Actualizar Empleado' : 'Registrar Empleado',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }
}

