/// Modelo que representa un abono parcial o liquidación de una cuenta por cobrar (venta apartada).
class Abono {
  final String id;
  final String ventaId;
  final double monto;
  final DateTime fecha;
  final String metodoPago;

  Abono({
    required this.id,
    required this.ventaId,
    required this.monto,
    required this.fecha,
    this.metodoPago = 'Efectivo',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'venta_id': ventaId,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'metodoPago': metodoPago,
    };
  }

  factory Abono.fromMap(Map<String, dynamic> map) {
    return Abono(
      id: map['id']?.toString() ?? '',
      ventaId: map['venta_id']?.toString() ?? '',
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      fecha: DateTime.tryParse(map['fecha']?.toString() ?? '') ?? DateTime.now(),
      metodoPago: map['metodoPago']?.toString() ?? 'Efectivo',
    );
  }
}

/// Estructura de datos inmutable para el Comprobante de Pago de Abono.
/// Cumple con los requerimientos fiscales y operativos para comprobar abonos y saldos pendientes.
class ComprobanteAbono {
  final String idAbono;
  final String ventaId;
  final String cliente;
  final double totalOriginal;
  final double abonoHoy;
  final double saldoRestante;
  final double totalPagado;
  final DateTime fecha;
  final String metodoPago;
  final bool liquidado;

  ComprobanteAbono({
    required this.idAbono,
    required this.ventaId,
    required this.cliente,
    required this.totalOriginal,
    required this.abonoHoy,
    required this.saldoRestante,
    required this.totalPagado,
    required this.fecha,
    this.metodoPago = 'Efectivo',
    this.liquidado = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'idAbono': idAbono,
      'ventaId': ventaId,
      'cliente': cliente,
      'totalOriginal': totalOriginal,
      'abonoHoy': abonoHoy,
      'saldoRestante': saldoRestante,
      'totalPagado': totalPagado,
      'fecha': fecha.toIso8601String(),
      'metodoPago': metodoPago,
      'liquidado': liquidado ? 1 : 0,
    };
  }
}


