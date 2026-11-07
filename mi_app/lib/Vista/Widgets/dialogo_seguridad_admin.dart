import 'package:flutter/material.dart';
import '../../Controladores/controlador_autenticacion.dart';
import '../../Tema/app_theme.dart';

/// Diálogo modal de seguridad que exige la contraseña de la Dueña o Administrador
/// antes de permitir registrar o modificar perfiles de empleados.
class DialogoSeguridadAdmin extends StatefulWidget {
  final ControladorAutenticacion controladorAutenticacion;

  const DialogoSeguridadAdmin({
    super.key,
    required this.controladorAutenticacion,
  });

  /// Método estático conveniente para invocar la validación de seguridad
  static Future<bool> verificar({
    required BuildContext context,
    required ControladorAutenticacion controladorAutenticacion,
  }) async {
    final bool? resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DialogoSeguridadAdmin(
        controladorAutenticacion: controladorAutenticacion,
      ),
    );

    return resultado ?? false;
  }

  @override
  State<DialogoSeguridadAdmin> createState() => _DialogoSeguridadAdminState();
}

class _DialogoSeguridadAdminState extends State<DialogoSeguridadAdmin> {
  final _claveCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _ocultarClave = true;
  bool _validando = false;
  String? _errorMensaje;

  @override
  void dispose() {
    _claveCtrl.dispose();
    super.dispose();
  }

  Future<void> _validarYConfirmar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _validando = true;
      _errorMensaje = null;
    });

    final clave = _claveCtrl.text.trim();
    final bool esValida =
        await widget.controladorAutenticacion.verificarClaveAdmin(clave);

    if (!mounted) return;

    setState(() => _validando = false);

    if (esValida) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMensaje = 'Contraseña incorrecta. Acceso restringido.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.lock_clock, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Acceso denegado: Contraseña de Dueña/Admin incorrecta.',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.border),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.subtleAmber,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.admin_panel_settings, color: AppColors.amber, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Autorización de Seguridad',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingresa la contraseña de la Dueña o Administrador activo para gestionar el personal.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _claveCtrl,
              obscureText: _ocultarClave,
              autofocus: true,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Contraseña de Dueña/Admin',
                labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                prefixIcon: Icon(Icons.lock_outline, color: AppColors.primary, size: 20),
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
                errorText: _errorMensaje,
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
                  return 'Ingresa la contraseña para autorizar';
                }
                return null;
              },
              onFieldSubmitted: (_) => _validarYConfirmar(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _validando ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton(
          onPressed: _validando ? null : _validarYConfirmar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          child: _validando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'Verificar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}

