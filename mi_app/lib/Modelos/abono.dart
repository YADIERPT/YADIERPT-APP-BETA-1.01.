import 'package:uuid/uuid.dart';

/// Modelo que representa un abono parcial o liquidación de una cuenta por cobrar (venta apartada).
class Abono {
  final String id;
  final String uuid;
  final String ventaId;
  final String? ventaUuid;
  final String? deudorUuid;
  final String? colaboradorUuid;
  final double monto;
  final DateTime fecha;
  final String metodoPago;
  final String? updatedAt;
  final String? deletedAt;
  final String syncEstado;
  final String? dispositivoId;

  Abono({
    required this.id,
    String? uuid,
    required this.ventaId,
    this.ventaUuid,
    this.deudorUuid,
    this.colaboradorUuid,
    required this.monto,
    required this.fecha,
    this.metodoPago = 'Efectivo',
    this.updatedAt,
    this.deletedAt,
    this.syncEstado = 'pendiente',
    this.dispositivoId,
  }) : uuid = (uuid != null && uuid.isNotEmpty) ? uuid : const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'venta_id': ventaId,
      'venta_uuid': ventaUuid,
      'deudor_uuid': deudorUuid,
      'colaborador_uuid': colaboradorUuid,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'metodoPago': metodoPago,
      'updated_at': updatedAt ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': deletedAt,
      'sync_estado': syncEstado,
      'dispositivo_id': dispositivoId,
    };
  }

  factory Abono.fromMap(Map<String, dynamic> map) {
    return Abono(
      id: map['id']?.toString() ?? '',
      uuid: map['uuid']?.toString(),
      ventaId: map['venta_id']?.toString() ?? '',
      ventaUuid: map['venta_uuid']?.toString(),
      deudorUuid: map['deudor_uuid']?.toString(),
      colaboradorUuid: map['colaborador_uuid']?.toString(),
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      fecha: DateTime.tryParse(map['fecha']?.toString() ?? '') ?? DateTime.now(),
      metodoPago: map['metodoPago']?.toString() ?? 'Efectivo',
      updatedAt: map['updated_at']?.toString(),
      deletedAt: map['deleted_at']?.toString(),
      syncEstado: map['sync_estado']?.toString() ?? 'pendiente',
      dispositivoId: map['dispositivo_id']?.toString(),
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


