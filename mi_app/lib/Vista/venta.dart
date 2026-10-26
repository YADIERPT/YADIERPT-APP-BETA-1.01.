import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Tema/app_theme.dart';
import '../Modelos/producto.dart';
import '../Modelos/venta.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_inventario.dart';
import 'Widgets/catalogo_bottom_sheet.dart';
import 'Widgets/articulo_ticket_item.dart';
import 'Widgets/venta_footer.dart';
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
      builder: (ctx) => CatalogoBottomSheet(
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

    // Completamos la venta en el controlador
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
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        content: SingleChildScrollView(
          child: Column(
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
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '¡Venta Exitosa!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'El ticket ha sido procesado con pago en efectivo.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 20),
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
      ),
    );
  }

  void _eliminarArticulo(Venta venta, ArticuloVenta art, int index) {
    final ArticuloVenta artEliminado = art;
    final int indiceEliminado = index;

    setState(() {
      venta.articulos.removeAt(index);
    });

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${artEliminado.producto.nombre} eliminado',
                style: const TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'DESHACER',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              if (indiceEliminado <= venta.articulos.length) {
                venta.articulos.insert(indiceEliminado, artEliminado);
              } else {
                venta.articulos.add(artEliminado);
              }
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        if (widget.controladorVentas.ventaActual == null) {
          widget.controladorVentas.iniciarVenta();
        }
        final venta = widget.controladorVentas.ventaActual!;

        // Sincronizar IVA con la configuración financiera del sistema:
        // Si el botón de IVA en Configuración Financiera está desactivado,
        // desaparece por completo del ticket y de los cálculos de cobro.
        final bool aplicarIvaConfig =
            widget.controladorVentas.controladorPerfil.configuracion.aplicarIva;
        venta.aplicarIva = aplicarIvaConfig;
        venta.porcentajeIva =
            widget.controladorVentas.controladorPerfil.configuracion.porcentajeIvaDefecto;

        final totalArticulos = venta.articulos.fold<int>(
          0,
          (sum, a) => sum + a.cantidad,
        );

        return OrientationBuilder(
          builder: (context, orientation) {
            final bool isLandscape = orientation == Orientation.landscape;

            return Scaffold(
              backgroundColor: AppColors.surface,
              appBar: AppBar(
                toolbarHeight: isLandscape ? 44 : 56,
                backgroundColor: AppColors.surface,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: AppColors.textPrimary,
                    size: isLandscape ? 20 : 24,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: isLandscape
                    ? Row(
                        children: [
                          Icon(Icons.receipt_long,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Ticket en Curso · Caja 1',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      )
                    : Row(
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
              ),
              body: isLandscape
                  ? _buildLandscapeLayout(venta, totalArticulos)
                  : _buildPortraitLayout(venta, totalArticulos),
            );
          },
        );
      },
    );
  }

  // Layout vertical (Portrait)
  Widget _buildPortraitLayout(Venta venta, int totalArticulos) {
    return Column(
      children: [
        _buildArticulosHeader(totalArticulos, isLandscape: false),
        Expanded(
          child: venta.articulos.isEmpty
              ? _buildEmptyState()
              : _buildArticulosList(venta, isLandscape: false),
        ),
        if (venta.articulos.isNotEmpty)
          VentaFooter(
            venta: venta,
            montoRecibidoController: _montoRecibidoController,
            onMontoCambiado: () => setState(() {}),
            onProcesarCobro: _procesarCobro,
            isLandscape: false,
          ),
      ],
    );
  }

  // Layout horizontal adaptativo (Landscape sin compresión)
  Widget _buildLandscapeLayout(Venta venta, int totalArticulos) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Columna izquierda: Lista de artículos compacta con swipe-to-delete
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _buildArticulosHeader(totalArticulos, isLandscape: true),
              Expanded(
                child: venta.articulos.isEmpty
                    ? _buildEmptyState()
                    : _buildArticulosList(venta, isLandscape: true),
              ),
            ],
          ),
        ),
        // Columna derecha: Checkout y resumen financiero adaptado
        Expanded(
          flex: 5,
          child: venta.articulos.isNotEmpty
              ? VentaFooter(
                  venta: venta,
                  montoRecibidoController: _montoRecibidoController,
                  onMontoCambiado: () => setState(() {}),
                  onProcesarCobro: _procesarCobro,
                  isLandscape: true,
                )
              : _buildLandscapeEmptyCheckout(),
        ),
      ],
    );
  }

  Widget _buildArticulosHeader(int totalArticulos, {required bool isLandscape}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, isLandscape ? 4 : 8, 16, isLandscape ? 4 : 8),
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
                    fontSize: isLandscape ? 14 : 15,
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
            icon: const Icon(Icons.add_shopping_cart, size: 15),
            label: Text(
              'Añadir ítem',
              style: TextStyle(
                fontSize: isLandscape ? 12 : 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 8 : 10,
                vertical: isLandscape ? 5 : 7,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticulosList(Venta venta, {required bool isLandscape}) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isLandscape ? 4 : 12,
      ),
      itemCount: venta.articulos.length,
      itemBuilder: (context, index) {
        final art = venta.articulos[index];

        return Dismissible(
          key: ValueKey('ticket_art_${art.producto.id}_$index'),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _eliminarArticulo(venta, art, index),
          background: Container(
            margin: EdgeInsets.only(bottom: isLandscape ? 8 : 12),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text(
                  'Eliminar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.delete_outline, color: Colors.white, size: 22),
              ],
            ),
          ),
          child: ArticuloTicketItem(
            art: art,
            isLandscape: isLandscape,
            onIncrementar: () {
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
            onDecrementar: () {
              setState(() {
                if (art.cantidad > 1) {
                  art.cantidad--;
                } else {
                  venta.articulos.remove(art);
                }
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 50,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              'El ticket está vacío',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Agrega productos desde el catálogo para comenzar.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _abrirCatalogoBottomSheet,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Abrir Catálogo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeEmptyCheckout() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(left: BorderSide(color: AppColors.border, width: 1)),
      ),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.point_of_sale_outlined,
                size: 32,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Terminal Lista',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Añade artículos al ticket para calcular montos y cobrar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
