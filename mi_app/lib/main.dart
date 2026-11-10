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
import 'Controladores/controlador_biometrico.dart';
import 'Controladores/controlador_hardware.dart';
import 'Controladores/controlador_cuentas_por_cobrar.dart';
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
  final controladorBiometrico = ControladorBiometrico();
  final controladorHardware = ControladorHardware();
  final controladorIA = ControladorIACompras(
    controladorInventario: controladorInventario,
  );

  final controladorVentas = ControladorVentas(
    controladorInventario: controladorInventario,
    controladorFinanzas: controladorFinanzas,
    controladorPerfil: controladorPerfil,
    controladorIA: controladorIA,
  );

  final controladorCuentasPorCobrar = ControladorCuentasPorCobrar(
    controladorVentas: controladorVentas,
    controladorFinanzas: controladorFinanzas,
  );

  final controladorInicio = ControladorInicio(
    controladorInventario: controladorInventario,
    controladorVentas: controladorVentas,
    controladorFinanzas: controladorFinanzas,
    controladorPerfil: controladorPerfil,
    controladorIA: controladorIA,
    controladorBiometrico: controladorBiometrico,
  );
  // Cargar siempre la cuenta administradora por defecto en un bloque aislado
  try {
    await controladorAutenticacion.cargarUsuariosPorDefecto();
  } catch (e, stack) {
    debugPrint('Aviso al cargar usuarios por defecto: $e\n$stack');
  }

  try {
    await controladorInicio.inicializarDatosOffline();
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
          'assets/images/planta_default.png',
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
        // Servicios de infraestructura y persistencia
        Provider<BaseDeDatos>.value(value: baseDeDatos),
        Provider<SecureStorageService>.value(value: secureStorage),

        // Controladores de lógica de negocio y repositorios
        ChangeNotifierProvider<ControladorInventario>.value(value: controladorInventario),
        ChangeNotifierProvider<ControladorFinanzas>.value(value: controladorFinanzas),
        Provider<ControladorPerfil>.value(value: controladorPerfil),
        ChangeNotifierProvider<ControladorAutenticacion>.value(value: controladorAutenticacion),
        ChangeNotifierProvider<ControladorVentas>.value(value: controladorVentas),
        ChangeNotifierProvider<ControladorCuentasPorCobrar>.value(value: controladorCuentasPorCobrar),
        ChangeNotifierProvider<ControladorInicio>.value(value: controladorInicio),
        ChangeNotifierProvider<ControladorIACompras>.value(value: controladorIA),
        ChangeNotifierProvider<ControladorHardware>.value(value: controladorHardware),
        Provider<ControladorBiometrico>.value(value: controladorBiometrico),
      ],
      child: const ViverApp(),
    ),
  );
}

class ViverApp extends StatelessWidget {
  const ViverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        return MaterialApp(
          scaffoldMessengerKey: ControladorHardware.scaffoldMessengerKey,
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
          home: const SplashVista(),
        );
      },
    );
  }
}
