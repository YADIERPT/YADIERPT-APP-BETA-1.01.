import 'producto.dart';

enum EstadoVenta { enProceso, completada, cancelada, apartada }

class ArticuloVenta {
  Producto producto;
  int cantidad;
  double precioUnitario;

  ArticuloVenta({
    required this.producto,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;

  Map<String, dynamic> toMap(String ventaId) {
    return {
      'venta_id': ventaId,
      'producto_id': producto.id,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
    };
  }

  factory ArticuloVenta.fromMap(Map<String, dynamic> map, Producto producto) {
    return ArticuloVenta(
      producto: producto,
      cantidad: map['cantidad'],
      precioUnitario: map['precioUnitario'],
    );
  }
}

class Venta {
  String id;
  DateTime fecha;
  EstadoVenta estado;
  List<ArticuloVenta> articulos;
  double porcentajeIva;
  bool aplicarIva;
  String cliente;
  double montoPagado;
  String notas;

  Venta({
    required this.id,
    required this.fecha,
    this.estado = EstadoVenta.enProceso,
    List<ArticuloVenta>? articulos,
    this.porcentajeIva = 0.16,
    this.aplicarIva = true,
    this.cliente = 'Cliente Mostrador',
    this.montoPagado = 0.0,
    this.notas = '',
  }) : articulos = articulos ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fecha': fecha.toIso8601String(),
      'estado': estado.name,
      'porcentajeIva': porcentajeIva,
      'aplicarIva': aplicarIva ? 1 : 0,
      'cliente': cliente,
      'montoPagado': montoPagado,
      'notas': notas,
    };
  }

  factory Venta.fromMap(
    Map<String, dynamic> map,
    List<ArticuloVenta> articulosCargados,
  ) {
    return Venta(
      id: map['id'],
      fecha: DateTime.parse(map['fecha']),
      estado: EstadoVenta.values.firstWhere((e) => e.name == map['estado']),
      porcentajeIva: (map['porcentajeIva'] as num).toDouble(),
      aplicarIva: map['aplicarIva'] != null ? map['aplicarIva'] == 1 : true,
      cliente: map['cliente']?.toString() ?? 'Cliente Mostrador',
      montoPagado: (map['montoPagado'] as num?)?.toDouble() ?? 0.0,
      notas: map['notas']?.toString() ?? '',
      articulos: articulosCargados,
    );
  }

  void agregarArticulo(Producto producto, int cantidad) {
    final indiceExistente = articulos.indexWhere(
      (art) => art.producto.id == producto.id,
    );

    if (indiceExistente != -1) {
      articulos[indiceExistente].cantidad += cantidad;
    } else {
      articulos.add(
        ArticuloVenta(
          producto: producto,
          cantidad: cantidad,
          precioUnitario: producto.precioVenta,
        ),
      );
    }
  }

  double get subtotalVenta {
    return articulos.fold(0, (suma, articulo) => suma + articulo.subtotal);
  }

  double get totalIva => aplicarIva ? (subtotalVenta * porcentajeIva) : 0.0;

  double get total => subtotalVenta + totalIva;

  /// Saldo pendiente por liquidar en ventas apartadas / cuentas por cobrar
  double get saldoPendiente => (total - montoPagado).clamp(0.0, double.infinity);

  /// Determina si la venta mantiene un saldo adeudado
  bool get tieneSaldoPendiente => saldoPendiente > 0.001;

  /// Indica si la venta corresponde a un apartado
  bool get esApartada => estado == EstadoVenta.apartada;

  /// Proporción del monto pagado sobre el total (0.0 a 1.0)
  double get porcentajePagado =>
      total > 0 ? (montoPagado / total).clamp(0.0, 1.0) : 1.0;

  void completarVenta() {
    estado = EstadoVenta.completada;
    montoPagado = total;
  }

  void cancelarVenta() {
    estado = EstadoVenta.cancelada;
  }

  void apartarVenta({double abonoInicial = 0.0, String? nombreCliente}) {
    estado = EstadoVenta.apartada;
    montoPagado = abonoInicial;
    if (nombreCliente != null && nombreCliente.trim().isNotEmpty) {
      cliente = nombreCliente.trim();
    }
  }
}
