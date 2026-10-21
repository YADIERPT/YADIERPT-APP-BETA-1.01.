import 'package:flutter/material.dart';

import '../Controladores/controlador_inicio.dart';
import '../Controladores/controlador_inventario.dart';
import '../Controladores/controlador_ventas.dart';
import '../Modelos/producto.dart';
import '../Tema/app_theme.dart';
import 'venta.dart';

class PosVista extends StatefulWidget {
  final ControladorInicio controladorInicio;
  final ControladorInventario controladorInventario;
  final ControladorVentas controladorVentas;

  const PosVista({
    super.key,
    required this.controladorInicio,
    required this.controladorInventario,
    required this.controladorVentas,
  });

  @override
  State<PosVista> createState() => _PosVistaState();
}

class _PosVistaState extends State<PosVista> {
  String _categoriaSeleccionada = 'all';
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    if (widget.controladorVentas.ventaActual == null) {
      widget.controladorVentas.iniciarVenta();
    }
  }

  void _abrirCobroModal() {
    final venta = widget.controladorVentas.ventaActual;
    if (venta == null || venta.articulos.isEmpty) {
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
          controladorVentas: widget.controladorVentas,
          controladorInventario: widget.controladorInventario,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        final productos =
            widget.controladorInventario.buscarProductos(_busqueda).where((p) {
          if (_categoriaSeleccionada == 'all') return true;
          return p.notas.toLowerCase().contains(_categoriaSeleccionada);
        }).toList();

        final ventaActual = widget.controladorVentas.ventaActual;
        final totalArticulos = ventaActual != null
            ? ventaActual.articulos.fold<int>(0, (sum, a) => sum + a.cantidad)
            : 0;
        final totalVenta = ventaActual?.total ?? 0.0;

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Column(
              children: [
                _buildSearchBar(),
                _buildCategoryChips(),
                _buildContextStrip(),
                Expanded(
                  child: productos.isEmpty
                      ? Center(
                          child: Text(
                            'No hay plantas que coincidan con la búsqueda',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.70,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: productos.length,
                          itemBuilder: (context, index) {
                            return _buildProductCard(productos[index]);
                          },
                        ),
                ),
              ],
            ),
          ),
          bottomSheet: totalArticulos > 0
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '\$${totalVenta.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _abrirCobroModal,
                          icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                          label: const Text(
                            'Ver Ticket y Cobrar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.secondarySurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          onChanged: (val) => setState(() => _busqueda = val),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            suffixIcon: _busqueda.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 18,
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
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                      ? (AppColors.isDark ? const Color(0xFF161616) : Colors.white)
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

  Widget _buildContextStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.eco_outlined, color: AppColors.primary, size: 15),
          const SizedBox(width: 4),
          Text(
            'CATÁLOGO DE PLANTAS',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
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
    final bool sinUnidades = producto.cantidadEnInventario == 0;

    return GestureDetector(
      onTap: () {
        if (sinUnidades) {
          _mostrarAvisoSinUnidades();
          return;
        }
        setState(() {
          widget.controladorVentas.agregarProductoAVentaActual(producto.id, 1);
        });
      },
      child: Opacity(
        opacity: sinUnidades ? 0.65 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enTicket
                  ? AppColors.brightGreen
                  : (AppColors.isDark ? const Color(0xFF383838) : AppColors.border),
              width: enTicket ? 2 : 1,
            ),
          ),
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.secondarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: producto.imagenes.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              producto.imagenes.first,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Icon(
                                Icons.local_florist,
                                size: 36,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.local_florist,
                            size: 36,
                            color: AppColors.primary,
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  producto.nombre,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  producto.notas.isNotEmpty ? producto.notas : 'Planta natural',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '\$${producto.precioVenta.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppColors.brightGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (sinUnidades)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.subtleCoral,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Sin unidades',
                              style: TextStyle(
                                color: AppColors.coral,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        '${producto.cantidadEnInventario} u.',
                        style: TextStyle(
                          color: producto.esStockCritico
                              ? AppColors.amber
                              : (AppColors.isDark
                                  ? const Color(0xFFCCCCCC)
                                  : AppColors.textSecondary),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
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
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.remove,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '$cantidadEnTicket',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            widget.controladorVentas
                                .agregarProductoAVentaActual(producto.id, 1);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
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
}
