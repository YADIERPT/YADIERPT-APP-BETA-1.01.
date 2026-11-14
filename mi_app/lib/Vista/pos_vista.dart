import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../Controladores/controlador_inicio.dart';
import '../Controladores/controlador_inventario.dart';
import '../Controladores/controlador_ventas.dart';
import '../Modelos/producto.dart';
import '../Modelos/venta.dart';
import '../Tema/app_theme.dart';
import '../Servicios/motor_feedback.dart';
import '../Utilidades/debouncer.dart';
import '../Utilidades/formateador.dart';
import '../Constantes/limites.dart';
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
      MotorFeedback.feedbackError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un producto al ticket para cobrar.'),
        ),
      );
      return;
    }

    final TextEditingController montoRecibidoController =
        TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                final double total = venta?.total ?? 0.0;
                final String textoLimpio =
                    montoRecibidoController.text.replaceAll(',', '').trim();
                final double recibido = double.tryParse(textoLimpio) ?? 0.0;
                final double cambio =
                    recibido >= total ? recibido - total : 0.0;
                final bool montoSuficiente = recibido >= total && total > 0;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Asa de arrastre superior
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),

                    // Encabezado con Total a Cobrar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cobro en Caja',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${cVentas.totalArticulosEnCarrito} artículos en ticket',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            formatoMoneda(total),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 16),

                    // Campo de entrada: Monto recibido
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: TextField(
                        controller: montoRecibidoController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FormateadorMilesMonetario(
                              max: LimitesApp.maxMontoMonetario),
                        ],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        onChanged: (_) => setModalState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Monto recibido',
                          labelStyle:
                              TextStyle(color: AppColors.textSecondary),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '\$',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 0, minHeight: 0),
                          filled: true,
                          fillColor: AppColors.secondarySurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                      ),
                    ),

                    // Franja informativa de cambio
                    if (montoSuficiente) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Cambio a entregar:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSecondary,
                                ),
                              ),
                              Text(
                                formatoMoneda(cambio),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Botones de acción
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
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
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: BorderSide(color: AppColors.border),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Ver Detalle'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: montoSuficiente
                                  ? () async {
                                      Navigator.pop(ctx);
                                      await cVentas.completarVentaActual();
                                      MotorFeedback.vibracionFuerte();
                                      MotorFeedback.reproducirCash();
                                      if (mounted) setState(() {});
                                    }
                                  : null,
                              icon: const Icon(Icons.check_circle_outline,
                                  size: 20),
                              label: const Text(
                                'Confirmar Cobro',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.border,
                                disabledForegroundColor:
                                    AppColors.textSecondary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _mostrarAvisoSinUnidades() {
    MotorFeedback.feedbackError();
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

  void _intentarAgregarAlCarrito(Producto producto) {
    try {
      context.read<ControladorVentas>().agregarArticulo(producto, 1);
      MotorFeedback.vibracionMedia();
    } catch (e) {
      MotorFeedback.vibracionError();
      MotorFeedback.reproducirError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
            child: CustomScrollView(
              slivers: [
                // 1. Parte superior: Buscador y filtros de categoría
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchBar(isLandscape),
                      _buildCategoryChips(isLandscape),
                      _buildContextStrip(isLandscape),
                    ],
                  ),
                ),

                // 2. Parte superior/central: Catálogo de productos
                _buildCatalogoGrid(isLandscape: isLandscape),
              ],
            ),
          ),
          bottomNavigationBar: Selector<ControladorVentas, (int, double)>(
            selector: (_, cVentas) =>
                (cVentas.totalArticulosEnCarrito, cVentas.totalVentaActual),
            builder: (context, datosVenta, _) {
              final totalArticulos = datosVenta.$1;
              final totalVenta = datosVenta.$2;

              if (totalArticulos == 0) return const SizedBox.shrink();

              return SafeArea(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 65),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isLandscape ? 8 : 12,
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
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
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: isLandscape ? 44 : 48,
                        ),
                        child: ElevatedButton.icon(
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
                              horizontal: isLandscape ? 14 : 18,
                              vertical: isLandscape ? 10 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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

  /// Construye el Sliver del catálogo de productos para el flujo unificado del POS
  Widget _buildCatalogoGrid({required bool isLandscape}) {
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

        // Regla de ordenamiento jerárquico UX:
        // Prioridad 1 (Arriba): Productos con existencias disponibles (cantidad > 0)
        // Prioridad 2 (Abajo): Productos agotados (cantidad == 0)
        // Prioridad secundaria: Orden alfabético insensible a mayúsculas dentro de cada grupo
        ControladorInventario.ordenarProductosJerarquico(productos);

        if (productos.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: Text(
                  'No hay productos que coincidan con la búsqueda',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            isLandscape ? 4 : 8,
            16,
            100,
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
                        onAgregar: () => _intentarAgregarAlCarrito(producto),
                        onIncrementar: () => _intentarAgregarAlCarrito(producto),
                        onDecrementar: () {
                          context
                              .read<ControladorVentas>()
                              .decrementarArticulo(producto.id);
                          MotorFeedback.vibracionLigera();
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
