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
  String _claveActual = '';
  String _nuevaClave = '';

  void _guardar() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final user = widget.controladorAutenticacion.usuarioActual;

      if (user == null) return;

      if (_claveActual != user.clave) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La contraseña actual no coincide.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      await widget.controladorAutenticacion.cambiarClave(user.id, _nuevaClave);

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
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      onSaved: (v) => _claveActual = v!,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
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
                          v!.length < 4 ? 'Mínimo 4 caracteres' : null,
                      onSaved: (v) => _nuevaClave = v!,
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
  }
}
