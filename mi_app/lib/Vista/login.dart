import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Tema/app_theme.dart';
import 'inicio.dart';
import '../Controladores/controlador_inicio.dart';
import '../Controladores/controlador_inventario.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_autenticacion.dart';

class LoginVista extends StatefulWidget {
  final ControladorInicio controladorInicio;
  final ControladorInventario controladorInventario;
  final ControladorVentas controladorVentas;
  final ControladorAutenticacion controladorAutenticacion;

  const LoginVista({
    super.key,
    required this.controladorInicio,
    required this.controladorInventario,
    required this.controladorVentas,
    required this.controladorAutenticacion,
  });

  @override
  State<LoginVista> createState() => _LoginVistaState();
}

class _LoginVistaState extends State<LoginVista> {
  final _usuarioController = TextEditingController(text: 'VO-4092');
  final _claveController = TextEditingController(text: '123456');
  bool _ocultarClave = true;
  bool _recordarTerminal = true;
  bool _isLoading = false;
  bool _isSuccess = false;

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
    final exito = await widget.controladorAutenticacion.iniciarSesion(
      id,
      clave,
    );

    if (!mounted) return;

    if (exito) {
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InicioVista(
              controladorInicio: widget.controladorInicio,
              controladorInventario: widget.controladorInventario,
              controladorVentas: widget.controladorVentas,
              controladorAutenticacion: widget.controladorAutenticacion,
            ),
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
          backgroundColor: AppColors.surfaceContainerLowest,
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
          content: const Text(
            'Usuario o PIN incorrectos. Por favor, intenta de nuevo.',
            style: TextStyle(color: AppColors.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
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
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 96,
              height: 96,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_florist,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.spa,
                  color: AppColors.onPrimary,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Vivero',
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Terminal de Punto de Venta • Iniciar Sesión',
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Usuario o correo',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _usuarioController,
              decoration: const InputDecoration(
                prefixIcon: Icon(
                  Icons.badge,
                  color: AppColors.onSurfaceVariant,
                ),
                hintText: 'Ej. VO-8421 o ana@vivero.pe',
                hintStyle: TextStyle(color: AppColors.outline),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'PIN de acceso o clave',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _claveController,
              obscureText: _ocultarClave,
              obscuringCharacter: '•',
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.lock,
                  color: AppColors.onSurfaceVariant,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _ocultarClave ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.onSurfaceVariant,
                  ),
                  onPressed: () =>
                      setState(() => _ocultarClave = !_ocultarClave),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 20),
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
                        : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: _recordarTerminal
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: AppColors.onPrimary,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Recordar terminal en este dispositivo',
                  style: TextStyle(color: AppColors.onSurface, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading || _isSuccess ? null : _iniciarSesion,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 1,
              ),
              child: _buildButtonContent(),
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
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: AppColors.onPrimary,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Abriendo caja...',
            style: TextStyle(
              color: AppColors.onPrimary,
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
          Icon(Icons.check_circle, color: AppColors.onPrimary, size: 20),
          SizedBox(width: 8),
          Text(
            '¡Sesión Iniciada!',
            style: TextStyle(
              color: AppColors.onPrimary,
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
              color: AppColors.onPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward, color: AppColors.onPrimary, size: 20),
        ],
      );
    }
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.surfaceContainerHigh, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'bienvenido',
            style: TextStyle(
              color: AppColors.onSurfaceVariant.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.surfaceContainerHigh, thickness: 1),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Text(
          'VIVERO POS • v1.0.2',
          style: TextStyle(
            color: AppColors.outline,
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
