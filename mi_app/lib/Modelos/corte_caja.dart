import 'package:uuid/uuid.dart';

/// Modelo de Arqueo y Corte de Caja por Turno y Terminal para POS multi-caja.
/// Diseñado para operar bajo arquitectura Offline-First con sincronización en Supabase.
class CorteCaja {
  final String id;
  final String uuid;
  final String colaboradorUuid;
  final String dispositivoId;
  final double montoApertura;
  double montoVentasEfectivo;
  double montoAbonosEfectivo;
  double montoEgresos;
  double montoReal;
  String estado; // 'ABIERTA', 'CERRADA'
  String notas;
  final DateTime fechaApertura;
  DateTime? fechaCierre;
  final String createdAt;
  String? updatedAt;
  String? deletedAt;
  String syncEstado;

  CorteCaja({
    String? id,
    String? uuid,
    required this.colaboradorUuid,
    required this.dispositivoId,
    required this.montoApertura,
    this.montoVentasEfectivo = 0.0,
    this.montoAbonosEfectivo = 0.0,
    this.montoEgresos = 0.0,
    this.montoReal = 0.0,
    this.estado = 'ABIERTA',
    this.notas = '',
    DateTime? fechaApertura,
    this.fechaCierre,
    String? createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncEstado = 'pendiente',
  })  : uuid = (uuid != null && uuid.isNotEmpty) ? uuid : const Uuid().v4(),
        id = (id != null && id.isNotEmpty) ? id : (uuid ?? const Uuid().v4()),
        fechaApertura = fechaApertura ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now().toUtc().toIso8601String();

  /// Total de efectivo que el sistema espera encontrar en la gaveta
  double get montoEsperado =>
      montoApertura + montoVentasEfectivo + montoAbonosEfectivo - montoEgresos;

  /// Diferencia entre el conteo ciego real y el monto esperado:
  /// > 0: Sobrante de caja
  /// < 0: Faltante de caja
  /// == 0: Caja cuadrada
  double get diferencia => montoReal - montoEsperado;

  bool get estaAbierta => estado == 'ABIERTA';
  bool get estaCerrada => estado == 'CERRADA';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'colaborador_uuid': colaboradorUuid,
      'dispositivo_id': dispositivoId,
      'monto_apertura': montoApertura,
      'monto_ventas_efectivo': montoVentasEfectivo,
      'monto_abonos_efectivo': montoAbonosEfectivo,
      'monto_egresos': montoEgresos,
      'monto_esperado': montoEsperado,
      'monto_real': montoReal,
      'diferencia': diferencia,
      'estado': estado,
      'notas': notas,
      'fecha_apertura': fechaApertura.toIso8601String(),
      'fecha_cierre': fechaCierre?.toIso8601String(),
      'created_at': createdAt,
      'updated_at': updatedAt ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': deletedAt,
      'sync_estado': syncEstado,
    };
  }

  factory CorteCaja.fromMap(Map<String, dynamic> map) {
    final rawUuid = map['uuid']?.toString() ?? const Uuid().v4();
    return CorteCaja(
      id: map['id']?.toString() ?? rawUuid,
      uuid: rawUuid,
      colaboradorUuid: map['colaborador_uuid']?.toString() ?? '',
      dispositivoId: map['dispositivo_id']?.toString() ?? '',
      montoApertura: (map['monto_apertura'] as num?)?.toDouble() ?? 0.0,
      montoVentasEfectivo: (map['monto_ventas_efectivo'] as num?)?.toDouble() ?? 0.0,
      montoAbonosEfectivo: (map['monto_abonos_efectivo'] as num?)?.toDouble() ?? 0.0,
      montoEgresos: (map['monto_egresos'] as num?)?.toDouble() ?? 0.0,
      montoReal: (map['monto_real'] as num?)?.toDouble() ?? 0.0,
      estado: map['estado']?.toString() ?? 'ABIERTA',
      notas: map['notas']?.toString() ?? '',
      fechaApertura: map['fecha_apertura'] != null
          ? DateTime.tryParse(map['fecha_apertura'].toString()) ?? DateTime.now()
          : DateTime.now(),
      fechaCierre: map['fecha_cierre'] != null
          ? DateTime.tryParse(map['fecha_cierre'].toString())
          : null,
      createdAt: map['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      updatedAt: map['updated_at']?.toString(),
      deletedAt: map['deleted_at']?.toString(),
      syncEstado: map['sync_estado']?.toString() ?? 'pendiente',
    );
  }

  CorteCaja copyWith({
    String? id,
    String? uuid,
    String? colaboradorUuid,
    String? dispositivoId,
    double? montoApertura,
    double? montoVentasEfectivo,
    double? montoAbonosEfectivo,
    double? montoEgresos,
    double? montoReal,
    String? estado,
    String? notas,
    DateTime? fechaApertura,
    DateTime? fechaCierre,
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
    String syncEstado = 'pendiente',
  }) {
    return CorteCaja(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      colaboradorUuid: colaboradorUuid ?? this.colaboradorUuid,
      dispositivoId: dispositivoId ?? this.dispositivoId,
      montoApertura: montoApertura ?? this.montoApertura,
      montoVentasEfectivo: montoVentasEfectivo ?? this.montoVentasEfectivo,
      montoAbonosEfectivo: montoAbonosEfectivo ?? this.montoAbonosEfectivo,
      montoEgresos: montoEgresos ?? this.montoEgresos,
      montoReal: montoReal ?? this.montoReal,
      estado: estado ?? this.estado,
      notas: notas ?? this.notas,
      fechaApertura: fechaApertura ?? this.fechaApertura,
      fechaCierre: fechaCierre ?? this.fechaCierre,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncEstado: syncEstado,
    );
  }
}

