import 'package:flutter/material.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_autenticacion.dart';
import '../Controladores/controlador_biometrico.dart';
import 'Widgets/custom_password_field.dart';

/// Vista unificada de Seguridad y Acceso:
/// Centraliza la gestión de autenticación biométrica (huella dactilar)
/// y el cambio de contraseña en una sola experiencia fluida y coherente.
class SeguridadAccesoVista extends StatefulWidget {
  final ControladorAutenticacion controladorAutenticacion;
  final ControladorBiometrico controladorBiometrico;

  const SeguridadAccesoVista({
    super.key,
    required this.controladorAutenticacion,
    required this.controladorBiometrico,
  });

  @override
  State<SeguridadAccesoVista> createState() => _SeguridadAccesoVistaState();
}

class _SeguridadAccesoVistaState extends State<SeguridadAccesoVista> {
  // Estado y controladores de contraseña
  final _formKey = GlobalKey<FormState>();
  final _nuevaClaveController = TextEditingController();
  final _confirmarClaveController = TextEditingController();
  String _claveActual = '';
  bool _actualizandoClave = false;

  // Estado biométrico local
  late bool _biometriaHabilitada;

  @override
  void initState() {
    super.initState();
    _biometriaHabilitada =
        widget.controladorBiometrico.config.biometriaHabilitada;
  }

  @override
  void dispose() {
    _nuevaClaveController.dispose();
    _confirmarClaveController.dispose();
    super.dispose();
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
            ),
            const SizedBox(width: 8),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- LÓGICA BIOMÉTRICA ---

  Future<void> _abrirDialogoAgregarHuella() async {
    final colaboradores =
        await widget.controladorAutenticacion.obtenerColaboradores();
    if (!mounted) return;

    String idColaboradorSeleccionado =
        widget.controladorAutenticacion.usuarioActual?.id ??
            (colaboradores.isNotEmpty ? colaboradores.first.id : 'VO-4092');

    final nombreHuellaCtrl =
        TextEditingController(text: 'Huella Dactilar Principal');

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.fingerprint, color: AppColors.primary, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'Registrar Huella',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asocia una huella al perfil del usuario actual para iniciar sesión rápidamente.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Colaborador asociado',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: idColaboradorSeleccionado,
                          isExpanded: true,
                          dropdownColor: AppColors.card,
                          style: TextStyle(color: AppColors.textPrimary),
                          items: colaboradores.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.id,
                              child: Text('${c.nombre} (${c.rol})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                idColaboradorSeleccionado = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Etiqueta de la huella',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nombreHuellaCtrl,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Ej. Índice Derecho',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.secondarySurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.fingerprint, size: 18),
                  label: const Text('Escanear y Guardar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmar == true) {
      final compatible = await widget.controladorBiometrico.servicio
          .verificarSoporteBiometrico();
      if (!compatible && mounted) {
        _mostrarToast(
          'No se detectó un sensor biométrico disponible o habilitado en este dispositivo.',
          esError: true,
        );
        return;
      }

      final exito = await widget.controladorBiometrico.registrarHuella(
        colaboradorId: idColaboradorSeleccionado,
        nombreHuella: nombreHuellaCtrl.text,
      );

      if (mounted) {
        if (exito) {
          setState(() {
            _biometriaHabilitada = true;
          });
          _mostrarToast('Huella dactilar registrada y activada exitosamente.');
        } else {
          _mostrarToast(
            'No se completó la lectura biométrica o fue cancelada.',
            esError: true,
          );
        }
      }
    }
  }

  Future<void> _abrirDialogoEliminarHuella() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Eliminar Huella?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Se eliminará la huella biométrica registrada. Podrás continuar accediendo con tu contraseña habitual.',
          style: TextStyle(color: AppColors.textSecondary),
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
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await widget.controladorBiometrico.eliminarHuella();
      if (mounted) {
        setState(() {
          _biometriaHabilitada = false;
        });
        _mostrarToast('Huella dactilar eliminada correctamente.');
      }
    }
  }

  // --- LÓGICA DE CONTRASEÑA ---

  Future<void> _cambiarPassword() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final user = widget.controladorAutenticacion.usuarioActual;
    if (user == null) return;

    setState(() => _actualizandoClave = true);

    try {
      final esValida = await widget.controladorAutenticacion
          .verificarClave(user, _claveActual);

      if (!mounted) return;
      if (!esValida) {
        setState(() => _actualizandoClave = false);
        _mostrarToast('La contraseña actual es incorrecta.', esError: true);
        return;
      }

      final nuevaClave = _nuevaClaveController.text.trim();
      await widget.controladorAutenticacion.cambiarClave(user.id, nuevaClave);

      if (!mounted) return;
      setState(() {
        _actualizandoClave = false;
        _nuevaClaveController.clear();
        _confirmarClaveController.clear();
      });

      _mostrarToast('Contraseña actualizada exitosamente.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _actualizandoClave = false);
      _mostrarToast('Error al actualizar la contraseña: $e', esError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.controladorBiometrico.config;
    final bool tieneHuella = cfg.tieneHuellaRegistrada;

    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            title: Text(
              'Seguridad y Acceso',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            backgroundColor: AppColors.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                // ==========================================
                // 1. SECCIÓN: AUTENTICACIÓN BIOMÉTRICA
                // ==========================================
                Text(
                  'ACCESO BIOMÉTRICO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                // Switch Activar Biometría
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.primary,
                    title: Text(
                      'Activar Acceso Biométrico',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      'Permite desbloquear e iniciar sesión con la huella dactilar',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    value: _biometriaHabilitada,
                    onChanged: (val) async {
                      if (val && !tieneHuella) {
                        await _abrirDialogoAgregarHuella();
                      } else {
                        setState(() => _biometriaHabilitada = val);
                        await widget.controladorBiometrico
                            .activarBiometria(val);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Tarjeta Estado de la Huella
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tieneHuella
                          ? AppColors.primary.withValues(alpha: 0.35)
                          : AppColors.border,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: tieneHuella
                                  ? AppColors.primaryContainer
                                  : AppColors.secondarySurface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.fingerprint,
                              color: tieneHuella
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tieneHuella
                                      ? (cfg.nombreHuella ?? 'Huella Activa')
                                      : 'Sin Huella Registrada',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tieneHuella
                                      ? 'Asociada al ID: ${cfg.usuarioVinculadoId}'
                                      : 'Registra tu huella para acceder sin teclear contraseña.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _abrirDialogoAgregarHuella,
                              icon: Icon(
                                tieneHuella ? Icons.refresh : Icons.add,
                                size: 18,
                              ),
                              label: Text(
                                tieneHuella
                                    ? 'Re-escanear Huella'
                                    : 'Agregar Huella',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          if (tieneHuella) ...[
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: _abrirDialogoEliminarHuella,
                              tooltip: 'Eliminar Huella',
                              icon: const Icon(Icons.delete_outline),
                              color: AppColors.error,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    AppColors.error.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                // ==========================================
                // 2. SECCIÓN: CAMBIAR CONTRASEÑA
                // ==========================================
                Text(
                  'CONTRASEÑA DE ACCESO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cambiar Contraseña',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ingresa tu contraseña actual y define una nueva clave segura.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomPasswordFormField(
                          labelText: 'Contraseña actual',
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Requerido' : null,
                          onSaved: (v) => _claveActual = v ?? '',
                        ),
                        const SizedBox(height: 16),
                        CustomPasswordFormField(
                          controller: _nuevaClaveController,
                          labelText: 'Nueva contraseña',
                          validator: (v) => v == null || v.length < 4
                              ? 'Mínimo 4 caracteres'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        CustomPasswordFormField(
                          controller: _confirmarClaveController,
                          labelText: 'Confirmar nueva contraseña',
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            if (v != _nuevaClaveController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed:
                                _actualizandoClave ? null : _cambiarPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.primary.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _actualizandoClave
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Actualizar Contraseña',
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

                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }
}

