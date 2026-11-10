import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../Controladores/controlador_inicio.dart';
import '../Controladores/controlador_inventario.dart';
import '../Controladores/controlador_ventas.dart';
import '../Modelos/producto.dart';
import '../Tema/app_theme.dart';
import '../Utilidades/debouncer.dart';
import 'Widgets/tarjeta_pos_producto.dart';
import 'venta.dart';

class PosVista extends StatefulWidget {
  const PosVista({super.key});

  @override
  State<PosVista> createState() => _PosVistaState();
}

class _PosVistaState extends State<PosVista> {
  String _categoriaSeleccionada = 'all';
  String _busqueda = '';
  final TextEditingController _busquedaController = TextEditingController();
  final Debouncer _busquedaDebouncer =
      Debouncer(delay: const Duration(milliseconds: 300));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cVentas = context.read<ControladorVentas>();
      if (cVentas.ventaActual == null) {
        cVentas.iniciarVenta();
      }
    });
  }

  @override
  void dispose() {
    _busquedaDebouncer.dispose();
    _busquedaController.dispose();
    super.dispose();
  }

  void _abrirCobroModal() {
    final cVentas = context.read<ControladorVentas>();
    final cInventario = context.read<ControladorInventario>();
    final venta = cVentas.ventaActual;
    if (cVentas.totalArticulosEnCarrito == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un producto al ticket para cobrar.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VentaVista(
          controladorVentas: cVentas,
          controladorInventario: cInventario,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _mostrarAvisoSinUnidades() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.coral,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: const Text(
          'Este producto no tiene unidades disponibles.',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        action: SnackBarAction(
          label: 'Entendido',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Column(
              children: [
                _buildSearchBar(isLandscape),
                _buildCategoryChips(isLandscape),
                _buildContextStrip(isLandscape),
                Expanded(
                  child: Selector<ControladorInventario, List<Producto>>(
                    selector: (context, cInv) =>
                        cInv.productos.map((p) => p.copyWith()).toList(),
                    shouldRebuild: (previous, next) {
                      if (previous.length != next.length) return true;
                      return !listEquals(previous, next);
                    },
                    builder: (context, productosInventario, _) {
                      final productos = productosInventario.where((p) {
                        final coincide = _busqueda.isEmpty ||
                            p.coincideConBusqueda(_busqueda);
                        if (!coincide) return false;
                        if (_categoriaSeleccionada == 'planta') return p.esPlanta;
                        if (_categoriaSeleccionada == 'articulo') return p.esArticulo;
                        return true;
                      }).toList();

                      if (productos.isEmpty) {
                        return Center(
                          child: Text(
                            'No hay productos que coincidan con la búsqueda',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          isLandscape ? 4 : 8,
                          16,
                          88,
                        ),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isLandscape ? 4 : 2,
                          childAspectRatio: isLandscape ? 0.78 : 0.70,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: productos.length,
                        itemBuilder: (context, index) {
                          final producto = productos[index];

                          // Selector granular: sólo reconstruye la tarjeta afectada cuando
                          // cambia su cantidad individual en el carrito, sin redibujar el grid completo.
                          return Selector<ControladorVentas, int>(
                            selector: (context, cVentas) =>
                                cVentas.obtenerCantidadEnCarrito(producto.id),
                            builder: (context, cantidadEnTicket, _) {
                              return RepaintBoundary(
                                child: TarjetaPosProducto(
                                  producto: producto,
                                  cantidadEnTicket: cantidadEnTicket,
                                  onAgregar: () {
                                    try {
                                      context
                                          .read<ControladorVentas>()
                                          .agregarArticulo(producto, 1);
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(e
                                              .toString()
                                              .replaceAll('Exception: ', '')),
                                          backgroundColor: AppColors.error,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  onIncrementar: () {
                                    try {
                                      context
                                          .read<ControladorVentas>()
                                          .agregarArticulo(producto, 1);
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(e
                                              .toString()
                                              .replaceAll('Exception: ', '')),
                                          backgroundColor: AppColors.error,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  onDecrementar: () {
                                    context
                                        .read<ControladorVentas>()
                                        .decrementarArticulo(producto.id);
                                  },
                                  onSinUnidades: _mostrarAvisoSinUnidades,
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          bottomSheet: Selector<ControladorVentas, (int, double)>(
            selector: (_, cVentas) =>
                (cVentas.totalArticulosEnCarrito, cVentas.totalVentaActual),
            builder: (context, datosVenta, _) {
              final totalArticulos = datosVenta.$1;
              final totalVenta = datosVenta.$2;

              if (totalArticulos == 0) return const SizedBox.shrink();

              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isLandscape ? 6 : 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalArticulos ${totalArticulos == 1 ? "artículo" : "artículos"}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '\$${totalVenta.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: isLandscape ? 17 : 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _abrirCobroModal,
                        icon: Icon(Icons.shopping_bag_outlined,
                            size: isLandscape ? 16 : 18),
                        label: Text(
                          'Ver Ticket y Cobrar',
                          style: TextStyle(
                            fontSize: isLandscape ? 13 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isLandscape ? 12 : 16,
                            vertical: isLandscape ? 8 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(bool isLandscape) {
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, isLandscape ? 6 : 12, 16, isLandscape ? 4 : 6),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.secondarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: RepaintBoundary(
            child: TextField(
              controller: _busquedaController,
              onChanged: (val) {
                _busquedaDebouncer.run(() {
                  if (mounted) {
                    setState(() => _busqueda = val.trim());
                  }
                });
              },
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar planta o variedad...',
                hintStyle:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isLandscape ? 8 : 12,
                ),
                suffixIcon: _busqueda.isNotEmpty || _busquedaController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          _busquedaDebouncer.cancel();
                          _busquedaController.clear();
                          setState(() => _busqueda = '');
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(bool isLandscape) {
    const categorias = [
      {'id': 'all', 'label': 'Todos'},
      {'id': 'planta', 'label': 'Plantas'},
      {'id': 'articulo', 'label': 'Artículos'},
    ];

    return SizedBox(
      height: isLandscape ? 36 : 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        itemCount: categorias.length,
        itemBuilder: (context, index) {
          final cat = categorias[index];
          final isSelected = _categoriaSeleccionada == cat['id'];
          return GestureDetector(
            onTap: () {
              setState(() {
                _categoriaSeleccionada = cat['id']!;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 12 : 16,
                vertical: isLandscape ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brightGreen
                    : AppColors.secondarySurface,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                cat['label']!,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.onPrimary
                      : AppColors.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContextStrip(bool isLandscape) {
    String titulo = 'CATÁLOGO GENERAL';
    IconData icono = Icons.storefront_outlined;
    if (_categoriaSeleccionada == 'planta') {
      titulo = 'CATÁLOGO DE PLANTAS';
      icono = Icons.eco_outlined;
    } else if (_categoriaSeleccionada == 'articulo') {
      titulo = 'CATÁLOGO DE ARTÍCULOS';
      icono = Icons.inventory_2_outlined;
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isLandscape ? 2 : 6,
      ),
      child: Row(
        children: [
          Icon(icono, color: AppColors.primary, size: 14),
          const SizedBox(width: 4),
          Text(
            titulo,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
