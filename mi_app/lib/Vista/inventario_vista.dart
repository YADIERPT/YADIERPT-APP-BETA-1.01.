import 'package:flutter/material.dart';

import 'nuevo_lote.dart';

import 'package:flutter/services.dart';

import '../Controladores/controlador_inventario.dart';
import '../Modelos/producto.dart';
import '../Tema/app_theme.dart';
import '../BaseDatos/base_datos.dart';

import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'scanner_vista.dart';

class InventarioVista extends StatefulWidget {
  final ControladorInventario controladorInventario;

  const InventarioVista({super.key, required this.controladorInventario});

  @override
  State<InventarioVista> createState() => _InventarioVistaState();
}

class _InventarioVistaState extends State<InventarioVista> {
  String _busqueda = '';
  String _categoriaSeleccionada = 'all';

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
            const Icon(Icons.check_circle, color: AppColors.onPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(color: AppColors.onPrimary),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  void _abrirAjuste(Producto producto) {
    int cantidad = producto.cantidadEnInventario;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ajuste Manual',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              producto.nombre,
                              style: const TextStyle(
                                color: AppColors.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (cantidad > 0) setModalState(() => cantidad--);
                          },
                          icon: const Icon(Icons.remove, size: 28),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainerHigh,
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '$cantidad',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const Text(
                              'unidades',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            setModalState(() => cantidad++);
                          },
                          icon: const Icon(Icons.add, size: 28),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainerHigh,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      int diferencia = cantidad - producto.cantidadEnInventario;
                      try {
                        if (diferencia > 0) {
                          producto.agregarInventario(diferencia);
                        } else if (diferencia < 0) {
                          producto.reducirInventario(diferencia.abs());
                        }
                        final db = await BaseDeDatos.instancia.database;
                        await db.update(
                          'productos',
                          producto.toMap(),
                          where: 'id = ?',
                          whereArgs: [producto.id],
                        );
                        await _cargarInventario();

                        if (mounted) Navigator.pop(context);
                        _mostrarToast('Stock actualizado exitosamente');
                      } catch (e) {}
                    },
                    icon: const Icon(Icons.check),
                    label: const Text(
                      'Confirmar Existencias',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
          title: const Text('Borrar Producto'),
          content: Text(
            '¿Estás seguro de que deseas eliminar completamente el producto ${producto.nombre} de tu base de datos? Esto no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
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
              child: const Text(
                'Confirmar',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Producto> productos = widget.controladorInventario.buscarProductos(
      _busqueda,
    );
    if (_categoriaSeleccionada == 'critical') {
      productos = productos.where((p) => p.cantidadEnInventario <= 5).toList();
    }

    int totalPlantas = widget.controladorInventario.productos.fold(
      0,
      (sum, p) => sum + p.cantidadEnInventario,
    );
    int stockCritico = widget.controladorInventario.productos
        .where((p) => p.cantidadEnInventario <= 5)
        .length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton.extended(
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
        foregroundColor: AppColors.onSecondary,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nuevo Lote',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 2),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.spa,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$totalPlantas',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Text(
                                'Plantas vivas',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant,
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
                            color: Color(0xFFC85A32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 2),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber,
                                color: AppColors.secondary,
                                size: 20,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$stockCritico',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const Text(
                                'Stock crítico',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant,
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
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 2),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.inventory_2,
                                color: AppColors.tertiary,
                                size: 20,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${widget.controladorInventario.productos.length}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.tertiary,
                                ),
                              ),
                              const Text(
                                'Lotes / SKUs',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) {
                            setState(() {
                              _busqueda = val;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Buscar planta o maceta...',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppColors.onSurfaceVariant,
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceContainer,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 48,
                        width: 48,
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
                              MaterialPageRoute(
                                builder: (context) => const ScannerVista(),
                              ),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _FilterChip(
                        label:
                            'Todos (${widget.controladorInventario.productos.length})',
                        icon: Icons.apps,
                        isSelected: _categoriaSeleccionada == 'all',
                        onTap: () =>
                            setState(() => _categoriaSeleccionada = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Stock Crítico ($stockCritico)',
                        icon: Icons.warning_amber,
                        isSelected: _categoriaSeleccionada == 'critical',
                        onTap: () =>
                            setState(() => _categoriaSeleccionada = 'critical'),
                        iconColor: AppColors.secondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: productos.length,
                itemBuilder: (context, index) {
                  final prod = productos[index];
                  bool isCritical = prod.cantidadEnInventario <= 5;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
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
                                            )
                                          : Image.file(
                                              File(prod.imagenes.first),
                                              fit: BoxFit.cover,
                                            ),
                                    )
                                  : const Icon(
                                      Icons.local_florist,
                                      color: AppColors.surfaceTint,
                                      size: 36,
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
                                        child: Text(
                                          prod.nombre,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.onSurface,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFC8EBCE),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          '${prod.cantidadEnInventario} u.',
                                          style: const TextStyle(
                                            color: Color(0xFF02210F),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCritical
                                          ? AppColors.secondary.withOpacity(0.1)
                                          : AppColors.surfaceContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isCritical
                                              ? Icons.warning_amber
                                              : Icons.check_circle,
                                          size: 12,
                                          color: isCritical
                                              ? AppColors.secondary
                                              : AppColors.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isCritical ? 'Stock Bajo' : 'Óptimo',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isCritical
                                                ? AppColors.secondary
                                                : AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '\$${prod.precioVenta.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.eco,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  prod.notas.isNotEmpty
                                      ? prod.notas
                                      : 'Sin notas específicas',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () => _abrirAjuste(prod),
                                icon: const Icon(Icons.exposure, size: 18),
                                label: const Text('Ajustar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppColors.surfaceContainerHigh,
                                  foregroundColor: AppColors.onSurface,
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
                                  size: 18,
                                ),
                                label: const Text('Borrar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: AppColors.onError,
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? iconColor;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.surfaceContainerHighest
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? (iconColor ?? AppColors.primary)
                  : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AppColors.onSurface
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
