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
      tipo: (map['tipo']?.toString().toLowerCase() == 'articulo')
          ? 'articulo'
          : 'planta',
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
        notas.toLowerCase().contains(consultaMinuscula) ||
        tipo.toLowerCase().contains(consultaMinuscula);
  }
}
