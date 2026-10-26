import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../Controladores/controlador_inventario.dart';
import '../Modelos/producto.dart';
import '../Tema/app_theme.dart';
import '../Constantes/limites.dart';
import '../Servicios/servicio_imagen.dart';

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
  double precioVenta = 0.0;
  int cantidad = 0;
  String notas = '';
  String? rutaImagen;
  String? tipoSeleccionado;
  String? errorTipo;

  @override
  void initState() {
    super.initState();
    _recuperarImagenPerdida();
  }

  Future<void> _recuperarImagenPerdida() async {
    final path = await ServicioImagen.instancia.recuperarImagenPerdida();
    if (path != null && mounted) {
      setState(() {
        rutaImagen = path;
      });
    }
  }

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

  Future<void> _mostrarOpcionesImagen() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
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
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
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
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    final path = source == ImageSource.camera
        ? await ServicioImagen.instancia.tomarFoto(context: context)
        : await ServicioImagen.instancia.seleccionarDeGaleria(context: context);

    if (!mounted) return;
    if (path != null) {
      setState(() {
        rutaImagen = path;
      });
    }
  }

  void _guardarProducto() async {
    final formValido = _formKey.currentState!.validate();
    if (tipoSeleccionado == null) {
      setState(() {
        errorTipo = 'Debes especificar obligatoriamente si es Planta o Artículo';
      });
      return;
    }

    if (formValido) {
      _formKey.currentState!.save();
      try {
        final nuevo = Producto(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nombre: nombre,
          tipo: tipoSeleccionado!,
          precioVenta: precioVenta > 0 ? precioVenta : costo,
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
                                  errorBuilder: (c, e, s) => Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image_outlined,
                                        color: AppColors.primary,
                                        size: 40,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Error al cargar imagen',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
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

                    // Selector Obligatorio: Planta o Artículo
                    Text(
                      'Tipo de producto *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: errorTipo != null
                            ? AppColors.coral
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                tipoSeleccionado = 'planta';
                                errorTipo = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: tipoSeleccionado == 'planta'
                                    ? AppColors.subtleGreen
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tipoSeleccionado == 'planta'
                                      ? AppColors.brightGreen
                                      : (errorTipo != null
                                          ? AppColors.coral
                                          : AppColors.border),
                                  width:
                                      tipoSeleccionado == 'planta' ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.spa_outlined,
                                    color: tipoSeleccionado == 'planta'
                                        ? AppColors.brightGreen
                                        : AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Planta',
                                    style: TextStyle(
                                      color: tipoSeleccionado == 'planta'
                                          ? AppColors.brightGreen
                                          : AppColors.textPrimary,
                                      fontWeight: tipoSeleccionado == 'planta'
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                tipoSeleccionado = 'articulo';
                                errorTipo = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: tipoSeleccionado == 'articulo'
                                    ? AppColors.subtleTurquoise
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tipoSeleccionado == 'articulo'
                                      ? AppColors.turquoise
                                      : (errorTipo != null
                                          ? AppColors.coral
                                          : AppColors.border),
                                  width:
                                      tipoSeleccionado == 'articulo' ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    color: tipoSeleccionado == 'articulo'
                                        ? AppColors.turquoise
                                        : AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Artículo',
                                    style: TextStyle(
                                      color: tipoSeleccionado == 'articulo'
                                          ? AppColors.turquoise
                                          : AppColors.textPrimary,
                                      fontWeight: tipoSeleccionado == 'articulo'
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (errorTipo != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        errorTipo!,
                        style: TextStyle(
                          color: AppColors.coral,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

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

                    // 3. Costo ($) y Precio de Venta ($)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Costo (\$)',
                              labelStyle:
                                  TextStyle(color: AppColors.textSecondary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: AppColors.card,
                              prefixText: '\$ ',
                              prefixStyle:
                                  TextStyle(color: AppColors.textPrimary),
                            ),
                            style: TextStyle(color: AppColors.textPrimary),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FormateadorMonetario(
                                max: LimitesApp.maxMontoMonetario,
                              ),
                            ],
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Requerido' : null,
                            onSaved: (v) =>
                                costo = double.tryParse(v ?? '') ?? 0.0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Precio Venta (\$)',
                              labelStyle:
                                  TextStyle(color: AppColors.textSecondary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: AppColors.card,
                              prefixText: '\$ ',
                              prefixStyle:
                                  TextStyle(color: AppColors.textPrimary),
                            ),
                            style: TextStyle(color: AppColors.textPrimary),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FormateadorMonetario(
                                max: LimitesApp.maxMontoMonetario,
                              ),
                            ],
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Requerido' : null,
                            onSaved: (v) =>
                                precioVenta = double.tryParse(v ?? '') ?? 0.0,
                          ),
                        ),
                      ],
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
