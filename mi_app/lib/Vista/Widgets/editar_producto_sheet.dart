import 'dart:io';
import 'package:flutter/material.dart';

import '../../Controladores/controlador_inventario.dart';
import '../../Modelos/producto.dart';
import '../../Tema/app_theme.dart';
import '../../Constantes/limites.dart';
import '../../Servicios/servicio_imagen.dart';

class EditarProductoSheet extends StatefulWidget {
  final Producto producto;
  final ControladorInventario controladorInventario;
  final VoidCallback onActualizado;

  const EditarProductoSheet({
    super.key,
    required this.producto,
    required this.controladorInventario,
    required this.onActualizado,
  });

  @override
  State<EditarProductoSheet> createState() => _EditarProductoSheetState();
}

class _EditarProductoSheetState extends State<EditarProductoSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombreCtrl;
  late TextEditingController _precioVentaCtrl;
  late TextEditingController _costoCtrl;
  late TextEditingController _notasCtrl;

  late String _tipo;
  String? _nuevaRutaImagen;
  bool _imagenEliminada = false;
  String? _errorNombre;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.producto.nombre);
    _precioVentaCtrl = TextEditingController(
      text: widget.producto.precioVenta.toStringAsFixed(2),
    );
    _costoCtrl = TextEditingController(
      text: widget.producto.costo.toStringAsFixed(2),
    );
    _notasCtrl = TextEditingController(text: widget.producto.notas);
    _tipo = widget.producto.tipo;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioVentaCtrl.dispose();
    _costoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _mostrarOpcionesImagen() async {
    final String? opcion = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primary),
                title: Text(
                  'Elegir de Galería',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.of(ctx).pop('gallery'),
              ),
              ListTile(
                leading: Icon(Icons.photo_camera, color: AppColors.primary),
                title: Text(
                  'Tomar Foto',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.of(ctx).pop('camera'),
              ),
              if (_tieneImagenActual)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.error),
                  title: Text(
                    'Eliminar Foto',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () => Navigator.of(ctx).pop('delete'),
                ),
            ],
          ),
        );
      },
    );

    if (opcion == null || !mounted) return;

    if (opcion == 'delete') {
      setState(() {
        _nuevaRutaImagen = null;
        _imagenEliminada = true;
      });
      return;
    }

    final path = opcion == 'camera'
        ? await ServicioImagen.instancia.tomarFoto(context: context)
        : await ServicioImagen.instancia.seleccionarDeGaleria(context: context);

    if (!mounted) return;
    if (path != null) {
      setState(() {
        _nuevaRutaImagen = path;
        _imagenEliminada = false;
      });
    }
  }

  bool get _tieneImagenActual {
    if (_imagenEliminada) return false;
    if (_nuevaRutaImagen != null && _nuevaRutaImagen!.isNotEmpty) return true;
    return widget.producto.imagenes.isNotEmpty;
  }

  Widget _buildImagenPreview() {
    if (_nuevaRutaImagen != null && _nuevaRutaImagen!.isNotEmpty) {
      return Image.file(
        File(_nuevaRutaImagen!),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (c, e, s) => _buildPlaceholder(),
      );
    }
    if (!_imagenEliminada && widget.producto.imagenes.isNotEmpty) {
      final img = widget.producto.imagenes.first;
      if (img.startsWith('http')) {
        return Image.network(
          img,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (c, e, s) => _buildPlaceholder(),
        );
      }
      return Image.file(
        File(img),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (c, e, s) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          _tipo == 'planta' ? Icons.spa_outlined : Icons.inventory_2_outlined,
          color: AppColors.primary,
          size: 36,
        ),
        const SizedBox(height: 6),
        Text(
          'Toca para cambiar foto',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _guardarCambios() async {
    final formValido = _formKey.currentState?.validate() ?? false;
    if (!formValido) return;

    final nombreTrim = _nombreCtrl.text.trim();
    if (nombreTrim.isEmpty) {
      setState(() => _errorNombre = 'El nombre no puede estar vacío');
      return;
    }

    final nombreDuplicado = widget.controladorInventario.productos.any(
      (p) =>
          p.id != widget.producto.id &&
          p.nombre.toLowerCase().trim() == nombreTrim.toLowerCase(),
    );
    if (nombreDuplicado) {
      setState(() => _errorNombre = 'Ya existe otro producto con este nombre');
      return;
    }

    final precioVenta = double.tryParse(_precioVentaCtrl.text) ?? 0.0;
    final costo = double.tryParse(_costoCtrl.text) ?? 0.0;

    List<String> imagenesFinales;
    if (_nuevaRutaImagen != null && _nuevaRutaImagen!.isNotEmpty) {
      imagenesFinales = [_nuevaRutaImagen!];
    } else if (_imagenEliminada) {
      imagenesFinales = [];
    } else {
      imagenesFinales = List<String>.from(widget.producto.imagenes);
    }

    final productoActualizado = Producto(
      id: widget.producto.id,
      nombre: nombreTrim,
      tipo: _tipo,
      precioVenta: precioVenta,
      costo: costo,
      cantidadEnInventario: widget.producto.cantidadEnInventario,
      umbralStockCritico: widget.producto.umbralStockCritico,
      imagenes: imagenesFinales,
      notas: _notasCtrl.text.trim(),
    );

    try {
      await widget.controladorInventario.actualizarProductoCompleto(
        productoActualizado,
      );
      widget.onActualizado();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, isLandscape ? 16 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Indicador de arrastre
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Encabezado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Editar Producto',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Previsualización y edición de imagen
                GestureDetector(
                  onTap: _mostrarOpcionesImagen,
                  child: Container(
                    height: isLandscape ? 100 : 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.secondarySurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildImagenPreview(),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Selector de Tipo de Producto (Planta o Artículo)
                Text(
                  'Tipo de producto',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _tipo = 'planta'),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _tipo == 'planta'
                                ? AppColors.subtleGreen
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _tipo == 'planta'
                                  ? AppColors.brightGreen
                                  : AppColors.border,
                              width: _tipo == 'planta' ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.spa_outlined,
                                color: _tipo == 'planta'
                                    ? AppColors.brightGreen
                                    : AppColors.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Planta',
                                style: TextStyle(
                                  color: _tipo == 'planta'
                                      ? AppColors.brightGreen
                                      : AppColors.textPrimary,
                                  fontWeight: _tipo == 'planta'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _tipo = 'articulo'),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _tipo == 'articulo'
                                ? AppColors.subtleTurquoise
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _tipo == 'articulo'
                                  ? AppColors.turquoise
                                  : AppColors.border,
                              width: _tipo == 'articulo' ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                color: _tipo == 'articulo'
                                    ? AppColors.turquoise
                                    : AppColors.textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Artículo',
                                style: TextStyle(
                                  color: _tipo == 'articulo'
                                      ? AppColors.turquoise
                                      : AppColors.textPrimary,
                                  fontWeight: _tipo == 'articulo'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Campo Nombre
                TextFormField(
                  controller: _nombreCtrl,
                  maxLength: LimitesApp.maxLongitudNombreProducto,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Nombre del producto',
                    labelStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    errorText: _errorNombre,
                  ),
                  onChanged: (val) {
                    if (_errorNombre != null) {
                      setState(() => _errorNombre = null);
                    }
                  },
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 8),

                // Costo y Precio de Venta
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _costoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FormateadorMonetario(
                            max: LimitesApp.maxMontoMonetario,
                          ),
                        ],
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Costo (\$)',
                          labelStyle: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          prefixText: '\$ ',
                          prefixStyle: TextStyle(color: AppColors.textPrimary),
                          filled: true,
                          fillColor: AppColors.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _precioVentaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FormateadorMonetario(
                            max: LimitesApp.maxMontoMonetario,
                          ),
                        ],
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Precio Venta (\$)',
                          labelStyle: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                          prefixText: '\$ ',
                          prefixStyle: TextStyle(color: AppColors.textPrimary),
                          filled: true,
                          fillColor: AppColors.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Descripción / Notas
                TextFormField(
                  controller: _notasCtrl,
                  maxLines: 2,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Descripción / Notas / Cuidados',
                    labelStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _guardarCambios,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Guardar Cambios',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
