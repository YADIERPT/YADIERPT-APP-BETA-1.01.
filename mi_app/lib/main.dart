import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'Tema/app_theme.dart';
import 'Vista/login.dart';

import 'Controladores/controlador_inicio.dart';
import 'Controladores/controlador_inventario.dart';
import 'Controladores/controlador_ventas.dart';
import 'Controladores/controlador_finanzas.dart';
import 'Controladores/controlador_perfil.dart';
import 'Controladores/controlador_autenticacion.dart';
import 'Modelos/producto.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  final controladorInventario = ControladorInventario();
  final controladorFinanzas = ControladorFinanzas();
  final controladorPerfil = ControladorPerfil();
  final controladorAutenticacion = ControladorAutenticacion();

  final controladorVentas = ControladorVentas(
    controladorInventario: controladorInventario,
    controladorFinanzas: controladorFinanzas,
    controladorPerfil: controladorPerfil,
  );

  final controladorInicio = ControladorInicio(
    controladorInventario: controladorInventario,
    controladorVentas: controladorVentas,
    controladorFinanzas: controladorFinanzas,
    controladorPerfil: controladorPerfil,
  );
  await controladorInicio.inicializarDatosOffline();
  await controladorAutenticacion.cargarUsuariosPorDefecto();
  await ThemeManager.instance.inicializar();
  if (controladorInventario.productos.isEmpty) {
    final monstera = Producto(
      id: 'BOT-012',
      nombre: 'Monstera Deliciosa',
      notas: 'Luz tamiz',
      precioVenta: 28.00,
      costo: 10.00,
      cantidadEnInventario: 14,
      tipo: 'planta',
      imagenes: [
        'https://lh3.googleusercontent.com/aida-public/AB6AXuDzVZ9j8_4q9p5pqc4u_PmDq2owo1t5GSUSfk7MgiELHy2-YQ64qDbIklUrLJoJE1lC4bTIMTj4sMyx5eiN2g4m_jncrb3qNUvd51_X3E2aRj_AF8-r0ybK1uezldfn990ECPiAN6wtL5MJh7ajjEmbxg75EiTCDkIrTVXtIgWjdmpOdIa_MfdVj9BMU0sS8z2PUk02t6EEwqTv-AwmO-M6x4Jfm6ojNNVB2dVQT4IVpXavWuVJ12e9Cw',
      ],
    );
    final maceta = Producto(
      id: 'ART-001',
      nombre: 'Maceta Cerámica Blanca 15cm',
      notas: 'Maceta con drenaje y plato',
      precioVenta: 18.00,
      costo: 8.00,
      cantidadEnInventario: 20,
      tipo: 'articulo',
      imagenes: [],
    );
    await controladorInventario.agregarProducto(monstera);
    await controladorInventario.agregarProducto(maceta);
  }

  runApp(
    ViverApp(
      controladorInicio: controladorInicio,
      controladorInventario: controladorInventario,
      controladorVentas: controladorVentas,
      controladorAutenticacion: controladorAutenticacion,
    ),
  );
}

class ViverApp extends StatelessWidget {
  final ControladorInicio controladorInicio;
  final ControladorInventario controladorInventario;
  final ControladorVentas controladorVentas;
  final ControladorAutenticacion controladorAutenticacion;

  const ViverApp({
    super.key,
    required this.controladorInicio,
    required this.controladorInventario,
    required this.controladorVentas,
    required this.controladorAutenticacion,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'ViverApp POS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeManager.instance.themeMode,
          builder: (context, child) {
            final Widget contenido = child ?? const SizedBox.shrink();
            return Container(
              color: AppColors.appBackground,
              child: contenido,
            );
          },
          home: LoginVista(
            controladorInicio: controladorInicio,
            controladorInventario: controladorInventario,
            controladorVentas: controladorVentas,
            controladorAutenticacion: controladorAutenticacion,
          ),
        );
      },
    );
  }
}
