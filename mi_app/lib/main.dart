import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'Tema/app_theme.dart';
import 'Vista/splash_vista.dart';

import 'BaseDatos/base_datos.dart';
import 'Servicios/secure_storage_service.dart';
import 'Controladores/controlador_inicio.dart';
import 'Controladores/controlador_inventario.dart';
import 'Controladores/controlador_ventas.dart';
import 'Controladores/controlador_finanzas.dart';
import 'Controladores/controlador_perfil.dart';
import 'Controladores/controlador_autenticacion.dart';
import 'IA/Controladores/controlador_ia_compras.dart';
import 'Modelos/producto.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En modo Release se inhabilitan los logs de depuración para prevenir fugas de datos en Logcat
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Instanciación de servicios y controladores principales
  final secureStorage = SecureStorageService.instancia;
  final baseDeDatos = BaseDeDatos.instancia;

  final controladorInventario = ControladorInventario();
  final controladorFinanzas = ControladorFinanzas();
  final controladorPerfil = ControladorPerfil();
  final controladorAutenticacion = ControladorAutenticacion();
  final controladorIA = ControladorIACompras(
    controladorInventario: controladorInventario,
  );

  final controladorVentas = ControladorVentas(
    controladorInventario: controladorInventario,
    controladorFinanzas: controladorFinanzas,
    controladorPerfil: controladorPerfil,
    controladorIA: controladorIA,
  );

  final controladorInicio = ControladorInicio(
    controladorInventario: controladorInventario,
    controladorVentas: controladorVentas,
    controladorFinanzas: controladorFinanzas,
    controladorPerfil: controladorPerfil,
    controladorIA: controladorIA,
  );
  try {
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
  } catch (e, stack) {
    debugPrint('Aviso de inicialización offline: $e\n$stack');
  }

  runApp(
    MultiProvider(
      providers: [
        // Servicios de infraestructura y seguridad
        Provider<BaseDeDatos>.value(value: baseDeDatos),
        Provider<SecureStorageService>.value(value: secureStorage),

        // Controladores de lógica de negocio y repositorios
        ChangeNotifierProvider<ControladorInventario>.value(value: controladorInventario),
        Provider<ControladorFinanzas>.value(value: controladorFinanzas),
        Provider<ControladorPerfil>.value(value: controladorPerfil),
        ChangeNotifierProvider<ControladorAutenticacion>.value(value: controladorAutenticacion),
        ChangeNotifierProvider<ControladorVentas>.value(value: controladorVentas),
        Provider<ControladorInicio>.value(value: controladorInicio),

        // Controlador de IA reactivo (ChangeNotifier)
        ChangeNotifierProvider<ControladorIACompras>.value(value: controladorIA),
      ],
      child: ViverApp(
        controladorInicio: controladorInicio,
        controladorInventario: controladorInventario,
        controladorVentas: controladorVentas,
        controladorAutenticacion: controladorAutenticacion,
      ),
    ),
  );
}

class ViverApp extends StatelessWidget {
  final ControladorInicio? controladorInicio;
  final ControladorInventario? controladorInventario;
  final ControladorVentas? controladorVentas;
  final ControladorAutenticacion? controladorAutenticacion;

  const ViverApp({
    super.key,
    this.controladorInicio,
    this.controladorInventario,
    this.controladorVentas,
    this.controladorAutenticacion,
  });

  @override
  Widget build(BuildContext context) {
    final cInicio = controladorInicio ?? context.read<ControladorInicio>();
    final cInventario = controladorInventario ?? context.read<ControladorInventario>();
    final cVentas = controladorVentas ?? context.read<ControladorVentas>();
    final cAuth = controladorAutenticacion ?? context.read<ControladorAutenticacion>();

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
          home: SplashVista(
            controladorInicio: cInicio,
            controladorInventario: cInventario,
            controladorVentas: cVentas,
            controladorAutenticacion: cAuth,
          ),
        );
      },
    );
  }
}
