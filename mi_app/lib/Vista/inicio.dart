import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Controladores/controlador_inicio.dart';
import '../Controladores/controlador_inventario.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_autenticacion.dart';
import '../Modelos/colaborador.dart';
import '../Tema/app_theme.dart';
import '../Tema/isometric_cube_icon.dart';
import 'pos_vista.dart';
import 'inventario_vista.dart';
import 'nuevo_lote.dart';
import 'perfil.dart';
import 'login.dart';
import 'Widgets/dashboard_vista.dart';
import 'Widgets/notificaciones_stock_sheet.dart';
import 'Widgets/app_logo.dart';
import '../Servicios/secure_storage_service.dart';

class InicioVista extends StatefulWidget {
  const InicioVista({super.key});

  @override
  State<InicioVista> createState() => _InicioVistaState();
}

class _InicioVistaState extends State<InicioVista> {
  int _indiceActual = 0;
  final List<int> _historialTabs = [0];

  /// Carga perezosa (Lazy Loading): Arreglo de 4 posiciones que inicializa las vistas bajo demanda.
  /// Evita inflar y retener los 4 árboles de widgets en memoria en el arranque inicial de la app.
  final List<Widget?> _paginas = List.filled(4, null);

  @override
  void initState() {
    super.initState();
    final authCtrl = context.read<ControladorAutenticacion>();
    final esEmpleado =
        authCtrl.usuarioActual?.rol == RolUsuario.empleado;
    if (esEmpleado) {
      _indiceActual = 1;
      _historialTabs.clear();
      _historialTabs.add(1);
    }
  }

  /// Retorna la vista correspondiente al índice especificado, instanciándola de forma perezosa
  /// únicamente la primera vez que el usuario la visita y conservando su instancia única en memoria.
  Widget _construirPagina(int indice) {
    if (_paginas[indice] == null) {
      switch (indice) {
        case 0:
          _paginas[0] = DashboardVista(
            alNavegar: (idx) => _navegarA(idx),
          );
          break;
        case 1:
          _paginas[1] = const PosVista();
          break;
        case 2:
          _paginas[2] = const InventarioVista();
          break;
        case 3:
          _paginas[3] = PerfilVista(
            onLogout: _cerrarSesion,
          );
          break;
        default:
          return const SizedBox.shrink();
      }
    }
    return _paginas[indice]!;
  }

  Future<void> _cerrarSesion() async {
    await SecureStorageService.instancia
        .guardar('planteapp_recordar_sesion', 'false');
    await SecureStorageService.instancia
        .eliminar('planteapp_token_sesion_recordada');
    if (!mounted) return;
    context.read<ControladorAutenticacion>().cerrarSesion();
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoginVista(),
      ),
    );
  }

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
      await SecureStorageService.instancia
          .guardar('planteapp_recordar_sesion', 'false');
      await SecureStorageService.instancia
          .eliminar('planteapp_token_sesion_recordada');
      context.read<ControladorAutenticacion>().cerrarSesion();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginVista(),
        ),
      );
    }
  }

  /// Construye dinámicamente el botón flotante según la pestaña activa del Scaffold principal.
  /// Evita la aparición de botones fantasma al regresar de subpantallas (como Empleados).
  Widget? _buildFloatingActionButton() {
    switch (_indiceActual) {
      case 2: // Pestaña de Inventario
        final rolActual = context.read<ControladorAutenticacion>().usuarioActual?.rol;
        final bool puedeModificar = rolActual?.puedeModificarInventario ?? true;
        if (!puedeModificar) return null;

        return FloatingActionButton(
          key: const ValueKey('fab_inventario_principal'),
          heroTag: 'fab_inventario_principal',
          tooltip: 'Añadir nuevo producto',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NuevoLoteVista(
                  controladorInventario: context.read<ControladorInventario>(),
                ),
              ),
            ).then((_) {
              context.read<ControladorInventario>().cargarProductos();
              if (mounted) setState(() {});
            });
          },
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.onSecondary,
          elevation: 3,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 28),
        );

      case 3: // Pestaña de "Mi Cuenta": estrictamente null para evitar botones fantasma
      case 0: // Inicio / Dashboard
      case 1: // Punto de Venta
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        final cInventario = context.watch<ControladorInventario>();
        final productosBajoStock = cInventario.productos
            .where((p) => p.esStockCritico)
            .toList();

        String titulo = 'Inicio';
        String subtitulo = 'Planteapp';
        if (_indiceActual == 0) {
          titulo = 'Inicio';
          subtitulo = 'Resumen General';
        } else if (_indiceActual == 1) {
          titulo = 'Punto de Venta';
          subtitulo = 'Planteapp';
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
            resizeToAvoidBottomInset: false,
            backgroundColor: AppColors.surface,
            floatingActionButton: _buildFloatingActionButton(),
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
                              const AppLogo.compact(size: 34),
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
                                NotificacionesStockSheet.mostrar(
                                  context: context,
                                  productosBajoStock: productosBajoStock,
                                  onNavegarAInventario: () {
                                    _navegarA(2);
                                  },
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
                    child: KeyedSubtree(
                      key: ValueKey<int>(_indiceActual),
                      child: _construirPagina(_indiceActual),
                    ),
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
