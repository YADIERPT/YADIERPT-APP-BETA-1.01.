enum TipoTransaccion { ingreso, egreso, merma }

class TransaccionFinanciera {
  String id;
  TipoTransaccion tipo;
  double monto;
  DateTime fecha;
  String descripcion;

  TransaccionFinanciera({
    required this.id,
    required this.tipo,
    required this.monto,
    required this.fecha,
    required this.descripcion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo.name,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
      'descripcion': descripcion,
    };
  }

  factory TransaccionFinanciera.fromMap(Map<String, dynamic> map) {
    final tipoRaw = map['tipo']?.toString().toLowerCase().trim() ?? '';
    return TransaccionFinanciera(
      id: map['id']?.toString() ?? '',
      tipo: TipoTransaccion.values.firstWhere(
        (e) => e.name.toLowerCase() == tipoRaw,
        orElse: () => TipoTransaccion.ingreso,
      ),
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      fecha: map['fecha'] != null
          ? DateTime.tryParse(map['fecha'].toString()) ?? DateTime.now()
          : DateTime.now(),
      descripcion: map['descripcion']?.toString() ?? '',
    );
  }

  bool get esIngreso => tipo == TipoTransaccion.ingreso;
  bool get esEgreso =>
      tipo == TipoTransaccion.egreso || tipo == TipoTransaccion.merma;
}

class RendimientoFinanciero {
  double totalIngresos;
  double totalEgresos;

  RendimientoFinanciero({this.totalIngresos = 0.0, this.totalEgresos = 0.0});

  double get gananciasNetas => totalIngresos - totalEgresos;

  double get margenRendimiento {
    if (totalIngresos == 0) return 0.0;
    return (gananciasNetas / totalIngresos) * 100;
  }
}
