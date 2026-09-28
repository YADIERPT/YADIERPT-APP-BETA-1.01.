import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../Controladores/controlador_inventario.dart';
import '../Modelos/producto.dart';
import '../Tema/app_theme.dart';

class NuevoLoteVista extends StatefulWidget {
  final ControladorInventario controladorInventario;

  const NuevoLoteVista({Key? key, required this.controladorInventario})
    : super(key: key);

  @override
  State<NuevoLoteVista> createState() => _NuevoLoteVistaState();
}

class _NuevoLoteVistaState extends State<NuevoLoteVista> {
  final _formKey = GlobalKey<FormState>();

  String nombre = '';
  double precio = 0.0;
  double costo = 0.0;
  int cantidad = 0;
  String notas = '';
  String? rutaImagen;

  void _mostrarToast(String mensaje) {
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

  void _seleccionarImagen(ImageSource source) async {
    Navigator.of(context).pop(); // Cerrar el modal de opciones
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (pickedFile != null) {
      setState(() {
        rutaImagen = pickedFile.path;
      });
    }
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.primary,
                ),
                title: const Text('Elegir de Galería'),
                onTap: () => _seleccionarImagen(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera,
                  color: AppColors.primary,
                ),
                title: const Text('Tomar Foto'),
                onTap: () => _seleccionarImagen(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
  }

  void _guardarLote() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        final nuevo = Producto(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nombre: nombre,
          precioVenta: precio,
          costo: costo,
          cantidadEnInventario: cantidad,
          imagenes: rutaImagen != null ? [rutaImagen!] : [],
          notas: notas,
        );
        await widget.controladorInventario.agregarProducto(nuevo);
        if (mounted) {
          Navigator.pop(context); // Volver a la pantalla anterior
          _mostrarToast('Lote agregado exitosamente');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'Agregar Nuevo Lote',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: _mostrarOpcionesImagen,
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.outlineVariant,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: rutaImagen != null && rutaImagen!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(rutaImagen!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              cacheHeight: 400,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                color: AppColors.primary,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Toca para añadir una foto',
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Nombre de la planta / lote',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  onSaved: (v) => nombre = v!,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Costo (\$)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceContainerLowest,
                          prefixText: '\$ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                        onSaved: (v) => costo = double.tryParse(v!) ?? 0.0,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Precio Venta (\$)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceContainerLowest,
                          prefixText: '\$ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                        onSaved: (v) => precio = double.tryParse(v!) ?? 0.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Cantidad Inicial',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceContainerLowest,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                        onSaved: (v) => cantidad = int.tryParse(v!) ?? 0,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Notas / Cuidados',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceContainerLowest,
                        ),
                        onSaved: (v) => notas = v ?? '',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _guardarLote,
                    child: const Text(
                      'Guardar Lote',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
