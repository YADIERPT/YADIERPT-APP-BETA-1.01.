import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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

  /// Genera un documento PDF con el ticket de venta y lo guarda localmente en el
  /// directorio de documentos de la aplicación (100% offline).
  Future<File> generarYGuardarTicketPdf(Venta venta) async {
    final pdf = pw.Document();

    final String folio = venta.id.length > 8
        ? venta.id.substring(venta.id.length - 8)
        : venta.id;

    final String fechaStr =
        '${venta.fecha.day.toString().padLeft(2, '0')}/${venta.fecha.month.toString().padLeft(2, '0')}/${venta.fecha.year} ${venta.fecha.hour.toString().padLeft(2, '0')}:${venta.fecha.minute.toString().padLeft(2, '0')}';

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
                    pw.Text(
                      'Comprobante de Operación Offline',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
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
                'Estado: ${venta.estado.name.toUpperCase()}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: venta.estado == EstadoVenta.apartada
                      ? PdfColors.amber800
                      : PdfColors.green900,
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
                      'Descripción',
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
                    'TOTAL:',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green900,
                    ),
                  ),
                  pw.Text(
                    '\$${venta.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green900,
                    ),
                  ),
                ],
              ),

              // En caso de apartado con saldo pendiente
              if (venta.tieneSaldoPendiente) ...[
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Anticipo Pagado:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                      '\$${venta.montoPagado.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Saldo Pendiente:',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.amber900,
                      ),
                    ),
                    pw.Text(
                      '\$${venta.saldoPendiente.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.amber900,
                      ),
                    ),
                  ],
                ),
              ],

              pw.Spacer(),

              // Pie de Recibo
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      '¡Gracias por cultivar vida con nosotros!',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Conserve este comprobante para cualquier aclaración.',
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

    final archivo = File('$rutaDirectorio/ticket_$folio.pdf');
    final bytes = await pdf.save();
    await archivo.writeAsBytes(bytes);

    return archivo;
  }

  /// Genera el ticket PDF, lo guarda en el dispositivo y despliega el visor nativo.
  Future<void> descargarYAbrirTicket(BuildContext context, Venta venta) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generando ticket en PDF...'),
          duration: Duration(milliseconds: 900),
        ),
      );

      final archivo = await generarYGuardarTicketPdf(venta);

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
                  filename: 'ticket_$folio.pdf',
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
              'Ticket descargado con éxito.',
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
}
