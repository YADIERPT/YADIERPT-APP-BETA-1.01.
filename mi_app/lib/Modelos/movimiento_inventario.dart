import 'package:uuid/uuid.dart';

/// Tipos válidos de movimiento de existencias según las directrices de Planteapp / Supabase.
enum TipoMovimientoInventario {
  venta('venta'),
  compra('compra'),
  ajuste('ajuste'),
  devolucion('devolucion');

  final String valor;
  const TipoMovimientoInventario(this.valor);

  static TipoMovimientoInventario desdeString(String? valor) {
    if (valor == null) return TipoMovimientoInventario.ajuste;
    final normalizado = valor.toLowerCase().trim();
    return TipoMovimientoInventario.values.firstWhere(
      (t) => t.valor == normalizado,
      orElse: () => TipoMovimientoInventario.ajuste,
    );
  }
}

/// Registro inmutable y de solo anexado (append-only) para auditoría de inventario.
class MovimientoInventario {
  final String uuid;
  final String productoUuid;
  final TipoMovimientoInventario tipo;
  final int cantidad; // Positiva entra mercancía, negativa sale mercancía
  final String? referenciaUuid; // UUID de Venta, Compra o Ajuste
  final String? motivo;
  final String? colaboradorUuid;
  final String? dispositivoId;
  final String syncEstado;
  final DateTime createdAt;

  MovimientoInventario({
    String? uuid,
    required this.productoUuid,
    required this.tipo,
    required this.cantidad,
    this.referenciaUuid,
    this.motivo,
    this.colaboradorUuid,
    this.dispositivoId,
    this.syncEstado = 'pendiente',
    DateTime? createdAt,
  })  : uuid = uuid ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().toUtc();

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'producto_uuid': productoUuid,
      'tipo': tipo.valor,
      'cantidad': cantidad,
      'referencia_uuid': referenciaUuid,
      'motivo': motivo,
      'colaborador_uuid': colaboradorUuid,
      'dispositivo_id': dispositivoId,
      'sync_estado': syncEstado,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MovimientoInventario.fromMap(Map<String, dynamic> map) {
    return MovimientoInventario(
      uuid: map['uuid']?.toString() ?? const Uuid().v4(),
      productoUuid: map['producto_uuid']?.toString() ?? '',
      tipo: TipoMovimientoInventario.desdeString(map['tipo']?.toString()),
      cantidad: (map['cantidad'] as num?)?.toInt() ?? 0,
      referenciaUuid: map['referencia_uuid']?.toString(),
      motivo: map['motivo']?.toString(),
      colaboradorUuid: map['colaborador_uuid']?.toString(),
      dispositivoId: map['dispositivo_id']?.toString(),
      syncEstado: map['sync_estado']?.toString() ?? 'pendiente',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
    );
  }
}
