import 'package:flutter/material.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_autenticacion.dart';
import '../Modelos/colaborador.dart';

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
    setState(() {
      _empleados = emp;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Empleados'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _empleados.length,
              itemBuilder: (context, index) {
                final emp = _empleados[index];
                return Card(
                  color: AppColors.surfaceContainerLowest,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.outlineVariant),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryContainer,
                      child: Icon(
                        Icons.person,
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      emp.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Rol: ${emp.rol.toUpperCase()}'),
                    trailing: Text(
                      'ID: ${emp.id}',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
