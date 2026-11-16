/// Modelo de datos que representa una mutación pendiente en la cola de sincronización (Outbox Pattern).
class ElementoColaSync {
  final int? id;
  final String tabla;
  final String registroUuid;
  final String operacion; // 'upsert' o 'delete'
  final String payloadJson;
  final int intentos;
  final String? ultimoError;
  final DateTime createdAt;

  ElementoColaSync({
    this.id,
    required this.tabla,
    required this.registroUuid,
    required this.operacion,
    required this.payloadJson,
    this.intentos = 0,
    this.ultimoError,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'tabla': tabla,
      'registro_uuid': registroUuid,
      'operacion': operacion,
      'payload_json': payloadJson,
      'intentos': intentos,
      'ultimo_error': ultimoError,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ElementoColaSync.fromMap(Map<String, dynamic> map) {
    return ElementoColaSync(
      id: (map['id'] as num?)?.toInt(),
      tabla: map['tabla']?.toString() ?? '',
      registroUuid: map['registro_uuid']?.toString() ?? '',
      operacion: map['operacion']?.toString() ?? 'upsert',
      payloadJson: map['payload_json']?.toString() ?? '{}',
      intentos: (map['intentos'] as num?)?.toInt() ?? 0,
      ultimoError: map['ultimo_error']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now().toUtc()
          : DateTime.now().toUtc(),
    );
  }
}
