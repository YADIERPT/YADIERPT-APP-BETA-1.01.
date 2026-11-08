import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'nuevo_lote.dart';
import 'sugerencias_ia_vista.dart';
import 'Widgets/ajuste_stock_sheet.dart';
import 'Widgets/editar_producto_sheet.dart';
import 'Widgets/tarjeta_producto_inventario.dart';
import 'Widgets/resumen_inventario_header.dart';
import 'Widgets/role_guard.dart';
import '../Controladores/controlador_inventario.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_autenticacion.dart';
import '../IA/Controladores/controlador_ia_compras.dart';
import '../Modelos/producto.dart';
import '../Tema/app_theme.dart';

class InventarioVista extends StatefulWidget {
  const InventarioVista({super.key});

  @override
  State<InventarioVista> createState() => _InventarioVistaState();
}

class _InventarioVistaState extends State<InventarioVista> {
  String _busqueda = '';
  String _filtroActivo = 'todos'; // 'todos', 'plantas', 'articulos', 'critico'
  final TextEditingController _busquedaController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _cargarInventario();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _busquedaController.dispose();
    super.dispose();
  }

  /// Efecto Debounce de 300 ms: cancela temporizadores previos y solo filtra
  /// el catálogo cuando el usuario detiene la escritura durante 300 ms.
  void _onBusquedaChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _busqueda = val.trim();
        });
      }
    });
  }

  void _limpiarBusqueda() {
    _debounceTimer?.cancel();
    _busquedaController.clear();
    setState(() {
      _busqueda = '';
    });
  }

  Future<void> _cargarInventario() async {
    await context.read<ControladorInventario>().cargarProductos();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleRefresh() async {
    await context.read<ControladorInventario>().cargarProductos();
    final cIA = context.read<ControladorIACompras>();
    final cVentas = context.read<ControladorVentas>();
    await cIA.inicializar(cVentas.ventas);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {});
    }
  }

  void _cambiarFiltro(String filtro) {
    setState(() {
      if (_filtroActivo == filtro) {
        _filtroActivo = 'todos';
      } else {
        _filtroActivo = filtro;
      }
    });
  }

  void _mostrarToast(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _abrirEditarProducto(Producto producto) {
    final rolActual = context.read<ControladorAutenticacion>().usuarioActual?.rol;
    if (rolActual != null && !rolActual.puedeModificarInventario) {
      _mostrarToast('Acceso restringido: no tienes permisos de edición');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => EditarProductoSheet(
        producto: producto,
        controladorInventario: context.read<ControladorInventario>(),
        onActualizado: () {
          _cargarInventario();
          _mostrarToast('Producto actualizado correctamente');
        },
      ),
    );
  }

  void _abrirAjuste(Producto producto) {
    final rolActual = context.read<ControladorAutenticacion>().usuarioActual?.rol;
    if (rolActual != null && !rolActual.puedeModificarInventario) {
      _mostrarToast('Acceso restringido: no puedes realizar ajustes de existencias');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => AjusteStockSheet(
        producto: producto,
        controladorInventario: context.read<ControladorInventario>(),
        onActualizado: () {
          _cargarInventario();
          _mostrarToast('Existencias y umbral actualizados');
        },
      ),
    );
  }

  void _abrirSugerenciasIA() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => SugerenciasIAVista(
          controladorIA: context.read<ControladorIACompras>(),
          controladorInventario: context.read<ControladorInventario>(),
          controladorVentas: context.read<ControladorVentas>(),
        ),
      ),
    ).then((_) {
      _cargarInventario();
    });
  }

  void _abrirBorrarProducto(Producto producto) {
    final rolActual = context.read<ControladorAutenticacion>().usuarioActual?.rol;
    if (rolActual != null && !rolActual.puedeModificarInventario) {
      _mostrarToast('Acceso restringido: no tienes permisos para dar de baja productos');
      return;
    }
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Borrar Producto',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '¿Estás seguro de que deseas eliminar completamente el producto ${producto.nombre} de tu inventario? Esta acción no se puede deshacer.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await context.read<ControladorInventario>().eliminarProducto(
                    producto.id,
                  );
                  await _cargarInventario();
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (mounted) _mostrarToast('Producto eliminado exitosamente');
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Borrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final cInventario = context.watch<ControladorInventario>();
    final cAuth = context.watch<ControladorAutenticacion>();
    final cIA = context.watch<ControladorIACompras>();

    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        List<Producto> productos =
            cInventario.buscarProductos(_busqueda);

        int totalPlantas = 0;
        int stockCritico = 0;
        int totalArticulos = 0;
        for (final p in cInventario.productos) {
          if (p.esPlanta) totalPlantas++;
          if (p.esArticulo) totalArticulos++;
          if (p.esStockCritico) stockCritico++;
        }

        // Aplicar filtro de los 3 botones superiores
        if (_filtroActivo == 'critico') {
          productos = productos.where((p) => p.esStockCritico).toList();
        } else if (_filtroActivo == 'plantas') {
          productos = productos.where((p) => p.esPlanta).toList();
        } else if (_filtroActivo == 'articulos') {
          productos = productos.where((p) => p.esArticulo).toList();
        }

        String tituloLista =
            'Catálogo · Todos los Productos (${productos.length})';
        if (_filtroActivo == 'critico') {
          tituloLista = 'Catálogo · Stock Crítico ($stockCritico)';
        } else if (_filtroActivo == 'plantas') {
          tituloLista = 'Catálogo · Plantas ($totalPlantas)';
        } else if (_filtroActivo == 'articulos') {
          tituloLista = 'Catálogo · Artículos ($totalArticulos)';
        }

        final rolActual = cAuth.usuarioActual?.rol;
        final bool puedeModificar =
            rolActual?.puedeModificarInventario ?? true;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: AppColors.surface,
          floatingActionButton: null,
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.card,
              strokeWidth: 2.5,
              displacement: 40.0,
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, isLandscape ? 8 : 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Buscador con Debounce de 300 ms
                        TextField(
                          controller: _busquedaController,
                          onChanged: _onBusquedaChanged,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Buscar planta o artículo...',
                            hintStyle:
                                TextStyle(color: AppColors.textSecondary, fontSize: 14),
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            suffixIcon: _busqueda.isNotEmpty || _busquedaController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear,
                                        color: AppColors.textSecondary, size: 18),
                                    onPressed: _limpiarBusqueda,
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.secondarySurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: isLandscape ? 8 : 12,
                              horizontal: 14,
                            ),
                          ),
                        ),
                        SizedBox(height: isLandscape ? 8 : 12),

                        // 2. Resumen Inventario & Filtros (Plantas, Stock Crítico, Artículos)
                        ResumenInventarioHeader(
                          totalPlantas: totalPlantas,
                          stockCritico: stockCritico,
                          totalSkus: totalArticulos,
                          filtroActivo: _filtroActivo,
                          onFiltroSeleccionado: _cambiarFiltro,
                          controladorIA: cIA,
                          onVerSugerencias: _abrirSugerenciasIA,
                        ),
                        SizedBox(height: isLandscape ? 10 : 16),

                        // 3. Encabezado de la lista con indicador de filtro
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tituloLista,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (_filtroActivo != 'todos')
                              GestureDetector(
                                onTap: () => _cambiarFiltro('todos'),
                                child: Text(
                                  'Ver todos',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // 4. Lista virtualizada con carga diferida (cero lag con teclado)
                if (productos.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Center(
                          child: Text(
                            'No se encontraron productos para el filtro seleccionado.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (isLandscape)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: productos.length,
                      itemBuilder: (context, index) {
                        final prod = productos[index];
                        return TarjetaProductoInventario(
                          prod: prod,
                          rolActual: rolActual,
                          puedeModificar: puedeModificar,
                          onEditar: () => _abrirEditarProducto(prod),
                          onAjustar: () => _abrirAjuste(prod),
                          onBorrar: () => _abrirBorrarProducto(prod),
                        );
                      },
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                    sliver: SliverList.builder(
                      itemCount: productos.length,
                      itemBuilder: (context, index) {
                        final prod = productos[index];
                        return TarjetaProductoInventario(
                          prod: prod,
                          rolActual: rolActual,
                          puedeModificar: puedeModificar,
                          onEditar: () => _abrirEditarProducto(prod),
                          onAjustar: () => _abrirAjuste(prod),
                          onBorrar: () => _abrirBorrarProducto(prod),
                        );
                      },
                    ),
                  ),
              ],
                ),
              ),
            ),
          );
      },
    );
  }
}
