import 'package:flutter/material.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_autenticacion.dart';

class SeguridadVista extends StatefulWidget {
  final ControladorAutenticacion controladorAutenticacion;

  const SeguridadVista({super.key, required this.controladorAutenticacion});

  @override
  State<SeguridadVista> createState() => _SeguridadVistaState();
}

class _SeguridadVistaState extends State<SeguridadVista> {
  final _formKey = GlobalKey<FormState>();
  final _nuevaClaveController = TextEditingController();
  final _confirmarClaveController = TextEditingController();
  String _claveActual = '';

  @override
  void dispose() {
    _nuevaClaveController.dispose();
    _confirmarClaveController.dispose();
    super.dispose();
  }

  void _guardar() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final user = widget.controladorAutenticacion.usuarioActual;

      if (user == null) return;

      if (!widget.controladorAutenticacion.verificarClave(user, _claveActual)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La contraseña actual no coincide.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final nuevaClave = _nuevaClaveController.text.trim();
      await widget.controladorAutenticacion.cambiarClave(user.id, nuevaClave);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contraseña actualizada exitosamente.'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            title: Text(
              'Seguridad de la Cuenta',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppColors.surface,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
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
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Contraseña actual',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.secondarySurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: TextStyle(color: AppColors.textPrimary),
                          obscureText: true,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Requerido' : null,
                          onSaved: (v) => _claveActual = v ?? '',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nuevaClaveController,
                          decoration: InputDecoration(
                            labelText: 'Nueva contraseña',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.secondarySurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: TextStyle(color: AppColors.textPrimary),
                          obscureText: true,
                          validator: (v) =>
                              v == null || v.length < 4
                                  ? 'Mínimo 4 caracteres'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmarClaveController,
                          decoration: InputDecoration(
                            labelText: 'Confirmar nueva contraseña',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.secondarySurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: TextStyle(color: AppColors.textPrimary),
                          obscureText: true,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            if (v != _nuevaClaveController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _guardar,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
