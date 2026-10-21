class Producto {
  String id;
  String nombre;
  String notas;
  double precioVenta;
  double costo;
  int cantidadEnInventario;
  int umbralStockCritico;
  List<String> imagenes;

  Producto({
    required this.id,
    required this.nombre,
    this.notas = '',
    required this.precioVenta,
    required this.costo,
    this.cantidadEnInventario = 0,
    this.umbralStockCritico = 5,
    List<String>? imagenes,
  }) : imagenes = imagenes ?? [];

  bool get esStockCritico => cantidadEnInventario <= umbralStockCritico;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'notas': notas,
      'precioVenta': precioVenta,
      'costo': costo,
      'cantidadEnInventario': cantidadEnInventario,
      'umbralStockCritico': umbralStockCritico,
      'imagenes': imagenes.join(','),
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'],
      nombre: map['nombre'],
      notas: map['notas'] ?? '',
      precioVenta: map['precioVenta'],
      costo: map['costo'],
      cantidadEnInventario: map['cantidadEnInventario'],
      umbralStockCritico: map['umbralStockCritico'] ?? 5,
      imagenes: map['imagenes'] != null && map['imagenes'].toString().isNotEmpty
          ? map['imagenes'].toString().split(',')
          : [],
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
        notas.toLowerCase().contains(consultaMinuscula);
  }
}
