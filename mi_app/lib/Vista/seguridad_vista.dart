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
            content: Text('La contrasena actual no coincide.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      await widget.controladorAutenticacion.cambiarClave(user.id, _nuevaClave);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contrasena actualizada exitosamente.'),
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
        title: const Text('Seguridad de la Cuenta'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cambiar Contrasena',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Contrasena actual',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                ),
                obscureText: true,
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
                onSaved: (v) => _claveActual = v!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Nueva contrasena',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                ),
                obscureText: true,
                validator: (v) =>
                    v != null && v.length < 6 ? 'Minimo 6 caracteres' : null,
                onSaved: (v) => _nuevaClave = v!,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _guardar,
                  child: const Text(
                    'Actualizar Contrasena',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
