import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../Modelos/abono.dart';
import '../Modelos/venta.dart';
import '../Tema/app_theme.dart';

/// Servicio para la generación, almacenamiento y visualización offline de
/// recibos y tickets de compra en formato PDF utilizando `pdf`, `path_provider`
/// y `open_filex`.
class ServicioTicketPdf {
  static final ServicioTicketPdf _instancia = ServicioTicketPdf._interno();

  /// Acceso a la instancia Singleton del servicio.
  static ServicioTicketPdf get instancia => _instancia;

  ServicioTicketPdf._interno();

  /// Genera un documento PDF con el ticket de venta (o ticket de crédito/apartado)
  /// y lo guarda localmente en el directorio de documentos de la aplicación (100% offline).
  Future<File> generarYGuardarTicketPdf(
    Venta venta, {
    bool esCredito = false,
  }) async {
    final pdf = pw.Document();

    final String folio = venta.id.length > 8
        ? venta.id.substring(venta.id.length - 8)
        : venta.id;

    final String fechaStr =
        '${venta.fecha.day.toString().padLeft(2, '0')}/${venta.fecha.month.toString().padLeft(2, '0')}/${venta.fecha.year} ${venta.fecha.hour.toString().padLeft(2, '0')}:${venta.fecha.minute.toString().padLeft(2, '0')}';

    final bool esModoCredito = esCredito ||
        venta.estado == EstadoVenta.apartada ||
        venta.tieneSaldoPendiente;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado Corporativo
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'PLANTEAPP',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Vivero & Botánica • Punto de Venta',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: pw.BoxDecoration(
                        color: esModoCredito ? PdfColors.amber100 : PdfColors.green100,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(
                          color: esModoCredito ? PdfColors.amber800 : PdfColors.green800,
                          width: 0.8,
                        ),
                      ),
                      child: pw.Text(
                        esModoCredito
                            ? 'TICKET DE CRÉDITO / APARTADO'
                            : 'TICKET DE VENTA',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: esModoCredito ? PdfColors.amber900 : PdfColors.green900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.8, color: PdfColors.grey400),
              pw.SizedBox(height: 4),

              // Datos Generales de la Venta
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Folio: #$folio',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    fechaStr,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Cliente: ${venta.cliente.isNotEmpty ? venta.cliente : "Público General"}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Estado: ${esModoCredito ? "CRÉDITO / APARTADO" : venta.estado.name.toUpperCase()}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: esModoCredito ? PdfColors.amber800 : PdfColors.green900,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8, color: PdfColors.grey400),
              pw.SizedBox(height: 4),

              // Tabla / Listado de Artículos
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Cant.',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'Descripción (Plantas apartadas)',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'P. Unit',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Total',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),

              // Filas de productos
              ...venta.articulos.map((art) {
                final double subtotalLinea = art.cantidad * art.precioUnitario;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          '${art.cantidad}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(
                          art.producto.nombre,
                          style: const pw.TextStyle(fontSize: 8),
                          maxLines: 1,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          '\$${art.precioUnitario.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          '\$${subtotalLinea.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8, color: PdfColors.grey400),
              pw.SizedBox(height: 4),

              // Totales y Desglose Financiero
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(
                    '\$${venta.subtotalVenta.toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              if (venta.totalIva > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('IVA:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      '\$${venta.totalIva.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL ORIGINAL:',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900,
                    ),
                  ),
                  pw.Text(
                    '\$${venta.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900,
                    ),
                  ),
                ],
              ),

              // En caso de apartado / crédito con saldo pendiente
              if (esModoCredito) ...[
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.amber400, width: 0.6),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Anticipo / Pagado:', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text(
                            '\$${venta.montoPagado.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'SALDO PENDIENTE:',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red900,
                            ),
                          ),
                          pw.Text(
                            '\$${venta.saldoPendiente.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              pw.Spacer(),

              // Pie de Recibo
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      esModoCredito
                          ? '¡Plantas apartadas garantizadas! Conserve su comprobante.'
                          : '¡Gracias por cultivar vida con nosotros!',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: esModoCredito ? PdfColors.amber900 : PdfColors.green800,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Presente este ticket para abonar o retirar su mercancía botánica.',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Obtener directorio local del dispositivo
    final directorio = await getApplicationDocumentsDirectory();
    final String rutaDirectorio = '${directorio.path}/tickets';
    final dirTickets = Directory(rutaDirectorio);

    if (!await dirTickets.exists()) {
      await dirTickets.create(recursive: true);
    }

    final archivo = File('$rutaDirectorio/ticket_${esModoCredito ? "credito_" : ""}$folio.pdf');

    // Compilación y serialización del PDF en un Isolate secundario para no bloquear el Main Thread (60 FPS sin Jank)
    final Uint8List bytes = kIsWeb
        ? await pdf.save()
        : await Isolate.run(() => pdf.save());

    await archivo.writeAsBytes(bytes);

    return archivo;
  }

  /// Genera el ticket PDF, lo guarda en el dispositivo y despliega el visor nativo.
  /// Soporta tanto tickets de venta regular como tickets de crédito/apartado con saldo pendiente.
  Future<void> descargarYAbrirTicket(
    BuildContext context,
    Venta venta, {
    bool esCredito = false,
  }) async {
    try {
      final bool esModoCredito = esCredito ||
          venta.estado == EstadoVenta.apartada ||
          venta.tieneSaldoPendiente;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            esModoCredito
                ? 'Generando ticket de crédito / apartado en PDF...'
                : 'Generando ticket de venta en PDF...',
          ),
          duration: const Duration(milliseconds: 900),
        ),
      );

      final archivo = await generarYGuardarTicketPdf(venta, esCredito: esCredito);

      if (!context.mounted) return;

      final String folio = venta.id.length > 8
          ? venta.id.substring(venta.id.length - 8)
          : venta.id;
      final resultado = await OpenFilex.open(archivo.path);

      if (resultado.type != ResultType.done && context.mounted) {
        String mensaje = 'Ticket guardado en: ${archivo.path}';
        if (resultado.type == ResultType.noAppToOpen) {
          mensaje = 'No se encontró un visor de PDF instalado en este dispositivo.';
        } else if (resultado.type == ResultType.permissionDenied) {
          mensaje = 'Permiso denegado por el sistema para abrir el archivo.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.card,
            duration: const Duration(seconds: 4),
            content: Text(
              mensaje,
              style: TextStyle(color: AppColors.textPrimary),
            ),
            action: SnackBarAction(
              label: 'Compartir/Imprimir',
              textColor: AppColors.primary,
              onPressed: () async {
                final bytes = await archivo.readAsBytes();
                await Printing.sharePdf(
                  bytes: bytes,
                  filename: 'ticket_${esModoCredito ? "credito_" : ""}$folio.pdf',
                );
              },
            ),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.card,
            content: Text(
              esModoCredito
                  ? 'Ticket de crédito/apartado generado con éxito.'
                  : 'Ticket descargado con éxito.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Error al generar el ticket: $e'),
        ),
      );
    }
  }

  /// Genera un "COMPROBANTE DE PAGO" en formato PDF con la información oficial del abono:
  /// Nombre del Cliente, Folio de Venta, Total Original, Abono de Hoy y Saldo Restante.
  Future<File> generarYGuardarComprobanteAbonoPdf(ComprobanteAbono comprobante) async {
    final pdf = pw.Document();

    final String folioAbono = comprobante.idAbono.length > 8
        ? comprobante.idAbono.substring(comprobante.idAbono.length - 8)
        : comprobante.idAbono;

    final String folioVenta = comprobante.ventaId.length > 8
        ? comprobante.ventaId.substring(comprobante.ventaId.length - 8)
        : comprobante.ventaId;

    final String fechaStr =
        '${comprobante.fecha.day.toString().padLeft(2, '0')}/${comprobante.fecha.month.toString().padLeft(2, '0')}/${comprobante.fecha.year} ${comprobante.fecha.hour.toString().padLeft(2, '0')}:${comprobante.fecha.minute.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado Corporativo
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'PLANTEAPP',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Vivero & Botánica • Punto de Venta',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green100,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(
                          color: PdfColors.green800,
                          width: 0.8,
                        ),
                      ),
                      child: pw.Text(
                        'COMPROBANTE DE PAGO',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.8, color: PdfColors.grey400),
              pw.SizedBox(height: 4),

              // Metadatos de la Transacción
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Recibo de Abono: #$folioAbono',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    fechaStr,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Folio Venta Apartada: #$folioVenta',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey800,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Cliente: ${comprobante.cliente.isNotEmpty ? comprobante.cliente : "Cliente Mostrador"}',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Método de Pago: ${comprobante.metodoPago}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.8, color: PdfColors.grey400),
              pw.SizedBox(height: 6),

              // Desglose Financiero Estructurado
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Original:',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          '\$${comprobante.totalOriginal.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Abono acumulado previo:',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          '\$${(comprobante.totalPagado - comprobante.abonoHoy).clamp(0.0, double.infinity).toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'ABONO DE HOY:',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        ),
                        pw.Text(
                          '\$${comprobante.abonoHoy.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'SALDO RESTANTE:',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: comprobante.saldoRestante <= 0.01
                                ? PdfColors.green900
                                : PdfColors.red900,
                          ),
                        ),
                        pw.Text(
                          '\$${comprobante.saldoRestante.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: comprobante.saldoRestante <= 0.01
                                ? PdfColors.green900
                                : PdfColors.red900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Etiqueta de Estado de Liquidación
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: comprobante.liquidado ? PdfColors.green50 : PdfColors.amber50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(
                      color: comprobante.liquidado ? PdfColors.green700 : PdfColors.amber700,
                      width: 0.6,
                    ),
                  ),
                  child: pw.Text(
                    comprobante.liquidado
                        ? '¡CUENTA LIQUIDADA EN SU TOTALIDAD!'
                        : 'CUENTA ACTIVA CON SALDO PENDIENTE',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: comprobante.liquidado ? PdfColors.green900 : PdfColors.amber900,
                    ),
                  ),
                ),
              ),

              pw.Spacer(),

              // Pie de Página
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      '¡Gracias por su puntual abono!',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Conserve este comprobante como amparo de su pago.',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Obtener directorio local del dispositivo
    final directorio = await getApplicationDocumentsDirectory();
    final String rutaDirectorio = '${directorio.path}/comprobantes_abono';
    final dirAbonos = Directory(rutaDirectorio);

    if (!await dirAbonos.exists()) {
      await dirAbonos.create(recursive: true);
    }

    final archivo = File('$rutaDirectorio/comprobante_abono_$folioAbono.pdf');

    // Serialización en Isolate de fondo
    final Uint8List bytes = kIsWeb
        ? await pdf.save()
        : await Isolate.run(() => pdf.save());

    await archivo.writeAsBytes(bytes);
    return archivo;
  }

  /// Despliega el visor de PDF para el Comprobante de Abono generado
  Future<void> descargarYAbrirComprobanteAbono(
    BuildContext context, {
    required ComprobanteAbono comprobante,
  }) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generando comprobante de pago en PDF...'),
          duration: Duration(milliseconds: 900),
        ),
      );

      final archivo = await generarYGuardarComprobanteAbonoPdf(comprobante);

      if (!context.mounted) return;

      final String folio = comprobante.idAbono.length > 8
          ? comprobante.idAbono.substring(comprobante.idAbono.length - 8)
          : comprobante.idAbono;

      final resultado = await OpenFilex.open(archivo.path);

      if (resultado.type != ResultType.done && context.mounted) {
        String mensaje = 'Comprobante guardado en: ${archivo.path}';
        if (resultado.type == ResultType.noAppToOpen) {
          mensaje = 'No se encontró un visor de PDF instalado en este dispositivo.';
        } else if (resultado.type == ResultType.permissionDenied) {
          mensaje = 'Permiso denegado por el sistema para abrir el archivo.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.card,
            duration: const Duration(seconds: 4),
            content: Text(
              mensaje,
              style: TextStyle(color: AppColors.textPrimary),
            ),
            action: SnackBarAction(
              label: 'Compartir/Imprimir',
              textColor: AppColors.primary,
              onPressed: () async {
                final bytes = await archivo.readAsBytes();
                await Printing.sharePdf(
                  bytes: bytes,
                  filename: 'comprobante_abono_$folio.pdf',
                );
              },
            ),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.card,
            content: Text(
              'Comprobante de pago generado con éxito.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Error al generar comprobante de abono: $e'),
        ),
      );
    }
  }
}

