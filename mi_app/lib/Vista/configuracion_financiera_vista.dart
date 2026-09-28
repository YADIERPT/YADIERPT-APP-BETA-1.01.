import 'package:flutter/material.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_perfil.dart';

class ConfiguracionFinancieraVista extends StatefulWidget {
  final ControladorPerfil controladorPerfil;

  const ConfiguracionFinancieraVista({
    super.key,
    required this.controladorPerfil,
  });

  @override
  State<ConfiguracionFinancieraVista> createState() =>
      _ConfiguracionFinancieraVistaState();
}

class _ConfiguracionFinancieraVistaState
    extends State<ConfiguracionFinancieraVista> {
  late bool _aplicarIva;
  late double _iva;

  @override
  void initState() {
    super.initState();
    _aplicarIva = widget.controladorPerfil.configuracion.aplicarIva;
    _iva = widget.controladorPerfil.configuracion.porcentajeIvaDefecto;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Configuracion Financiera'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SwitchListTile(
            title: const Text('Aplicar IVA a las ventas'),
            subtitle: const Text(
              'Si se desactiva, los tickets no cobraran impuestos.',
            ),
            value: _aplicarIva,
            activeColor: AppColors.primary,
            onChanged: (val) async {
              await widget.controladorPerfil.alternarAplicarIva(val);
              setState(() => _aplicarIva = val);
            },
          ),
          const SizedBox(height: 24),
          ListTile(
            title: Text('Porcentaje de IVA actual: ${(_iva * 100).toInt()}%'),
            subtitle: const Text('Configura el impuesto estandar.'),
            trailing: const Icon(Icons.edit),
            onTap: () {
              // En un futuro se puede agregar un dialogo para cambiar el %
            },
          ),
        ],
      ),
    );
  }
}
