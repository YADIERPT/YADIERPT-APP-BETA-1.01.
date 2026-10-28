class CalibracionProducto {
  final String productoId;
  final double velocidadDiaria; // Unidades promedio vendidas por día
  final double variabilidad; // Desviación estándar de ventas diarias
  final double diasCobertura; // Días estimados antes de agotarse
  final double tendencia; // Ratio de aceleración/desaceleración reciente vs histórico
  final String nivelRotacion; // 'ALTA', 'MEDIA', 'BAJA', 'NULA'
  final double scorePrioridad; // Puntuación calculada para reorden
  final DateTime ultimaCalibracion;
  final int totalUnidadesHistoricas;

  const CalibracionProducto({
    required this.productoId,
    required this.velocidadDiaria,
    required this.variabilidad,
    required this.diasCobertura,
    required this.tendencia,
    required this.nivelRotacion,
    required this.scorePrioridad,
    required this.ultimaCalibracion,
    required this.totalUnidadesHistoricas,
  });

  Map<String, dynamic> toMap() {
    return {
      'producto_id': productoId,
      'velocidad_diaria': velocidadDiaria,
      'variabilidad': variabilidad,
      'dias_cobertura': diasCobertura,
      'tendencia': tendencia,
      'nivel_rotacion': nivelRotacion,
      'score_prioridad': scorePrioridad,
      'ultima_calibracion': ultimaCalibracion.toIso8601String(),
      'total_unidades_historicas': totalUnidadesHistoricas,
    };
  }

  factory CalibracionProducto.fromMap(Map<String, dynamic> map) {
    return CalibracionProducto(
      productoId: map['producto_id'] as String,
      velocidadDiaria: (map['velocidad_diaria'] as num?)?.toDouble() ?? 0.0,
      variabilidad: (map['variabilidad'] as num?)?.toDouble() ?? 0.0,
      diasCobertura: (map['dias_cobertura'] as num?)?.toDouble() ?? 999.0,
      tendencia: (map['tendencia'] as num?)?.toDouble() ?? 0.0,
      nivelRotacion: (map['nivel_rotacion'] as String?) ?? 'MEDIA',
      scorePrioridad: (map['score_prioridad'] as num?)?.toDouble() ?? 0.0,
      ultimaCalibracion: map['ultima_calibracion'] != null
          ? DateTime.tryParse(map['ultima_calibracion'] as String) ?? DateTime.now()
          : DateTime.now(),
      totalUnidadesHistoricas:
          (map['total_unidades_historicas'] as num?)?.toInt() ?? 0,
    );
  }

  CalibracionProducto copyWith({
    String? productoId,
    double? velocidadDiaria,
    double? variabilidad,
    double? diasCobertura,
    double? tendencia,
    String? nivelRotacion,
    double? scorePrioridad,
    DateTime? ultimaCalibracion,
    int? totalUnidadesHistoricas,
  }) {
    return CalibracionProducto(
      productoId: productoId ?? this.productoId,
      velocidadDiaria: velocidadDiaria ?? this.velocidadDiaria,
      variabilidad: variabilidad ?? this.variabilidad,
      diasCobertura: diasCobertura ?? this.diasCobertura,
      tendencia: tendencia ?? this.tendencia,
      nivelRotacion: nivelRotacion ?? this.nivelRotacion,
      scorePrioridad: scorePrioridad ?? this.scorePrioridad,
      ultimaCalibracion: ultimaCalibracion ?? this.ultimaCalibracion,
      totalUnidadesHistoricas:
          totalUnidadesHistoricas ?? this.totalUnidadesHistoricas,
    );
  }
}
