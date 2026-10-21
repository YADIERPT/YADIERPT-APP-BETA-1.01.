import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Tema/app_theme.dart';
import '../Modelos/producto.dart';
import '../Modelos/venta.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_inventario.dart';
import '../Constantes/limites.dart';
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

  void _mostrarAviso(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.coral,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text(
          mensaje,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
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

  void _agregarAlCarrito(Producto producto) {
    if (producto.cantidadEnInventario == 0) {
      _mostrarAviso(context, 'Este producto no tiene unidades disponibles.');
      return;
    }
    try {
      widget.controladorVentas.agregarProductoAVentaActual(producto.id, 1);
      setState(() {});
      HapticFeedback.lightImpact();
    } catch (e) {
      _mostrarAviso(context, e.toString().replaceAll('Exception: ', ''));
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

    final double total = venta.total;
    final double recibido =
        double.tryParse(_montoRecibidoController.text) ?? 0.0;
    if (recibido < total) return;
    final double cambio = recibido - total;

    // Completamos la venta en el controlador (registra en efectivo)
    await widget.controladorVentas.completarVentaActual();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: AppColors.primary,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Venta Exitosa!',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'El ticket ha sido procesado con pago en efectivo.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Text(
              'Monto recibido: \$${recibido.toStringAsFixed(2)}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Cambio a devolver: \$${cambio.toStringAsFixed(2)}',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.controladorVentas.iniciarVenta();
                      _montoRecibidoController.clear();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Cerrar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ImpresionTicket.imprimirTicket(venta, recibido: recibido);
                    },
                    icon: const Icon(Icons.print, size: 16),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Imprimir',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        final venta = widget.controladorVentas.ventaActual!;
        final totalArticulos = venta.articulos.fold<int>(
          0,
          (sum, a) => sum + a.cantidad,
        );

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ticket en Curso',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Caja 1 · En curso',
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
            actions: const [],
          ),
          body: Column(
            children: [
              // Fila Artículos con contador de unidades y botón "Añadir ítem"
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Artículos',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondarySurface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$totalArticulos uds.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _abrirCatalogoBottomSheet,
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text(
                        'Añadir ítem',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          Expanded(
            child: venta.articulos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'El ticket está vacío',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Agrega productos desde el catálogo para comenzar.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _abrirCatalogoBottomSheet,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Abrir Catálogo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: venta.articulos.length,
                    itemBuilder: (context, index) {
                      final art = venta.articulos[index];
                      return _buildArticuloItem(art);
                    },
                  ),
          ),
          if (venta.articulos.isNotEmpty) _buildFooter(venta, totalArticulos),
        ],
      ),
    );
  },
);
  }

  Widget _buildArticuloItem(ArticuloVenta art) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          // Piso superior: Imagen, Nombre, Notas de cuidado y Precio
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.secondarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: art.producto.imagenes.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: art.producto.imagenes.first.startsWith('http')
                              ? Image.network(
                                  art.producto.imagenes.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Icon(
                                    Icons.local_florist,
                                    color: AppColors.primary,
                                    size: 26,
                                  ),
                                )
                              : Image.file(
                                  File(art.producto.imagenes.first),
                                  fit: BoxFit.cover,
                                ),
                        )
                      : Icon(
                          Icons.local_florist,
                          color: AppColors.primary,
                          size: 26,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        art.producto.nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        art.producto.notas.isNotEmpty
                            ? art.producto.notas
                            : 'Luz tamiz',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '\$${art.precioUnitario.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          // Piso inferior: Fila "Cantidad" con selector "−" / valor / "+"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cantidad',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (art.cantidad > 1) {
                              art.cantidad--;
                            } else {
                              widget.controladorVentas.ventaActual!.articulos
                                  .remove(art);
                            }
                          });
                        },
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Icon(
                            Icons.remove,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 26),
                        alignment: Alignment.center,
                        child: Text(
                          '${art.cantidad}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          if (art.producto.cantidadEnInventario > art.cantidad) {
                            setState(() {
                              art.cantidad++;
                            });
                          } else {
                            _mostrarAviso(
                              context,
                              'Solo hay ${art.producto.cantidadEnInventario} unidades disponibles.',
                            );
                          }
                        },
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Icon(
                            Icons.add,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Venta venta, int totalArticulos) {
    final double recibido =
        double.tryParse(_montoRecibidoController.text) ?? 0.0;
    final double cambio = recibido - venta.total;
    final bool montoSuficiente =
        _montoRecibidoController.text.isNotEmpty && recibido >= venta.total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '\$${venta.subtotalVenta.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (venta.aplicarIva) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'IVA (${(venta.porcentajeIva * 100).toInt()}%)',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '\$${venta.totalIva.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),

            // Campo "$ Monto recibido"
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.secondarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _montoRecibidoController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FormateadorMonetario(max: LimitesApp.maxMontoMonetario),
                ],
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      '\$',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  hintText: 'Monto recibido',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ),

            // Etapa 2: Franja "Cambio a entregar" solo cuando el monto alcanza o supera el total
            if (montoSuficiente) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFF161616),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.attach_money,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Cambio a entregar',
                          style: TextStyle(
                            color: Color(0xFF161616),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '\$${cambio.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF161616),
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Botón "Procesar Cobro de [total]" (habilitado solo cuando monto >= total)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (venta.articulos.isEmpty || !montoSuficiente)
                    ? null
                    : _procesarCobro,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.secondarySurface,
                  disabledForegroundColor: AppColors.textSecondary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Procesar Cobro de \$${venta.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
    List<Producto> filtrados =
        widget.controladorInventario.buscarProductos(_busqueda);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Catálogo de Productos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
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
                color: AppColors.secondarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _busqueda = val),
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar planta o maceta...',
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
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
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
                final bool sinUnidades = prod.cantidadEnInventario == 0;

                return GestureDetector(
                  onTap: () {
                    if (sinUnidades) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.coral,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                          content: const Text(
                            'Este producto no tiene unidades disponibles.',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
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
                      return;
                    }
                    widget.onProductoSeleccionado(prod);
                    setState(() {});
                  },
                  child: Opacity(
                    opacity: sinUnidades ? 0.65 : 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: enTicket ? AppColors.brightGreen : AppColors.border,
                          width: enTicket ? 2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.secondarySurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: prod.imagenes.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        prod.imagenes.first,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(
                                      Icons.local_florist,
                                      color: AppColors.primary,
                                      size: 36,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            prod.nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '\$${prod.precioVenta.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: AppColors.brightGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
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
                              else if (enTicket)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$cantidadEnTicket',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
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
