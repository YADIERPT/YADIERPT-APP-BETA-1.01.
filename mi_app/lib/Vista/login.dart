import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../Tema/app_theme.dart';
import 'inicio.dart';
import 'Widgets/app_logo.dart';
import '../Controladores/controlador_inicio.dart';
import '../Controladores/controlador_inventario.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_autenticacion.dart';
import '../Controladores/controlador_biometrico.dart';
import '../Servicios/secure_storage_service.dart';

class LoginVista extends StatefulWidget {
  const LoginVista({super.key});

  @override
  State<LoginVista> createState() => _LoginVistaState();
}

class _LoginVistaState extends State<LoginVista> {
  final _usuarioController = TextEditingController();
  final _claveController = TextEditingController();
  bool _ocultarClave = true;
  bool _recordarTerminal = false;
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _cargarUltimoUsuario();
  }

  Future<void> _cargarUltimoUsuario() async {
    try {
      final secureStorage = SecureStorageService.instancia;
      final ultimoId = await secureStorage.leer('planteapp_ultimo_usuario_id');
      final recordar = await secureStorage.leer('planteapp_recordar_sesion');
      if (mounted) {
        setState(() {
          if (ultimoId != null && ultimoId.isNotEmpty) {
            _usuarioController.text = ultimoId;
          }
          _recordarTerminal = (recordar == 'true');
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _claveController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    setState(() {
      _isLoading = true;
    });

    final id = _usuarioController.text.trim();
    final clave = _claveController.text.trim();
    final exito = await context.read<ControladorAutenticacion>().iniciarSesion(
      id,
      clave,
    );

    if (!mounted) return;

    if (exito) {
      final secureStorage = SecureStorageService.instancia;
      if (_recordarTerminal) {
        await secureStorage.guardar('planteapp_recordar_sesion', 'true');
        await secureStorage.guardar('planteapp_ultimo_usuario_id', id);
      } else {
        await secureStorage.guardar('planteapp_recordar_sesion', 'false');
      }

      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const InicioVista(),
          ),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: const [
              Icon(Icons.error_outline, color: AppColors.error),
              SizedBox(width: 8),
              Text('Error de Acceso', style: TextStyle(color: AppColors.error)),
            ],
          ),
          content: Text(
            'Usuario o PIN incorrectos. Por favor, intenta de nuevo.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Entendido',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _iniciarSesionConHuella() async {
    final bioCtrl = context.read<ControladorBiometrico>();
    if (!bioCtrl.tieneHuellaRegistrada) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No hay ninguna huella configurada. Inicia sesión con tus credenciales y configúrala en Cuenta > Lector de Huellas.',
          ),
          backgroundColor: AppColors.amber,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final String? usuarioId = await bioCtrl.autenticarAcceso();

    if (usuarioId != null) {
      final bool exito =
          await context.read<ControladorAutenticacion>().iniciarSesionPorId(usuarioId);

      if (!mounted) return;

      if (exito) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const InicioVista(),
            ),
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Huella no reconocida o autenticación cancelada.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            AppColors.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            AppColors.isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 24.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildEmblemAndTitle(),
                          const SizedBox(height: 32),
                          _buildLoginForm(),
                          const SizedBox(height: 24),
                          _buildDivider(),
                        ],
                      ),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmblemAndTitle() {
    return const AppLogo.splash(
      size: 104.0,
      appName: 'Planteapp',
      subtitle: 'Terminal de Punto de Venta • Iniciar Sesión',
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Usuario o correo',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _usuarioController,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.badge_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                hintText: 'Ej. VO-8421 o ana@vivero.pe',
                hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'PIN de acceso o clave',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _claveController,
              obscureText: _ocultarClave,
              obscuringCharacter: '•',
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                hintText: 'PIN o contraseña',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _ocultarClave ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _ocultarClave = !_ocultarClave),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => setState(() => _recordarTerminal = !_recordarTerminal),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _recordarTerminal
                        ? AppColors.primary
                        : AppColors.secondarySurface,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: _recordarTerminal
                          ? AppColors.primary
                          : AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: _recordarTerminal
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recordar datos en este dispositivo',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading || _isSuccess ? null : _iniciarSesion,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _buildButtonContent(),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'o ingresa biométricamente',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppColors.border)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed:
                  _isLoading || _isSuccess ? null : _iniciarSesionConHuella,
              icon: Icon(Icons.fingerprint, color: AppColors.primary, size: 22),
              label: Text(
                'Acceder con Huella Digital',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: context.read<ControladorBiometrico>()
                          .tieneHuellaRegistrada
                      ? AppColors.primary
                      : AppColors.border,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonContent() {
    if (_isLoading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Ingresando...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else if (_isSuccess) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.check_circle, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            '¡Bienvenido!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text(
            'Ingresar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward, color: Colors.white, size: 18),
        ],
      );
    }
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: AppColors.border, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'punto de venta',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: AppColors.border, thickness: 1),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'VIVERO • PLANTEAPP',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
