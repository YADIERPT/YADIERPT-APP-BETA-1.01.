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
    if (mounted) {
      setState(() {
        _empleados = emp;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: _cargando
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
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
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryContainer,
                      child: Icon(
                        Icons.person,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      emp.nombre,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Rol: ${emp.rol.toUpperCase()}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    trailing: Text(
                      'ID: ${emp.id}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
