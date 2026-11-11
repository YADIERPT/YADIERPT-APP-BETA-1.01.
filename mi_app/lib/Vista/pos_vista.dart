import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../Controladores/controlador_inicio.dart';
import '../Controladores/controlador_inventario.dart';
import '../Controladores/controlador_ventas.dart';
import '../Modelos/producto.dart';
import '../Modelos/venta.dart';
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 1. Lectura del ancho máximo disponible
                final bool esTablet = constraints.maxWidth >= 600;

                // 2. Si el ancho es MENOR a 600px (teléfono o vertical):
                // Retorna el diseño original (Lista de artículos en Expanded y panel de cobro debajo)
                if (!esTablet) {
                  return Column(
                    children: [
                      _buildSearchBar(false),
                      _buildCategoryChips(false),
                      _buildContextStrip(false),
                      Expanded(
                        child: _buildCatalogoGrid(esTablet: false),
                      ),
                    ],
                  );
                }

                // 3. Si el ancho es MAYOR a 600px (tablet en horizontal):
                // Retorna un Row que divide la pantalla profesionalmente:
                // - Lado izquierdo (60% del ancho): Catálogo o buscador rápido de productos
                // - Lado derecho (40% del ancho): Ticket en Curso y panel de cobro fijo
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Lado Izquierdo (60% del ancho): Catálogo o buscador rápido
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          _buildSearchBar(true),
                          _buildCategoryChips(true),
                          _buildContextStrip(true),
                          Expanded(
                            child: _buildCatalogoGrid(esTablet: true),
                          ),
                        ],
                      ),
                    ),

                    // Divisor sutil vertical
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),

                    // Lado Derecho (40% del ancho): Ticket en Curso y panel de cobro fijo
                    Expanded(
                      flex: 4,
                      child: _buildPanelTicketEnCurso(),
                    ),
                  ],
                );
              },
            ),
          ),
          bottomSheet: Selector<ControladorVentas, (int, double)>(
            selector: (_, cVentas) =>
                (cVentas.totalArticulosEnCarrito, cVentas.totalVentaActual),
            builder: (context, datosVenta, _) {
              // En pantallas tablet (ancho >= 600), el panel de cobro ya se encuentra fijo en el lado derecho
              final bool esPantallaAncha = MediaQuery.of(context).size.width >= 600;
              if (esPantallaAncha) return const SizedBox.shrink();

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
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Ver Ticket y Cobrar',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: isLandscape ? 13 : 14,
                              fontWeight: FontWeight.bold,
                            ),
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

  /// Construye la cuadrícula del catálogo de productos para POS
  Widget _buildCatalogoGrid({required bool esTablet}) {
    return Selector<ControladorInventario, List<Producto>>(
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

        final bool isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                esTablet ? 4 : 8,
                16,
                esTablet ? 16 : 88,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  childAspectRatio: isLandscape ? 0.85 : 0.72,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
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
                  childCount: productos.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Construye el panel lateral derecho (40% de ancho) para Tablets:
  /// Muestra el "Ticket en Curso" en tiempo real y el panel de cobro fijo.
  Widget _buildPanelTicketEnCurso() {
    return Consumer<ControladorVentas>(
      builder: (context, cVentas, _) {
        final venta = cVentas.ventaActual;
        final articulos = venta?.articulos ?? [];
        final totalArticulos = cVentas.totalArticulosEnCarrito;
        final totalVenta = cVentas.totalVentaActual;

        return Container(
          color: AppColors.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Cabecera del Ticket en Curso
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.subtleGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.receipt_long_outlined,
                        color: AppColors.brightGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ticket en Curso',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            totalArticulos == 0
                                ? 'Sin artículos añadidos'
                                : '$totalArticulos ${totalArticulos == 1 ? "artículo" : "artículos"}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (articulos.isNotEmpty)
                      Tooltip(
                        message: 'Vaciar ticket',
                        child: IconButton(
                          icon: Icon(
                            Icons.delete_sweep_outlined,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            cVentas.iniciarVenta();
                          },
                        ),
                      ),
                  ],
                ),
              ),

              // 2. Lista scrolleable de artículos del ticket
              Expanded(
                child: articulos.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 52,
                                color: AppColors.border,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Ticket Vacío',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Toca productos del catálogo para agregarlos al ticket.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: articulos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final art = articulos[index];
                          final prod = art.producto;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.secondarySurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                // Nombre del producto y precio unitario
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prod.nombre,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '\$${art.precioUnitario.toStringAsFixed(2)} c/u',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Controles de cantidad: [-] cantidad [+]
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border, width: 0.6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => cVentas.decrementarArticulo(prod.id),
                                        child: const Padding(
                                          padding: EdgeInsets.all(5.0),
                                          child: Icon(Icons.remove, size: 14),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          '${art.cantidad}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          try {
                                            cVentas.agregarArticulo(prod, 1);
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  e.toString().replaceAll('Exception: ', ''),
                                                ),
                                                backgroundColor: AppColors.error,
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(5.0),
                                          child: Icon(Icons.add, size: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 10),

                                // Subtotal por renglón
                                SizedBox(
                                  width: 58,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '\$${art.subtotal.toStringAsFixed(2)}',
                                      textAlign: TextAlign.end,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // 3. Panel de Cobro Fijo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (venta != null && venta.aplicarIva) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text('\$${venta.subtotalVenta.toStringAsFixed(2)}', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('IVA (${(venta.porcentajeIva * 100).toInt()}%)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text('\$${venta.totalIva.toStringAsFixed(2)}', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Divider(height: 1),
                      const SizedBox(height: 6),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '\$${totalVenta.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: articulos.isEmpty ? null : _abrirCobroModal,
                        icon: const Icon(Icons.point_of_sale, size: 18),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            articulos.isEmpty
                                ? 'Ticket Vacío'
                                : 'Cobrar Ticket (\$${totalVenta.toStringAsFixed(2)})',
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          disabledBackgroundColor: AppColors.border,
                          disabledForegroundColor: AppColors.textSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
