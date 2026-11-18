import 'package:uuid/uuid.dart';
import 'producto.dart';

enum EstadoVenta { enProceso, completada, cancelada, apartada, liquidada }

class ArticuloVenta {
  String id;
  String uuid;
  String? ventaUuid;
  String? productoUuid;
  Producto producto;
  int cantidad;
  double precioUnitario;
  String createdAt;
  String? updatedAt;
  String? deletedAt;
  String syncEstado;
  String? dispositivoId;

  String get nombre => producto.nombre;

  ArticuloVenta({
    String? id,
    String? uuid,
    String? ventaUuid,
    String? productoUuid,
    required Producto producto,
    required int cantidad,
    required double precioUnitario,
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
    String syncEstado = 'pendiente',
    String? dispositivoId,
  }) : this._(
          id: id ?? uuid ?? const Uuid().v4(),
          uuid: uuid ?? id,
          ventaUuid: ventaUuid,
          productoUuid: productoUuid,
          producto: producto,
          cantidad: cantidad,
          precioUnitario: precioUnitario,
          createdAt: createdAt,
          updatedAt: updatedAt,
          deletedAt: deletedAt,
          syncEstado: syncEstado,
          dispositivoId: dispositivoId,
        );

  ArticuloVenta._({
    required this.id,
    String? uuid,
    this.ventaUuid,
    this.productoUuid,
    required this.producto,
    required this.cantidad,
    required this.precioUnitario,
    String? createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncEstado = 'pendiente',
    this.dispositivoId,
  })  : uuid = uuid ?? id,
        createdAt = createdAt ?? DateTime.now().toUtc().toIso8601String();

  double get subtotal => cantidad * precioUnitario;

  Map<String, dynamic> toMap(String ventaId, {String? ventaUuidParam}) {
    return {
      'id': id,
      'uuid': uuid,
      'venta_id': ventaId,
      'venta_uuid': ventaUuidParam ?? ventaUuid,
      'producto_id': producto.id,
      'producto_uuid': productoUuid ?? producto.uuid,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
      'created_at': createdAt,
      'updated_at': updatedAt ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': deletedAt,
      'sync_estado': syncEstado,
      'dispositivo_id': dispositivoId,
    };
  }

  factory ArticuloVenta.fromMap(Map<String, dynamic> map, Producto producto) {
    final rawUuid = map['uuid']?.toString() ?? const Uuid().v4();
    return ArticuloVenta(
      id: map['id']?.toString() ?? rawUuid,
      uuid: rawUuid,
      ventaUuid: map['venta_uuid']?.toString(),
      productoUuid: map['producto_uuid']?.toString() ?? producto.uuid,
      producto: producto,
      cantidad: (map['cantidad'] as num).toInt(),
      precioUnitario: (map['precioUnitario'] as num).toDouble(),
      createdAt: map['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      updatedAt: map['updated_at']?.toString(),
      deletedAt: map['deleted_at']?.toString(),
      syncEstado: map['sync_estado']?.toString() ?? 'pendiente',
      dispositivoId: map['dispositivo_id']?.toString(),
    );
  }
}

class Venta {
  String id;
  String uuid;
  String? colaboradorUuid;
  DateTime fecha;
  EstadoVenta estado;
  List<ArticuloVenta> articulos;
  double porcentajeIva;
  bool aplicarIva;
  String cliente;
  double montoPagado;
  String notas;
  String createdAt;
  String? updatedAt;
  String? deletedAt;
  String syncEstado;
  String? dispositivoId;

  Venta({
    String? id,
    String? uuid,
    String? colaboradorUuid,
    required DateTime fecha,
    EstadoVenta estado = EstadoVenta.enProceso,
    List<ArticuloVenta>? articulos,
    double porcentajeIva = 0.16,
    bool aplicarIva = true,
    String cliente = 'Cliente Mostrador',
    double montoPagado = 0.0,
    String notas = '',
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
    String syncEstado = 'pendiente',
    String? dispositivoId,
  }) : this._(
          id: id ?? uuid ?? const Uuid().v4(),
          uuid: uuid ?? id,
          colaboradorUuid: colaboradorUuid,
          fecha: fecha,
          estado: estado,
          articulos: articulos,
          porcentajeIva: porcentajeIva,
          aplicarIva: aplicarIva,
          cliente: cliente,
          montoPagado: montoPagado,
          notas: notas,
          createdAt: createdAt,
          updatedAt: updatedAt,
          deletedAt: deletedAt,
          syncEstado: syncEstado,
          dispositivoId: dispositivoId,
        );

  Venta._({
    required this.id,
    String? uuid,
    this.colaboradorUuid,
    required this.fecha,
    this.estado = EstadoVenta.enProceso,
    List<ArticuloVenta>? articulos,
    this.porcentajeIva = 0.16,
    this.aplicarIva = true,
    this.cliente = 'Cliente Mostrador',
    this.montoPagado = 0.0,
    this.notas = '',
    String? createdAt,
    this.updatedAt,
    this.deletedAt,
    this.syncEstado = 'pendiente',
    this.dispositivoId,
  })  : uuid = uuid ?? id,
        createdAt = createdAt ?? DateTime.now().toUtc().toIso8601String(),
        articulos = articulos ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'colaborador_uuid': colaboradorUuid,
      'fecha': fecha.toIso8601String(),
      'estado': estado.name,
      'porcentajeIva': porcentajeIva,
      'aplicarIva': aplicarIva ? 1 : 0,
      'cliente': cliente,
      'montoPagado': montoPagado,
      'notas': notas,
      'created_at': createdAt,
      'updated_at': updatedAt ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': deletedAt,
      'sync_estado': syncEstado,
      'dispositivo_id': dispositivoId,
    };
  }

  factory Venta.fromMap(
    Map<String, dynamic> map,
    List<ArticuloVenta> articulosCargados,
  ) {
    final estadoRaw = map['estado']?.toString().toLowerCase().trim() ?? '';
    final rawUuid = map['uuid']?.toString() ?? const Uuid().v4();
    final fechaParsed = map['fecha'] != null
        ? DateTime.tryParse(map['fecha'].toString()) ?? DateTime.now()
        : DateTime.now();
    return Venta(
      id: map['id']?.toString() ?? rawUuid,
      uuid: rawUuid,
      colaboradorUuid: map['colaborador_uuid']?.toString(),
      fecha: fechaParsed,
      estado: EstadoVenta.values.firstWhere(
        (e) => e.name.toLowerCase() == estadoRaw,
        orElse: () => EstadoVenta.enProceso,
      ),
      porcentajeIva: (map['porcentajeIva'] as num?)?.toDouble() ?? 0.16,
      aplicarIva: map['aplicarIva'] != null ? map['aplicarIva'] == 1 : true,
      cliente: map['cliente']?.toString() ?? 'Cliente Mostrador',
      montoPagado: (map['montoPagado'] as num?)?.toDouble() ?? 0.0,
      notas: map['notas']?.toString() ?? '',
      createdAt: map['created_at']?.toString() ?? fechaParsed.toIso8601String(),
      updatedAt: map['updated_at']?.toString(),
      deletedAt: map['deleted_at']?.toString(),
      syncEstado: map['sync_estado']?.toString() ?? 'pendiente',
      dispositivoId: map['dispositivo_id']?.toString(),
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

  double get subtotal => subtotalVenta;

  double get totalIva => aplicarIva ? (subtotalVenta * porcentajeIva) : 0.0;

  double get montoIva => totalIva;

  double get total => subtotalVenta + totalIva;

  /// Saldo pendiente por liquidar en ventas apartadas / cuentas por cobrar
  double get saldoPendiente => (total - montoPagado).clamp(0.0, double.infinity);

  /// Determina si la venta mantiene un saldo adeudado
  bool get tieneSaldoPendiente => saldoPendiente > 0.001;

  /// Indica si la venta corresponde a un apartado o cuenta por cobrar
  bool get esApartada =>
      estado == EstadoVenta.apartada || estado == EstadoVenta.liquidada;

  /// Determina si la cuenta está completamente liquidada (saldo restante $0.00)
  bool get esLiquidada =>
      estado == EstadoVenta.liquidada || (!tieneSaldoPendiente && esApartada);

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
