import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Tema/app_theme.dart';
import '../Modelos/producto.dart';
import '../Modelos/venta.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_inventario.dart';
import 'impresion_ticket.dart';

class VentaVista extends StatefulWidget {
  final ControladorVentas controladorVentas;
  final ControladorInventario controladorInventario;
  final Producto? productoInicial;

  const VentaVista({
    super.key,
    required this.controladorVentas,
    required this.controladorInventario,
    this.productoInicial,
  });

  @override
  State<VentaVista> createState() => _VentaVistaState();
}

class _VentaVistaState extends State<VentaVista> {
  String _metodoPago = 'efectivo';
  final TextEditingController _montoRecibidoController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.controladorVentas.ventaActual == null) {
      widget.controladorVentas.iniciarVenta();
    }

    if (widget.productoInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _agregarAlCarrito(widget.productoInicial!);
      });
    }
  }

  @override
  void dispose() {
    _montoRecibidoController.dispose();
    super.dispose();
  }

  void _agregarAlCarrito(Producto producto) {
    try {
      widget.controladorVentas.agregarProductoAVentaActual(producto.id, 1);
      setState(() {});
      HapticFeedback.lightImpact();
    } catch (e) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Aviso', style: TextStyle(color: AppColors.error)),
            ],
          ),
          content: Text(
            e.toString().replaceAll('Exception: ', ''),
            style: const TextStyle(color: AppColors.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Aceptar',
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

  void _abrirCatalogoBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CatalogoBottomSheet(
        controladorInventario: widget.controladorInventario,
        ventaActual: widget.controladorVentas.ventaActual!,
        onProductoSeleccionado: (p) => _agregarAlCarrito(p),
      ),
    );
  }

  Future<void> _procesarCobro() async {
    final venta = widget.controladorVentas.ventaActual;
    if (venta == null || venta.articulos.isEmpty) return;

    double total = venta.total;
    double recibido = 0.0;

    if (_metodoPago == 'efectivo') {
      recibido = double.tryParse(_montoRecibidoController.text) ?? 0.0;
      if (recibido < total) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: const [
                Icon(Icons.warning_rounded, color: AppColors.error),
                SizedBox(width: 8),
                Text(
                  'Monto Insuficiente',
                  style: TextStyle(color: AppColors.error),
                ),
              ],
            ),
            content: const Text(
              'El monto recibido es menor al total a cobrar.',
              style: TextStyle(color: AppColors.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Corregir',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
        return;
      }
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppColors.primary),
            SizedBox(width: 8),
            Text('¡Venta Exitosa!', style: TextStyle(color: AppColors.primary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('El ticket ha sido procesado con pago en $_metodoPago.'),
            if (_metodoPago == 'efectivo') ...[
              const SizedBox(height: 12),
              Text('Monto recibido: \$${recibido.toStringAsFixed(2)}'),
              Text(
                'Cambio a devolver: \$${(recibido - total).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Cerrar',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              ImpresionTicket.imprimirTicket(venta, recibido: recibido);
            },
            icon: const Icon(Icons.print, color: AppColors.onPrimary),
            label: const Text(
              'Imprimir',
              style: TextStyle(color: AppColors.onPrimary),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );

    await widget.controladorVentas.completarVentaActual();
    widget.controladorVentas.iniciarVenta();

    if (mounted) {
      _montoRecibidoController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final venta = widget.controladorVentas.ventaActual!;
    final totalArticulos = venta.articulos.fold<int>(
      0,
      (sum, a) => sum + a.cantidad,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface.withOpacity(0.9),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.onSurfaceVariant,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.receipt_long,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Ticket en Curso',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Turno Mañana • Caja 01',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Artículos',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$totalArticulos uds.',
                            style: const TextStyle(
                              color: AppColors.onPrimaryContainer,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _abrirCatalogoBottomSheet,
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Añadir ítem'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: venta.articulos.length,
                  itemBuilder: (context, index) {
                    final art = venta.articulos[index];
                    return _buildCartRow(art, context);
                  },
                ),
              ),
              _buildFooterCard(venta),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartRow(ArticuloVenta art, BuildContext context) {
    return Dismissible(
      key: Key(art.producto.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete, color: AppColors.onError),
      ),
      onDismissed: (direction) {
        setState(
          () => widget.controladorVentas.ventaActual!.articulos.remove(art),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: art.producto.imagenes.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              art.producto.imagenes.first,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.local_florist,
                            color: AppColors.surfaceTint,
                            size: 32,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                art.producto.nombre,
                                style: const TextStyle(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '\$${art.precioUnitario.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          art.producto.notas,
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cantidad',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: () {
                            setState(() {
                              if (art.cantidad > 1) {
                                art.cantidad--;
                              } else {
                                widget.controladorVentas.ventaActual!.articulos
                                    .remove(art);
                              }
                            });
                          },
                        ),
                        Text(
                          '${art.cantidad}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: () {
                            setState(() {
                              if (art.producto.cantidadEnInventario >
                                  art.cantidad) {
                                art.cantidad++;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterCard(Venta venta) {
    double recibido = double.tryParse(_montoRecibidoController.text) ?? 0.0;
    double cambio = recibido - venta.total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
              Text(
                '\$${venta.subtotalVenta.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          if (venta.aplicarIva)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'IVA (${(venta.porcentajeIva * 100).toInt()}%)',
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  Text(
                    '\$${venta.totalIva.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.attach_money,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _montoRecibidoController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Monto recibido',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_montoRecibidoController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: cambio >= 0
                      ? AppColors.secondaryContainer
                      : AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          cambio >= 0
                              ? Icons.monetization_on
                              : Icons.warning_rounded,
                          color: cambio >= 0
                              ? AppColors.onSecondaryContainer
                              : AppColors.onError,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cambio >= 0
                              ? 'Cambio a entregar'
                              : 'Monto insuficiente',
                          style: TextStyle(
                            color: cambio >= 0
                                ? AppColors.onSecondaryContainer
                                : AppColors.onError,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    if (cambio >= 0)
                      Text(
                        '\$${cambio.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.onSecondaryContainer,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed:
                  (venta.articulos.isEmpty ||
                      _montoRecibidoController.text.isEmpty ||
                      cambio < 0)
                  ? null
                  : _procesarCobro,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                disabledBackgroundColor: AppColors.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Procesar Cobro de \$${venta.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogoBottomSheet extends StatefulWidget {
  final ControladorInventario controladorInventario;
  final Venta ventaActual;
  final Function(Producto) onProductoSeleccionado;

  const _CatalogoBottomSheet({
    required this.controladorInventario,
    required this.ventaActual,
    required this.onProductoSeleccionado,
  });

  @override
  State<_CatalogoBottomSheet> createState() => _CatalogoBottomSheetState();
}

class _CatalogoBottomSheetState extends State<_CatalogoBottomSheet> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    List<Producto> filtrados = widget.controladorInventario.buscarProductos(
      _busqueda,
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Catálogo de Productos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _busqueda = val),
                decoration: InputDecoration(
                  hintText: 'Buscar planta o maceta...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: filtrados.length,
              itemBuilder: (context, index) {
                final prod = filtrados[index];
                int cantidadEnTicket = 0;
                try {
                  final art = widget.ventaActual.articulos.firstWhere(
                    (a) => a.producto.id == prod.id,
                  );
                  cantidadEnTicket = art.cantidad;
                } catch (_) {}

                bool enTicket = cantidadEnTicket > 0;

                return GestureDetector(
                  onTap: () {
                    widget.onProductoSeleccionado(prod);
                    setState(() {});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: enTicket
                            ? AppColors.primary
                            : Colors.transparent,
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
                                child: prod.imagenes.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          prod.imagenes.first,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.local_florist,
                                        color: AppColors.surfaceTint,
                                        size: 40,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              prod.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                            ),
                            Text(
                              '\$${prod.precioVenta.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.onSurfaceVariant,
                              ),
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
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$cantidadEnTicket',
                                      style: const TextStyle(
                                        color: AppColors.onPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
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
              },
            ),
          ),
        ],
      ),
    );
  }
}
