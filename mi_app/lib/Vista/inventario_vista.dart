import 'package:flutter/material.dart';
import 'dart:io';

import 'nuevo_lote.dart';
import '../Controladores/controlador_inventario.dart';
import '../Modelos/producto.dart';
import '../Tema/app_theme.dart';
import '../Constantes/limites.dart';

class InventarioVista extends StatefulWidget {
  final ControladorInventario controladorInventario;

  const InventarioVista({super.key, required this.controladorInventario});

  @override
  State<InventarioVista> createState() => _InventarioVistaState();
}

class _InventarioVistaState extends State<InventarioVista> {
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarInventario();
  }

  Future<void> _cargarInventario() async {
    await widget.controladorInventario.cargarProductos();
    if (mounted) {
      setState(() {});
    }
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

  void _mostrarDialogoEditarNombre(Producto prod) {
    final controller = TextEditingController(text: prod.nombre);
    String? errorTexto;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Editar nombre',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    maxLength: LimitesApp.maxLongitudNombreProducto,
                    autofocus: true,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nombre del producto',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.secondarySurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      errorText: errorTexto,
                      errorStyle: TextStyle(color: AppColors.coral),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (val) {
                      if (errorTexto != null) {
                        setDialogState(() => errorTexto = null);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final nuevoNombre = controller.text.trim();
                    if (nuevoNombre.isEmpty) {
                      setDialogState(() {
                        errorTexto = 'El nombre no puede estar vacío';
                      });
                      return;
                    }
                    if (nuevoNombre.length >
                        LimitesApp.maxLongitudNombreProducto) {
                      setDialogState(() {
                        errorTexto =
                            'Máximo ${LimitesApp.maxLongitudNombreProducto} caracteres';
                      });
                      return;
                    }

                    final yaExiste = widget.controladorInventario.productos.any(
                      (p) =>
                          p.id != prod.id &&
                          p.nombre.toLowerCase().trim() ==
                              nuevoNombre.toLowerCase(),
                    );
                    if (yaExiste) {
                      setDialogState(() {
                        errorTexto = 'Ya existe otro producto con este nombre';
                      });
                      return;
                    }

                    try {
                      await widget.controladorInventario
                          .actualizarNombreProducto(
                        prod.id,
                        nuevoNombre,
                      );
                      await _cargarInventario();
                      if (mounted) {
                        setState(() {});
                        Navigator.pop(ctx);
                        _mostrarToast('Nombre actualizado correctamente');
                      }
                    } catch (e) {
                      setDialogState(() {
                        errorTexto = 'Error: $e';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirAjuste(Producto producto) {
    int cantidad = producto.cantidadEnInventario;
    int umbral = producto.umbralStockCritico;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AJUSTE MANUAL',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              producto.nombre,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.secondarySurface,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Bloque 1: Cantidad de unidades en inventario
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.secondarySurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (cantidad > 0) setModalState(() => cantidad--);
                          },
                          icon: const Icon(Icons.remove, size: 26),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.card,
                            foregroundColor: AppColors.textPrimary,
                            minimumSize: const Size(48, 48),
                            shape: const CircleBorder(),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '$cantidad',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'unidades en inventario',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            if (cantidad < LimitesApp.maxUnidades) {
                              setModalState(() => cantidad++);
                            }
                          },
                          icon: const Icon(Icons.add, size: 26),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.card,
                            foregroundColor: AppColors.textPrimary,
                            minimumSize: const Size(48, 48),
                            shape: const CircleBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Bloque 2: Umbral de Stock Crítico
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondarySurface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.warning,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Umbral de Stock Crítico',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Alertar cuando queden existencias',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () {
                                  if (umbral > 0) {
                                    setModalState(() => umbral--);
                                  }
                                },
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
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
                                  '$umbral',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  if (umbral < LimitesApp.maxStockUmbral) {
                                    setModalState(() => umbral++);
                                  }
                                },
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
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
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        producto.cantidadEnInventario = cantidad;
                        producto.umbralStockCritico = umbral;

                        await widget.controladorInventario
                            .actualizarExistenciasYUmbral(
                          producto.id,
                          cantidad,
                          umbral,
                        );
                        await _cargarInventario();

                        if (mounted) Navigator.pop(context);
                        _mostrarToast('Existencias y umbral actualizados');
                      } catch (_) {
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text(
                      'Confirmar Existencias',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _abrirBorrarProducto(Producto producto) {
    showDialog(
      context: context,
      builder: (context) {
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
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await widget.controladorInventario.eliminarProducto(
                    producto.id,
                  );
                  await _cargarInventario();
                  if (mounted) Navigator.pop(context);
                  _mostrarToast('Producto eliminado exitosamente');
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
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        List<Producto> productos =
            widget.controladorInventario.buscarProductos(_busqueda);

        int totalPlantas = widget.controladorInventario.productos.fold(
          0,
          (sum, p) => sum + p.cantidadEnInventario,
        );
        int stockCritico = widget.controladorInventario.productos
            .where((p) => p.esStockCritico)
            .length;

        return Scaffold(
          backgroundColor: AppColors.surface,
          floatingActionButton: FloatingActionButton(
            tooltip: 'Añadir nuevo producto',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NuevoLoteVista(
                    controladorInventario: widget.controladorInventario,
                  ),
                ),
              ).then((_) => _cargarInventario());
            },
            backgroundColor: AppColors.secondary,
            foregroundColor: const Color(0xFF161616),
            elevation: 3,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, size: 28),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              children: [
                // 1. Buscador en la parte superior (sin botón de escáner y sin filtros rápidos anteriores)
                TextField(
              onChanged: (val) {
                setState(() {
                  _busqueda = val;
                });
              },
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar planta o lote...',
                hintStyle:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: AppColors.textSecondary, size: 18),
                        onPressed: () {
                          setState(() {
                            _busqueda = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.secondarySurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 2. Debajo del buscador, las 3 tarjetas de resumen: plantas vivas, stock crítico y lotes/SKUs
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.subtleGreen,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.spa_outlined,
                            color: AppColors.brightGreen,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$totalPlantas',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Plantas vivas',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.subtleAmber,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.amber,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$stockCritico',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Stock crítico',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.subtleTurquoise,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.turquoise,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.controladorInventario.productos.length}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Lotes / SKUs',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Módulo 9: Panel "Sugerencias IA" y chip con el mismo nombre (solo visual / placeholder)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Sugerencias IA',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Espacio de sugerencias',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recomendación del sistema: optimización de stock botánico disponible.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          minimumSize: const Size(60, 28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          'Descartar',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          minimumSize: const Size(60, 28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Ver sugerencia',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Lista de productos del inventario
            Text(
              'Plantas y Lotes en Catálogo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            if (productos.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Center(
                  child: Text(
                    'No se encontraron productos en el inventario.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              ...productos.map((prod) {
                final bool isCritical = prod.esStockCritico;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppColors.secondarySurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: prod.imagenes.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child:
                                        prod.imagenes.first.startsWith('http')
                                            ? Image.network(
                                                prod.imagenes.first,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, s) =>
                                                    Icon(
                                                  Icons.local_florist,
                                                  color: AppColors.primary,
                                                  size: 32,
                                                ),
                                              )
                                            : Image.file(
                                                File(prod.imagenes.first),
                                                fit: BoxFit.cover,
                                              ),
                                  )
                                : Icon(
                                    Icons.local_florist,
                                    color: AppColors.primary,
                                    size: 32,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              prod.nombre,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: () =>
                                                _mostrarDialogoEditarNombre(
                                                    prod),
                                            child: Padding(
                                              padding: const EdgeInsets.all(2.0),
                                              child: Icon(
                                                Icons.edit_outlined,
                                                size: 16,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                      ),
                                    ),
                                    // Cantidad disponible como texto simple (cantidad + unidad), sin recuadro de color
                                    Text(
                                      '${prod.cantidadEnInventario} u.',
                                      style: TextStyle(
                                        color: isCritical
                                            ? AppColors.warning
                                            : AppColors.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      isCritical
                                          ? Icons.warning_amber_rounded
                                          : Icons.check_circle_outline,
                                      size: 13,
                                      color: isCritical
                                          ? AppColors.warning
                                          : AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isCritical ? 'Stock Bajo' : 'Óptimo',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isCritical
                                            ? AppColors.warning
                                            : AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '\$${prod.precioVenta.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (prod.notas.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondarySurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            prod.notas,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => _abrirAjuste(prod),
                              icon: const Icon(Icons.add, size: 16),
                              // El botón "Ajustar" cambia su texto a "Añadir"
                              label: const Text('Añadir'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: ElevatedButton.icon(
                              onPressed: () => _abrirBorrarProducto(prod),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 16,
                              ),
                              label: const Text('Borrar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  },
);
  }
}
