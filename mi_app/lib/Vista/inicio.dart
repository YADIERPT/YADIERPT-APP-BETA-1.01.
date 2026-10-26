import 'package:flutter/material.dart';

import '../Controladores/controlador_inicio.dart';
import '../Controladores/controlador_inventario.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_autenticacion.dart';
import '../Tema/app_theme.dart';
import '../Tema/isometric_cube_icon.dart';
import 'pos_vista.dart';
import 'inventario_vista.dart';
import 'perfil.dart';
import 'login.dart';
import 'Widgets/dashboard_vista.dart';
import 'Widgets/notificaciones_stock_sheet.dart';

class InicioVista extends StatefulWidget {
  final ControladorInicio controladorInicio;
  final ControladorInventario controladorInventario;
  final ControladorVentas controladorVentas;
  final ControladorAutenticacion controladorAutenticacion;

  const InicioVista({
    super.key,
    required this.controladorInicio,
    required this.controladorInventario,
    required this.controladorVentas,
    required this.controladorAutenticacion,
  });

  @override
  State<InicioVista> createState() => _InicioVistaState();
}

class _InicioVistaState extends State<InicioVista> {
  int _indiceActual = 0;
  final List<int> _historialTabs = [0];

  void _navegarA(int indice) {
    if (_indiceActual != indice) {
      _historialTabs.add(indice);
      setState(() {
        _indiceActual = indice;
      });
    }
  }

  Future<void> _manejarRegreso() async {
    if (_indiceActual != 0) {
      if (_historialTabs.isNotEmpty && _historialTabs.last == _indiceActual) {
        _historialTabs.removeLast();
      }
      int nuevoIndice = 0;
      if (_historialTabs.isNotEmpty) {
        nuevoIndice = _historialTabs.last;
      } else {
        _historialTabs.add(0);
      }
      setState(() {
        _indiceActual = nuevoIndice;
      });
    } else {
      await _confirmarCerrarSesion();
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final bool? salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Cerrar sesión?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas cerrar sesión de Planteapp?',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (salir == true && mounted) {
      widget.controladorAutenticacion.cerrarSesion();
      Navigator.of(context, rootNavigator: true).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginVista(
            controladorInicio: widget.controladorInicio,
            controladorInventario: widget.controladorInventario,
            controladorVentas: widget.controladorVentas,
            controladorAutenticacion: widget.controladorAutenticacion,
          ),
        ),
      );
    }
  }

  List<Widget> _obtenerPaginas() {
    return [
      DashboardVista(
        controladorInicio: widget.controladorInicio,
        controladorInventario: widget.controladorInventario,
        controladorVentas: widget.controladorVentas,
        controladorAutenticacion: widget.controladorAutenticacion,
        alNavegar: (indice) {
          _navegarA(indice);
        },
      ),
      PosVista(
        controladorInicio: widget.controladorInicio,
        controladorInventario: widget.controladorInventario,
        controladorVentas: widget.controladorVentas,
      ),
      InventarioVista(controladorInventario: widget.controladorInventario),
      PerfilVista(
        controladorPerfil: widget.controladorInicio.controladorPerfil,
        controladorVentas: widget.controladorVentas,
        controladorAutenticacion: widget.controladorAutenticacion,
        controladorBiometrico: widget.controladorInicio.controladorBiometrico,
        onLogout: () {
          widget.controladorAutenticacion.cerrarSesion();
          Navigator.of(context, rootNavigator: true).pushReplacement(
            MaterialPageRoute(
              builder: (context) => LoginVista(
                controladorInicio: widget.controladorInicio,
                controladorInventario: widget.controladorInventario,
                controladorVentas: widget.controladorVentas,
                controladorAutenticacion: widget.controladorAutenticacion,
              ),
            ),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        final paginas = _obtenerPaginas();
        final productosBajoStock = widget.controladorInventario.productos
            .where((p) => p.esStockCritico)
            .toList();

        String titulo = 'Inicio';
        String subtitulo = 'Vivero';
        if (_indiceActual == 0) {
          titulo = 'Inicio';
          subtitulo = 'Resumen General';
        } else if (_indiceActual == 1) {
          titulo = 'Punto de Venta';
          subtitulo = 'Vivero';
        } else if (_indiceActual == 2) {
          titulo = 'Inventario';
          subtitulo = 'Control Botánico';
        } else if (_indiceActual == 3) {
          titulo = 'Mi Cuenta';
          subtitulo = 'Configuración';
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _manejarRegreso();
          },
          child: Scaffold(
            backgroundColor: AppColors.surface,
            body: SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isLandscape ? 5 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _manejarRegreso,
                                icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                color: AppColors.textPrimary,
                                tooltip: 'Regresar',
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.eco, color: AppColors.primary, size: isLandscape ? 22 : 28),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            titulo,
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: isLandscape ? 14 : 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        if (isLandscape) ...[
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              '· $subtitulo',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 11,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (!isLandscape)
                                      Text(
                                        subtitulo,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: AppColors.card,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(24),
                                    ),
                                  ),
                                  builder: (context) =>
                                      NotificacionesStockSheet(
                                    productosBajoStock: productosBajoStock,
                                  ),
                                );
                              },
                              child: Container(
                                width: isLandscape ? 30 : 36,
                                height: isLandscape ? 30 : 36,
                                decoration: BoxDecoration(
                                  color: AppColors.secondarySurface,
                                  shape: BoxShape.circle,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.notifications_none,
                                      color: AppColors.textPrimary,
                                      size: isLandscape ? 17 : 20,
                                    ),
                                    if (productosBajoStock.isNotEmpty)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            color: AppColors.error,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.card,
                                              width: 1.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                _navegarA(3);
                              },
                              child: Container(
                                width: isLandscape ? 30 : 36,
                                height: isLandscape ? 30 : 36,
                                decoration: BoxDecoration(
                                  color: AppColors.secondarySurface,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person_outline,
                                  color: AppColors.textPrimary,
                                  size: isLandscape ? 17 : 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(index: _indiceActual, children: paginas),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: isLandscape ? 2 : 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTabItem(Icons.home_outlined, Icons.home, 'Inicio', 0, isLandscape),
                      _buildTabItem(
                        Icons.shopping_cart_outlined,
                        Icons.shopping_cart,
                        'Ventas',
                        1,
                        isLandscape,
                      ),
                      _buildTabItem(
                        Icons.view_in_ar_outlined,
                        Icons.view_in_ar_outlined,
                        'Inventario',
                        2,
                        isLandscape,
                      ),
                      _buildTabItem(
                        Icons.person_outline,
                        Icons.person,
                        'Mi Cuenta',
                        3,
                        isLandscape,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabItem(
    IconData iconoNormal,
    IconData iconoActivo,
    String etiqueta,
    int indice,
    bool isLandscape,
  ) {
    bool estaActivo = _indiceActual == indice;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _navegarA(indice);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isLandscape ? 1 : 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: isLandscape ? 12 : 18,
                  vertical: isLandscape ? 2 : 5,
                ),
                decoration: BoxDecoration(
                  color: estaActivo
                      ? AppColors.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: indice == 2
                    ? IsometricCubeIcon(
                        size: isLandscape ? 18 : 22,
                        color: estaActivo
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        strokeWidth: 1.8,
                      )
                    : Icon(
                        estaActivo ? iconoActivo : iconoNormal,
                        color: estaActivo
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: isLandscape ? 18 : 22,
                      ),
              ),
              SizedBox(height: isLandscape ? 1 : 3),
              Text(
                etiqueta,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: estaActivo
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontSize: isLandscape ? 9 : 10,
                  fontWeight: estaActivo ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
