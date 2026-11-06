import 'package:flutter/material.dart';
import '../../Controladores/controlador_autenticacion.dart';
import '../../Controladores/controlador_biometrico.dart';
import '../../Tema/app_theme.dart';
import 'custom_password_field.dart';

/// Modal de verificación previa de seguridad para operaciones sensibles
/// (cambio de contraseña, alteración de credenciales biométricas, etc.).
class VerificacionSeguridadSheet extends StatefulWidget {
  final ControladorAutenticacion controladorAutenticacion;
  final ControladorBiometrico? controladorBiometrico;
  final String titulo;
  final String motivo;
  final String accionBoton;

  const VerificacionSeguridadSheet({
    super.key,
    required this.controladorAutenticacion,
    this.controladorBiometrico,
    this.titulo = 'Verificación de Seguridad',
    this.motivo =
        'Para acceder a la configuración de credenciales sensibles, confirma tu identidad.',
    this.accionBoton = 'Confirmar Identidad',
  });

  /// Método estático para invocar el flujo de verificación previa de forma concisa
  static Future<bool> solicitar({
    required BuildContext context,
    required ControladorAutenticacion controladorAutenticacion,
    ControladorBiometrico? controladorBiometrico,
    String titulo = 'Verificación de Seguridad',
    String motivo =
        'Para acceder a la configuración de credenciales sensibles, confirma tu identidad.',
    String accionBoton = 'Confirmar Identidad',
  }) async {
    final bool? verificado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => VerificacionSeguridadSheet(
        controladorAutenticacion: controladorAutenticacion,
        controladorBiometrico: controladorBiometrico,
        titulo: titulo,
        motivo: motivo,
        accionBoton: accionBoton,
      ),
    );

    return verificado ?? false;
  }

  @override
  State<VerificacionSeguridadSheet> createState() =>
      _VerificacionSeguridadSheetState();
}

class _VerificacionSeguridadSheetState
    extends State<VerificacionSeguridadSheet> {
  final _formKey = GlobalKey<FormState>();
  final _claveController = TextEditingController();
  bool _estaValidando = false;
  String? _errorMensaje;

  @override
  void dispose() {
    _claveController.dispose();
    super.dispose();
  }

  /// Verifica la clave contra la base de datos local SQLite
  Future<void> _validarClave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _estaValidando = true;
      _errorMensaje = null;
    });

    final usuario = widget.controladorAutenticacion.usuarioActual;
    if (usuario == null) {
      setState(() {
        _estaValidando = false;
        _errorMensaje = 'No hay una sesión activa de usuario.';
      });
      return;
    }

    final claveIngresada = _claveController.text.trim();
    final bool esValida = await widget.controladorAutenticacion.verificarClave(
      usuario,
      claveIngresada,
    );

    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    if (esValida) {
      setState(() => _estaValidando = false);
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _estaValidando = false;
        _errorMensaje = 'Contraseña incorrecta. Inténtalo de nuevo.';
      });
    }
  }

  /// Ejecuta la validación biométrica nativa (local_auth / lector de huella)
  Future<void> _validarBiometria() async {
    final bioCtrl = widget.controladorBiometrico;
    if (bioCtrl == null || !bioCtrl.tieneHuellaRegistrada) return;

    setState(() {
      _estaValidando = true;
      _errorMensaje = null;
    });

    try {
      final bool exito = await bioCtrl.servicio.autenticarHuella(
        motivo: widget.motivo,
      );

      if (!mounted) return;

      if (exito) {
        setState(() => _estaValidando = false);
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _estaValidando = false;
          _errorMensaje = 'Autenticación biométrica fallida o cancelada.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estaValidando = false;
        _errorMensaje = 'Error al verificar sensor biométrico: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.controladorAutenticacion.usuarioActual;
    final bool biometriaDisponible =
        widget.controladorBiometrico?.tieneHuellaRegistrada ?? false;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tirador superior (drag handle)
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
                  const SizedBox(height: 18),

                  // Cabecera con ícono de seguridad
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.security_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.titulo,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (usuario != null)
                              Text(
                                '${usuario.nombre} (${usuario.id})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        tooltip: 'Cancelar',
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Texto explicativo del motivo de seguridad
                  Text(
                    widget.motivo,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Mensaje de error visual si falla la verificación
                  if (_errorMensaje != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMensaje!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Campo de texto para contraseña actual con toggle de visibilidad
                  CustomPasswordFormField(
                    controller: _claveController,
                    labelText: 'Contraseña o PIN actual',
                    hintText: 'Ingresa tu credencial para continuar',
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Ingresa tu contraseña actual';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      if (_errorMensaje != null) {
                        setState(() => _errorMensaje = null);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Botón principal de validación por contraseña
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _estaValidando ? null : _validarClave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _estaValidando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              widget.accionBoton,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  // Botón opcional de biometría si el usuario tiene huella registrada
                  if (biometriaDisponible) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o también',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.border)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _estaValidando ? null : _validarBiometria,
                        icon: Icon(
                          Icons.fingerprint_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        label: Text(
                          'Validar con Sensor de Huella',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.border, width: 1.2),
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
        ),
      ),
    );
  }
}

