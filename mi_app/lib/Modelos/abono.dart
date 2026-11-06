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

