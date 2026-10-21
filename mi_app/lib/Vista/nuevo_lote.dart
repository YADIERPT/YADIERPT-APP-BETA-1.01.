import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../Controladores/controlador_inventario.dart';
import '../Modelos/producto.dart';
import '../Tema/app_theme.dart';
import '../Constantes/limites.dart';

class NuevoLoteVista extends StatefulWidget {
  final ControladorInventario controladorInventario;

  const NuevoLoteVista({super.key, required this.controladorInventario});

  @override
  State<NuevoLoteVista> createState() => _NuevoLoteVistaState();
}

class _NuevoLoteVistaState extends State<NuevoLoteVista> {
  final _formKey = GlobalKey<FormState>();

  String nombre = '';
  double costo = 0.0;
  int cantidad = 0;
  String notas = '';
  String? rutaImagen;

  void _mostrarToast(String mensaje) {
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

  void _seleccionarImagen(ImageSource source) async {
    Navigator.of(context).pop();
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
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: AppColors.primary,
                ),
                title: Text(
                  'Elegir de Galería',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => _seleccionarImagen(ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_camera,
                  color: AppColors.primary,
                ),
                title: Text(
                  'Tomar Foto',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => _seleccionarImagen(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
  }

  void _guardarProducto() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        final nuevo = Producto(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nombre: nombre,
          precioVenta: costo,
          costo: costo,
          cantidadEnInventario: cantidad,
          imagenes: rutaImagen != null ? [rutaImagen!] : [],
          notas: notas,
        );
        await widget.controladorInventario.agregarProducto(nuevo);
        if (mounted) {
          Navigator.pop(context);
          _mostrarToast('Producto agregado exitosamente');
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
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            title: Text(
              'Agregar Nuevo Producto',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppColors.surface,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
            elevation: 0,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Foto
                    GestureDetector(
                      onTap: _mostrarOpcionesImagen,
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: AppColors.secondarySurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: rutaImagen != null && rutaImagen!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  File(rutaImagen!),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    color: AppColors.primary,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Toca para añadir una foto',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    // 2. Nombre de la planta / producto
                    TextFormField(
                      maxLength: LimitesApp.maxLongitudNombreProducto,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la planta / producto',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.card,
                      ),
                      style: TextStyle(color: AppColors.textPrimary),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      onSaved: (v) => nombre = v!,
                    ),
                    const SizedBox(height: 14),

                    // 3. Costo ($) - Único precio a ancho completo
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Costo (\$)',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.card,
                        prefixText: '\$ ',
                        prefixStyle: TextStyle(color: AppColors.textPrimary),
                      ),
                      style: TextStyle(color: AppColors.textPrimary),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [FormateadorMonetario(max: LimitesApp.maxMontoMonetario)],
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      onSaved: (v) => costo = double.tryParse(v!) ?? 0.0,
                    ),
                    const SizedBox(height: 14),

                    // 4. Cantidad inicial - Ancho completo
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Cantidad inicial',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.card,
                      ),
                      style: TextStyle(color: AppColors.textPrimary),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FormateadorEntero(max: LimitesApp.maxUnidades)],
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      onSaved: (v) => cantidad = int.tryParse(v!) ?? 0,
                    ),
                    const SizedBox(height: 14),

                    // 5. Notas / cuidados - Ancho completo
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Notas / cuidados',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.card,
                      ),
                      style: TextStyle(color: AppColors.textPrimary),
                      onSaved: (v) => notas = v ?? '',
                    ),
                    const SizedBox(height: 28),

                    // Botón de guardar: "Guardar Producto"
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _guardarProducto,
                        child: const Text(
                          'Guardar Producto',
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
      },
    );
  }
}
