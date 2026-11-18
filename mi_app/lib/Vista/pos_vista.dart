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
import 'Widgets/miniatura_producto_widget.dart';
import 'venta.dart';
import 'impresion_ticket.dart';
import '../Servicios/servicio_ticket_pdf.dart';

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

  Widget _buildMiniImagenProducto(Producto prod) {
    return MiniaturaProductoWidget(
      producto: prod,
      width: 44,
      height: 44,
      borderRadius: BorderRadius.circular(10),
    );
  }

  Future<bool?> _mostrarDialogoPreguntaImpresion({
    required BuildContext context,
    required String titulo,
    required String mensaje,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          title: Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            mensaje,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(
                'No',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogCtx, true),
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Sí, imprimir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirCobroModal() {
    final cVentas = context.read<ControladorVentas>();
    final venta = cVentas.ventaActual;
    final articulos = venta?.articulos ?? [];

    if (cVentas.totalArticulosEnCarrito == 0 || articulos.isEmpty) {
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
      isScrollControlled: true, // Regla 3: Scroll controlado
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        // Regla 3: Margen dinámico exacto de teclado
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            // Regla 3: No sobrepasar el 85% de la pantalla para proteger la barra de estado
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(modalContext).size.height * 0.85,
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

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Asa de arrastre superior
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 6),
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

                        // 1. Encabezado: "Artículos (X uds.)" a la izquierda y botón verde "Añadir ítem" a la derecha
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 16, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Artículos (${cVentas.totalArticulosEnCarrito} uds.)',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.pop(modalContext),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text(
                                  'Añadir ítem',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // 1. Lista de productos del ticket interactiva
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: articulos.length,
                            itemBuilder: (context, i) {
                              final art = articulos[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.border, width: 1),
                                ),
                                child: Row(
                                  children: [
                                    // Imagen
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.secondarySurface,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: _buildMiniImagenProducto(
                                          art.producto),
                                    ),
                                    const SizedBox(width: 12),

                                    // Nombre y Precio unitario
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            art.producto.nombre,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${formatoMoneda(art.precioUnitario)} c/u',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Botones interactivos [ - ] [ cant ] [ + ]
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.secondarySurface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: AppColors.border, width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              cVentas.decrementarArticulo(
                                                  art.producto.id);
                                              MotorFeedback.vibracionLigera();
                                              setModalState(() {});
                                              if (cVentas.totalArticulosEnCarrito ==
                                                  0) {
                                                Navigator.pop(modalContext);
                                              }
                                            },
                                            borderRadius:
                                                const BorderRadius.horizontal(
                                              left: Radius.circular(8),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 5),
                                              child: Icon(Icons.remove,
                                                  size: 14,
                                                  color: AppColors.textPrimary),
                                            ),
                                          ),
                                          Container(
                                            constraints: const BoxConstraints(
                                                minWidth: 26),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '${art.cantidad}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              try {
                                                cVentas.agregarArticulo(
                                                    art.producto, 1);
                                                MotorFeedback.vibracionMedia();
                                                setModalState(() {});
                                              } catch (e) {
                                                MotorFeedback.vibracionError();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(e
                                                        .toString()
                                                        .replaceAll(
                                                            'Exception: ',
                                                            '')),
                                                    backgroundColor:
                                                        AppColors.error,
                                                    duration: const Duration(
                                                        seconds: 2),
                                                  ),
                                                );
                                              }
                                            },
                                            borderRadius:
                                                const BorderRadius.horizontal(
                                              right: Radius.circular(8),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 5),
                                              child: Icon(Icons.add,
                                                  size: 14,
                                                  color: AppColors.textPrimary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),

                                    // Subtotal
                                    Text(
                                      formatoMoneda(art.subtotal),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        const SizedBox(height: 8),

                        // 2. Desglose de Totales: Subtotal, IVA y Total neto con formatoMoneda
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 2),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    venta?.aplicarIva == true
                                        ? 'Subtotal'
                                        : 'Total a Cobrar',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    formatoMoneda(
                                        venta?.subtotalVenta ?? total),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              if (venta != null && venta.aplicarIva) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'IVA (${(venta.porcentajeIva * 100).toInt()}%)',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      formatoMoneda(venta.totalIva),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total neto',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    formatoMoneda(total),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // 2. Campo de entrada: "Monto recibido"
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: TextField(
                            controller: montoRecibidoController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FormateadorMilesMonetario(
                                  max: LimitesApp.maxMontoMonetario),
                            ],
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              labelText: 'Monto recibido',
                              labelStyle: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                              prefixIcon: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '\$',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                  minWidth: 0, minHeight: 0),
                              filled: true,
                              fillColor: AppColors.secondarySurface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: AppColors.primary, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),

                        // Franja informativa de Cambio a entregar
                        if (montoSuficiente) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Cambio a entregar:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSecondary,
                                    ),
                                  ),
                                  Text(
                                    formatoMoneda(cambio),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // 2. Botones: Principal ("Cobrar $Total") y Secundario ("Apartar / Cuenta por Cobrar")
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Botón Principal: Cobrar $Total
                              SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: montoSuficiente
                                      ? () async {
                                          final ventaACobrar =
                                              cVentas.ventaActual;
                                          if (ventaACobrar == null) return;

                                          // 1. Cerrar BottomSheet de cobro
                                          Navigator.pop(modalContext);

                                          // 2. Registrar en base de datos SQLite
                                          try {
                                            await cVentas.completarVentaActual();
                                            MotorFeedback.vibracionFuerte();
                                            MotorFeedback.reproducirCash();
                                          } catch (e) {
                                            MotorFeedback.vibracionError();
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Error al procesar la venta: $e'),
                                                  backgroundColor:
                                                      AppColors.error,
                                                ),
                                              );
                                            }
                                            return;
                                          }

                                          if (!mounted) return;

                                          // 3. Diálogo de confirmación de impresión idéntico al de abonos
                                          final bool? deseaImprimir =
                                              await _mostrarDialogoPreguntaImpresion(
                                            context: context,
                                            titulo: 'Venta Registrada',
                                            mensaje:
                                                'El registro se guardó correctamente. ¿Desea imprimir el ticket de comprobante para el cliente?',
                                          );

                                          // 4. Si el usuario confirma, llamar a la función de impresión
                                          if (deseaImprimir == true && mounted) {
                                            try {
                                              await ImpresionTicket
                                                  .imprimirTicket(
                                                ventaACobrar,
                                                recibido: recibido,
                                              );
                                            } catch (e) {
                                              debugPrint(
                                                  'Aviso al imprimir ticket de venta: $e');
                                            }
                                          }

                                          // 5. Iniciar nueva venta limpia en el carrito
                                          if (mounted) {
                                            cVentas.iniciarVenta();
                                            setState(() {});
                                          }
                                        }
                                      : null,
                                  icon: const Icon(Icons.check_circle_outline,
                                      size: 20),
                                  label: Text(
                                    'Cobrar ${formatoMoneda(total)}',
                                    style: const TextStyle(
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
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Botón Secundario: Apartar / Cuenta por Cobrar
                              SizedBox(
                                height: 44,
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    // 1. Diálogo para capturar nombre de cliente y anticipo
                                    final resultado = await showDialog<
                                        Map<String, dynamic>>(
                                      context: context,
                                      builder: (ctx) =>
                                          const DialogoApartadoVenta(),
                                    );
                                    if (resultado != null) {
                                      final nombre =
                                          resultado['cliente'] as String;
                                      final anticipo =
                                          resultado['anticipo'] as double;

                                      // 2. Registrar apartado en SQLite
                                      final ventaApartada = await cVentas
                                          .apartarVentaActual(
                                        cliente: nombre,
                                        montoAbonoInicial: anticipo,
                                      );

                                      if (ventaApartada != null && mounted) {
                                        // 3. Cerrar el BottomSheet de cobro
                                        Navigator.pop(modalContext);
                                        MotorFeedback.vibracionMedia();

                                        // 4. Diálogo de confirmación de impresión idéntico al de abonos
                                        final bool? deseaImprimir =
                                            await _mostrarDialogoPreguntaImpresion(
                                          context: context,
                                          titulo: 'Apartado Registrado',
                                          mensaje:
                                              'El registro se guardó correctamente. ¿Desea imprimir el ticket de comprobante para el cliente?',
                                        );

                                        // 5. Si el usuario confirma, generar e imprimir ticket
                                        if (deseaImprimir == true && mounted) {
                                          try {
                                            await ServicioTicketPdf.instancia
                                                .descargarYAbrirTicket(
                                              context,
                                              ventaApartada,
                                              esCredito: true,
                                            );
                                          } catch (e) {
                                            debugPrint(
                                                'Aviso al imprimir ticket de apartado: $e');
                                          }
                                        }

                                        // 6. Iniciar nueva venta limpia en el carrito y mostrar confirmación
                                        if (mounted) {
                                          cVentas.iniciarVenta();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Venta apartada para $nombre por ${formatoMoneda(ventaApartada.total)}',
                                              ),
                                              backgroundColor:
                                                  AppColors.primary,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                          setState(() {});
                                        }
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                      Icons.bookmark_add_outlined,
                                      size: 18),
                                  label: const Text(
                                    'Apartar / Cuenta por Cobrar',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: BorderSide(color: AppColors.border),
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
                    ),
                  );
                },
              ),
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
            left: false,
            right: false,
            top: true,
            bottom: true,
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
                top: false,
                left: false,
                right: false,
                bottom: true,
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
                              formatoMoneda(totalVenta),
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
