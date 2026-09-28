import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Controladores/controlador_inicio.dart';
import '../Controladores/controlador_inventario.dart';
import '../Controladores/controlador_ventas.dart';
import '../Modelos/producto.dart';
import '../Modelos/venta.dart';
import '../Tema/app_theme.dart';
import 'perfil.dart';
import 'venta.dart';
import 'scanner_vista.dart';

class PosVista extends StatefulWidget {
  final ControladorInicio controladorInicio;
  final ControladorInventario controladorInventario;
  final ControladorVentas controladorVentas;

  const PosVista({
    Key? key,
    required this.controladorInicio,
    required this.controladorInventario,
    required this.controladorVentas,
  }) : super(key: key);

  @override
  State<PosVista> createState() => _PosVistaState();
}

class _PosVistaState extends State<PosVista> {
  String _busqueda = '';
  String _categoriaSeleccionada = 'all';

  @override
  void initState() {
    super.initState();
    if (widget.controladorVentas.ventaActual == null) {
      widget.controladorVentas.iniciarVenta();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Producto> productosMostrados = widget.controladorInventario
        .buscarProductos(_busqueda);
    if (_categoriaSeleccionada != 'all') {
      productosMostrados = productosMostrados
          .where((p) => p.notas.toLowerCase().contains(_categoriaSeleccionada))
          .toList();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        resizeToAvoidBottomInset: false,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton:
            (widget.controladorVentas.ventaActual != null &&
                widget.controladorVentas.ventaActual!.articulos.isNotEmpty)
            ? Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                width: double.infinity,
                height: 56,
                child: FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.push(
                      context,
                      _slidePageRoute(
                        VentaVista(
                          controladorVentas: widget.controladorVentas,
                          controladorInventario: widget.controladorInventario,
                        ),
                      ),
                    ).then((_) => setState(() {}));
                  },
                  backgroundColor: AppColors.primary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${widget.controladorVentas.ventaActual!.articulos.fold(0, (sum, item) => sum + item.cantidad)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Ver Ticket y Cobrar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 32),
                      Text(
                        '\$${widget.controladorVentas.ventaActual!.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildSearchBar(),
                  _buildCategoryChips(),
                  _buildContextStrip(),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: productosMostrados.length,
                      itemBuilder: (context, index) {
                        return _buildProductCard(productosMostrados[index]);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.eco, color: AppColors.primary, size: 28),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Vivero',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Turno Mañana',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _busqueda = val),
                decoration: InputDecoration(
                  hintText: 'Buscar especie, SKU o nombre...',
                  hintStyle: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  suffixIcon: _busqueda.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.onSurfaceVariant,
                          ),
                          onPressed: () {
                            setState(() => _busqueda = '');
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.qr_code_scanner,
                color: AppColors.onPrimary,
              ),
              onPressed: () async {
                final resultado = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScannerVista()),
                );
                if (resultado != null && resultado is String) {
                  setState(() {
                    _busqueda = resultado;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final etiquetas =
        widget.controladorInicio.controladorPerfil.configuracion.etiquetas;
    final categorias = [
      {'id': 'all', 'label': 'Todos'},
    ];
    for (var etiqueta in etiquetas) {
      categorias.add({'id': etiqueta.toLowerCase(), 'label': etiqueta});
    }

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categorias.length,
        itemBuilder: (context, index) {
          final cat = categorias[index];
          final isSelected = _categoriaSeleccionada == cat['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 4, bottom: 4),
            child: GestureDetector(
              onTap: () => setState(() => _categoriaSeleccionada = cat['id']!),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  cat['label']!,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContextStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: const [
          Icon(Icons.eco, color: AppColors.surfaceTint, size: 16),
          SizedBox(width: 4),
          Text(
            'VARIEDADES DISPONIBLES',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  PageRouteBuilder _slidePageRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  Widget _buildProductCard(Producto producto) {
    int cantidadEnTicket = 0;
    if (widget.controladorVentas.ventaActual != null) {
      try {
        final art = widget.controladorVentas.ventaActual!.articulos.firstWhere(
          (a) => a.producto.id == producto.id,
        );
        cantidadEnTicket = art.cantidad;
      } catch (_) {}
    }
    bool enTicket = cantidadEnTicket > 0;

    return GestureDetector(
      onTap: () {
        setState(() {
          widget.controladorVentas.agregarProductoAVentaActual(producto.id, 1);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enTicket ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: producto.imagenes.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              producto.imagenes.first,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) =>
                                  const Icon(Icons.image, color: Colors.grey),
                            ),
                          )
                        : const Icon(
                            Icons.local_florist,
                            size: 40,
                            color: AppColors.surfaceTint,
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  producto.nombre,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.water_drop,
                      size: 12,
                      color: AppColors.surfaceTint,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      producto.notas.isNotEmpty ? producto.notas : 'Medio',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Precio unit.',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '\$${producto.precioVenta.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${producto.cantidadEnInventario} disp.',
                        style: const TextStyle(
                          color: AppColors.onPrimaryFixed,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (enTicket)
              Positioned(
                top: 4,
                right: 4,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(cantidadEnTicket),
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  final art = widget
                                      .controladorVentas
                                      .ventaActual!
                                      .articulos
                                      .firstWhere(
                                        (a) => a.producto.id == producto.id,
                                      );
                                  if (art.cantidad > 1) {
                                    art.cantidad--;
                                  } else {
                                    widget
                                        .controladorVentas
                                        .ventaActual!
                                        .articulos
                                        .remove(art);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                color: Colors.transparent,
                                child: const Icon(
                                  Icons.remove,
                                  color: AppColors.onPrimary,
                                  size: 18,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 14.0),
                              child: Text(
                                '$cantidadEnTicket',
                                style: const TextStyle(
                                  color: AppColors.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DrawerCarrito extends StatefulWidget {
  final Venta? ventaActual;
  final VoidCallback onActualizar;
  final VoidCallback onCompletar;

  const _DrawerCarrito({
    super.key,
    required this.ventaActual,
    required this.onActualizar,
    required this.onCompletar,
  });

  @override
  State<_DrawerCarrito> createState() => _DrawerCarritoState();
}

class _DrawerCarritoState extends State<_DrawerCarrito> {
  @override
  Widget build(BuildContext context) {
    if (widget.ventaActual == null) return const SizedBox();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Ticket de Venta',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Cliente mostrador • Caja 01',
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.expand_more),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.ventaActual!.articulos.length,
              itemBuilder: (context, index) {
                final art = widget.ventaActual!.articulos[index];
                return _buildCartRow(art, context);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surfaceContainer,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '\$${widget.ventaActual!.subtotalVenta.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'IVA (${(widget.ventaActual!.porcentajeIva * 100).toInt()}%)',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '\$${widget.ventaActual!.totalIva.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total a cobrar',
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '\$${widget.ventaActual!.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: widget.onCompletar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.onSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Procesar Cobro',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
  }

  Widget _buildCartRow(ArticuloVenta art, BuildContext context) {
    return Dismissible(
      key: Key(art.producto.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete, color: AppColors.onError),
      ),
      onDismissed: (direction) {
        setState(() {
          widget.ventaActual!.articulos.remove(art);
        });
        widget.onActualizar();
        if (widget.ventaActual!.articulos.isEmpty) Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.yard, color: AppColors.surfaceTint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    art.producto.nombre,
                    style: const TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '\$${art.precioUnitario.toStringAsFixed(2)} c/u',
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16),
                    onPressed: () {
                      setState(() {
                        if (art.cantidad > 1) {
                          art.cantidad--;
                        } else {
                          widget.ventaActual!.articulos.remove(art);
                          if (widget.ventaActual!.articulos.isEmpty)
                            Navigator.pop(context);
                        }
                      });
                      widget.onActualizar();
                    },
                  ),
                  Text(
                    '${art.cantidad}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () {
                      setState(() {
                        if (art.producto.cantidadEnInventario > art.cantidad) {
                          art.cantidad++;
                        }
                      });
                      widget.onActualizar();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 60,
              child: Text(
                '\$${art.subtotal.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
