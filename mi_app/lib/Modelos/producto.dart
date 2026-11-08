class Producto {
  String id;
  String nombre;
  String notas;
  double precioVenta;
  double costo;
  int cantidadEnInventario;
  int umbralStockCritico;
  String tipo; // 'planta' o 'articulo'
  List<String> imagenes;
  bool activo;

  Producto({
    required this.id,
    required this.nombre,
    this.notas = '',
    required this.precioVenta,
    required this.costo,
    this.cantidadEnInventario = 0,
    this.umbralStockCritico = 5,
    this.tipo = 'planta',
    List<String>? imagenes,
    this.activo = true,
  }) : imagenes = imagenes ?? [];

  bool get esStockCritico => cantidadEnInventario <= umbralStockCritico;
  bool get esPlanta => tipo.toLowerCase() == 'planta';
  bool get esArticulo => tipo.toLowerCase() == 'articulo';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'notas': notas,
      'precioVenta': precioVenta,
      'costo': costo,
      'cantidadEnInventario': cantidadEnInventario,
      'umbralStockCritico': umbralStockCritico,
      'tipo': tipo,
      'imagenes': imagenes.join(','),
      'activo': activo ? 1 : 0,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'],
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
    );
  }

  Producto copyWith({
    String? id,
    String? nombre,
    String? notas,
    double? precioVenta,
    double? costo,
    int? cantidadEnInventario,
    int? umbralStockCritico,
    String? tipo,
    List<String>? imagenes,
    bool? activo,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      notas: notas ?? this.notas,
      precioVenta: precioVenta ?? this.precioVenta,
      costo: costo ?? this.costo,
      cantidadEnInventario: cantidadEnInventario ?? this.cantidadEnInventario,
      umbralStockCritico: umbralStockCritico ?? this.umbralStockCritico,
      tipo: tipo ?? this.tipo,
      imagenes: imagenes ?? List.from(this.imagenes),
      activo: activo ?? this.activo,
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
}
