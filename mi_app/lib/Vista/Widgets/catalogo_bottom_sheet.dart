import 'dart:io';
import 'package:flutter/material.dart';

import '../../Controladores/controlador_inventario.dart';
import '../../Modelos/producto.dart';
import '../../Modelos/venta.dart';
import '../../Tema/app_theme.dart';

class CatalogoBottomSheet extends StatefulWidget {
  final ControladorInventario controladorInventario;
  final Venta ventaActual;
  final ValueChanged<Producto> onProductoSeleccionado;

  const CatalogoBottomSheet({
    super.key,
    required this.controladorInventario,
    required this.ventaActual,
    required this.onProductoSeleccionado,
  });

  @override
  State<CatalogoBottomSheet> createState() => _CatalogoBottomSheetState();
}

class _CatalogoBottomSheetState extends State<CatalogoBottomSheet> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final List<Producto> filtrados =
        widget.controladorInventario.buscarProductos(_busqueda);
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      height: MediaQuery.of(context).size.height * (isLandscape ? 0.95 : 0.85),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.local_florist,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Catálogo de Productos',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
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
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isLandscape ? 4 : 2,
                childAspectRatio: isLandscape ? 0.78 : 0.72,
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

                final bool enTicket = cantidadEnTicket > 0;
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
                                      child: prod.imagenes.first.startsWith('http')
                                          ? Image.network(
                                              prod.imagenes.first,
                                              fit: BoxFit.cover,
                                              errorBuilder: (c, e, s) => Icon(
                                                Icons.local_florist,
                                                color: AppColors.primary,
                                                size: 36,
                                              ),
                                            )
                                          : Image.file(
                                              File(prod.imagenes.first),
                                              fit: BoxFit.cover,
                                              errorBuilder: (c, e, s) => Icon(
                                                Icons.local_florist,
                                                color: AppColors.primary,
                                                size: 36,
                                              ),
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
