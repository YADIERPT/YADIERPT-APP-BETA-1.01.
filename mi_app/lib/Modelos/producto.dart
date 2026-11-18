import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class Producto {
  String id;
  String uuid;
  String nombre;
  String notas;
  double precioVenta;
  double costo;
  int cantidadEnInventario;
  int umbralStockCritico;
  String tipo; // 'planta' o 'articulo'
  List<String> imagenes;
  bool activo;
  bool isSynced;
  String? updatedAt;
  String? deletedAt;
  String syncEstado;
  String? dispositivoId;

  Producto({
    required this.id,
    String? uuid,
    required this.nombre,
    this.notas = '',
    required this.precioVenta,
    required this.costo,
    this.cantidadEnInventario = 0,
    this.umbralStockCritico = 5,
    this.tipo = 'planta',
    List<String>? imagenes,
    this.activo = true,
    this.isSynced = false,
    this.updatedAt,
    this.deletedAt,
    this.syncEstado = 'pendiente',
    this.dispositivoId,
  })  : uuid = (uuid != null && uuid.isNotEmpty) ? uuid : const Uuid().v4(),
        imagenes = imagenes ?? [];

  bool get esStockCritico => cantidadEnInventario <= umbralStockCritico;
  bool get esPlanta => tipo.toLowerCase() == 'planta';
  bool get esArticulo => tipo.toLowerCase() == 'articulo';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'nombre': nombre,
      'notas': notas,
      'precioVenta': precioVenta,
      'costo': costo,
      'cantidadEnInventario': cantidadEnInventario,
      'umbralStockCritico': umbralStockCritico,
      'tipo': tipo,
      'imagenes': imagenes.join(','),
      'activo': activo ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'updated_at': updatedAt ?? DateTime.now().toUtc().toIso8601String(),
      'deleted_at': deletedAt,
      'sync_estado': syncEstado,
      'dispositivo_id': dispositivoId,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'],
      uuid: map['uuid']?.toString(),
      nombre: map['nombre'],
      notas: map['notas'] ?? '',
      precioVenta: (map['precioVenta'] as num).toDouble(),
      costo: (map['costo'] as num).toDouble(),
      cantidadEnInventario: (map['cantidadEnInventario'] as num).toInt(),
      umbralStockCritico: (map['umbralStockCritico'] as num?)?.toInt() ?? 5,
      tipo: (map['tipo']?.toString().toLowerCase() == 'articulo')
          ? 'articulo'
          : 'planta',
      imagenes: map['imagenes'] != null && map['imagenes'].toString().isNotEmpty
          ? map['imagenes'].toString().split(',')
          : [],
      activo: map['activo'] == null
          ? true
          : (map['activo'] == 1 || map['activo'] == true),
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
      updatedAt: map['updated_at']?.toString(),
      deletedAt: map['deleted_at']?.toString(),
      syncEstado: map['sync_estado']?.toString() ?? 'pendiente',
      dispositivoId: map['dispositivo_id']?.toString(),
    );
  }

  Producto copyWith({
    String? id,
    String? uuid,
    String? nombre,
    String? notas,
    double? precioVenta,
    double? costo,
    int? cantidadEnInventario,
    int? umbralStockCritico,
    String? tipo,
    List<String>? imagenes,
    bool? activo,
    bool? isSynced,
    String? updatedAt,
    String? deletedAt,
    String? syncEstado,
    String? dispositivoId,
  }) {
    return Producto(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      nombre: nombre ?? this.nombre,
      notas: notas ?? this.notas,
      precioVenta: precioVenta ?? this.precioVenta,
      costo: costo ?? this.costo,
      cantidadEnInventario: cantidadEnInventario ?? this.cantidadEnInventario,
      umbralStockCritico: umbralStockCritico ?? this.umbralStockCritico,
      tipo: tipo ?? this.tipo,
      imagenes: imagenes ?? List.from(this.imagenes),
      activo: activo ?? this.activo,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncEstado: syncEstado ?? this.syncEstado,
      dispositivoId: dispositivoId ?? this.dispositivoId,
    );
  }
  void reducirInventario(int cantidad) {
    if (cantidad <= cantidadEnInventario) {
      cantidadEnInventario -= cantidad;
    } else {
      throw Exception(
        'Cantidad insuficiente en inventario para mermar/vender.',
      );
    }
  }

  void agregarInventario(int cantidad) {
    cantidadEnInventario += cantidad;
  }

  void agregarImagen(String rutaImagen) {
    imagenes.add(rutaImagen);
  }

  bool coincideConBusqueda(String consulta) {
    final consultaMinuscula = consulta.toLowerCase();
    return nombre.toLowerCase().contains(consultaMinuscula) ||
        notas.toLowerCase().contains(consultaMinuscula) ||
        tipo.toLowerCase().contains(consultaMinuscula);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Producto &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nombre == other.nombre &&
          notas == other.notas &&
          precioVenta == other.precioVenta &&
          costo == other.costo &&
          cantidadEnInventario == other.cantidadEnInventario &&
          umbralStockCritico == other.umbralStockCritico &&
          tipo == other.tipo &&
          activo == other.activo &&
          listEquals(imagenes, other.imagenes);

  @override
  int get hashCode => Object.hash(
        id,
        nombre,
        notas,
        precioVenta,
        costo,
        cantidadEnInventario,
        umbralStockCritico,
        tipo,
        activo,
        Object.hashAll(imagenes),
      );
}
