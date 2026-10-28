enum NivelUrgencia {
  critico,
  alto,
  moderado,
  bajaRotacion;

  String get etiqueta {
    switch (this) {
      case NivelUrgencia.critico:
        return 'Crítico';
      case NivelUrgencia.alto:
        return 'Alto';
      case NivelUrgencia.moderado:
        return 'Moderado';
      case NivelUrgencia.bajaRotacion:
        return 'Baja Rotación';
    }
  }

  static NivelUrgencia desdeString(String valor) {
    switch (valor.toUpperCase()) {
      case 'CRITICO':
        return NivelUrgencia.critico;
      case 'ALTO':
        return NivelUrgencia.alto;
      case 'MODERADO':
        return NivelUrgencia.moderado;
      case 'BAJA_ROTACION':
      case 'BAJAROTACION':
        return NivelUrgencia.bajaRotacion;
      default:
        return NivelUrgencia.moderado;
    }
  }
}

enum EstadoRecomendacion {
  pendiente,
  aplicada,
  descartada;

  static EstadoRecomendacion desdeString(String valor) {
    switch (valor.toUpperCase()) {
      case 'APLICADA':
        return EstadoRecomendacion.aplicada;
      case 'DESCARTADA':
        return EstadoRecomendacion.descartada;
      case 'PENDIENTE':
      default:
        return EstadoRecomendacion.pendiente;
    }
  }
}

class RecomendacionCompra {
  final String id;
  final String productoId;
  final String nombreProducto;
  final String tipo; // 'planta' o 'articulo'
  final int stockActual;
  final int umbralStockCritico;
  final int cantidadSugerida;
  final double costoUnitario;
  final double precioVenta;
  final double costoTotalEstimado;
  final double gananciaEstimada;
  final double margenPorcentual;
  final NivelUrgencia nivelUrgencia;
  final double diasHastaAgotamiento;
  final String motivoRazonado;
  final DateTime fechaGeneracion;
  final EstadoRecomendacion estado;
  final double velocidadDiaria;

  const RecomendacionCompra({
    required this.id,
    required this.productoId,
    required this.nombreProducto,
    required this.tipo,
    required this.stockActual,
    required this.umbralStockCritico,
    required this.cantidadSugerida,
    required this.costoUnitario,
    required this.precioVenta,
    required this.costoTotalEstimado,
    required this.gananciaEstimada,
    required this.margenPorcentual,
    required this.nivelUrgencia,
    required this.diasHastaAgotamiento,
    required this.motivoRazonado,
    required this.fechaGeneracion,
    this.estado = EstadoRecomendacion.pendiente,
    this.velocidadDiaria = 0.0,
  });

  bool get esPlanta => tipo.toLowerCase() == 'planta';
  bool get esCritico => nivelUrgencia == NivelUrgencia.critico;
  bool get esPendiente => estado == EstadoRecomendacion.pendiente;
  bool get sugiereCompra => cantidadSugerida > 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producto_id': productoId,
      'cantidad_sugerida': cantidadSugerida,
      'costo_estimado': costoTotalEstimado,
      'ganancia_estimada': gananciaEstimada,
      'nivel_urgencia': nivelUrgencia.name.toUpperCase(),
      'motivo_razonado': motivoRazonado,
      'dias_hasta_agotamiento': diasHastaAgotamiento,
      'fecha_generacion': fechaGeneracion.toIso8601String(),
      'estado': estado.name.toUpperCase(),
    };
  }

  factory RecomendacionCompra.fromDbMap({
    required Map<String, dynamic> map,
    required String nombreProducto,
    required String tipo,
    required int stockActual,
    required int umbralStockCritico,
    required double costoUnitario,
    required double precioVenta,
    double velocidadDiaria = 0.0,
  }) {
    final cantidadSugerida = (map['cantidad_sugerida'] as num?)?.toInt() ?? 0;
    final costoTotal =
        (map['costo_estimado'] as num?)?.toDouble() ?? (cantidadSugerida * costoUnitario);
    final ganancia = (map['ganancia_estimada'] as num?)?.toDouble() ??
        (cantidadSugerida * (precioVenta - costoUnitario));
    final margen = precioVenta > 0
        ? (((precioVenta - costoUnitario) / precioVenta) * 100)
        : 0.0;

    return RecomendacionCompra(
      id: map['id'] as String,
      productoId: map['producto_id'] as String,
      nombreProducto: nombreProducto,
      tipo: tipo,
      stockActual: stockActual,
      umbralStockCritico: umbralStockCritico,
      cantidadSugerida: cantidadSugerida,
      costoUnitario: costoUnitario,
      precioVenta: precioVenta,
      costoTotalEstimado: costoTotal,
      gananciaEstimada: ganancia,
      margenPorcentual: margen,
      nivelUrgencia: NivelUrgencia.desdeString(
        map['nivel_urgencia'] as String? ?? 'MODERADO',
      ),
      diasHastaAgotamiento:
          (map['dias_hasta_agotamiento'] as num?)?.toDouble() ?? 999.0,
      motivoRazonado: map['motivo_razonado'] as String? ?? '',
      fechaGeneracion: map['fecha_generacion'] != null
          ? DateTime.tryParse(map['fecha_generacion'] as String) ?? DateTime.now()
          : DateTime.now(),
      estado: EstadoRecomendacion.desdeString(
        map['estado'] as String? ?? 'PENDIENTE',
      ),
      velocidadDiaria: velocidadDiaria,
    );
  }

  RecomendacionCompra copyWith({
    EstadoRecomendacion? estado,
  }) {
    return RecomendacionCompra(
      id: id,
      productoId: productoId,
      nombreProducto: nombreProducto,
      tipo: tipo,
      stockActual: stockActual,
      umbralStockCritico: umbralStockCritico,
      cantidadSugerida: cantidadSugerida,
      costoUnitario: costoUnitario,
      precioVenta: precioVenta,
      costoTotalEstimado: costoTotalEstimado,
      gananciaEstimada: gananciaEstimada,
      margenPorcentual: margenPorcentual,
      nivelUrgencia: nivelUrgencia,
      diasHastaAgotamiento: diasHastaAgotamiento,
      motivoRazonado: motivoRazonado,
      fechaGeneracion: fechaGeneracion,
      estado: estado ?? this.estado,
      velocidadDiaria: velocidadDiaria,
    );
  }
}
