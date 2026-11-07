import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Tema/app_theme.dart';
import 'Widgets/app_logo.dart';
import 'login.dart';
import 'inicio.dart';
import '../Servicios/secure_storage_service.dart';
import '../Controladores/controlador_inicio.dart';
import '../Controladores/controlador_inventario.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_autenticacion.dart';

/// Pantalla de presentación (Splash Screen) con animación sutil de entrada,
/// logotipo corporativo centrado respetando el modo oscuro, y transición fluida
/// hacia la pantalla de inicio de sesión (Login).
class SplashVista extends StatefulWidget {
  final ControladorInicio? controladorInicio;
  final ControladorInventario? controladorInventario;
  final ControladorVentas? controladorVentas;
  final ControladorAutenticacion? controladorAutenticacion;

  const SplashVista({
    super.key,
    this.controladorInicio,
    this.controladorInventario,
    this.controladorVentas,
    this.controladorAutenticacion,
  });

  @override
  State<SplashVista> createState() => _SplashVistaState();
}

class _SplashVistaState extends State<SplashVista>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _transicionTimer;

  @override
  void initState() {
    super.initState();

    // Controlador para aparición suave del emblema y nombre
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();

    // Temporizador de presentación inicial (2.0 segundos de exposición)
    _transicionTimer =
        Timer(const Duration(milliseconds: 2000), _evaluarSesionYDestino);
  }

  @override
  void dispose() {
    _transicionTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _evaluarSesionYDestino() async {
    if (!mounted) return;

    final cInicio = widget.controladorInicio ?? context.read<ControladorInicio>();
    final cInventario = widget.controladorInventario ?? context.read<ControladorInventario>();
    final cVentas = widget.controladorVentas ?? context.read<ControladorVentas>();
    final cAuth = widget.controladorAutenticacion ?? context.read<ControladorAutenticacion>();

    try {
      final secureStorage = SecureStorageService.instancia;
      final recordar = await secureStorage.leer('planteapp_recordar_sesion');
      final ultimoId = await secureStorage.leer('planteapp_ultimo_usuario_id');

      if (recordar == 'true' && ultimoId != null && ultimoId.trim().isNotEmpty) {
        final exito = await cAuth.iniciarSesionPorId(ultimoId.trim());
        if (exito && mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 500),
              pageBuilder: (context, animation, secondaryAnimation) {
                return InicioVista(
                  controladorInicio: cInicio,
                  controladorInventario: cInventario,
                  controladorVentas: cVentas,
                  controladorAutenticacion: cAuth,
                );
              },
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Aviso: Verificación de sesión recordada: $e');
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) {
          return LoginVista(
            controladorInicio: cInicio,
            controladorInventario: cInventario,
            controladorVentas: cVentas,
            controladorAutenticacion: cAuth,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  // Emblema botánico y logotipo centrado
                  const AppLogo.splash(
                    size: 110.0,
                    showAppName: true,
                    appName: 'Planteapp',
                    subtitle: 'Terminal de Punto de Venta Botánico',
                  ),
                  const Spacer(flex: 2),
                  // Indicador de carga discreto adaptado a la paleta no sobresaturada
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Cargando sistema seguro...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

