import '../Modelos/producto.dart';
import '../BaseDatos/base_datos.dart';

class ControladorInventario {
  List<Producto> _productos = [];

  List<Producto> get productos => _productos;

  Future<void> cargarProductos() async {
    final db = await BaseDeDatos.instancia.database;
    final mapas = await db.query('productos');
    _productos = mapas.map((mapa) => Producto.fromMap(mapa)).toList();
  }

  Future<void> agregarProducto(Producto nuevoProducto) async {
    if (_productos.any((p) => p.id == nuevoProducto.id)) {
      throw Exception('El producto con este ID ya existe.');
    }

    final db = await BaseDeDatos.instancia.database;
    await db.insert('productos', nuevoProducto.toMap());
    _productos.add(nuevoProducto);
  }

  Future<void> eliminarProducto(String id) async {
    final db = await BaseDeDatos.instancia.database;
    await db.delete('productos', where: 'id = ?', whereArgs: [id]);
    _productos.removeWhere((p) => p.id == id);
  }

  Future<void> registrarMerma(String productoId, int cantidad) async {
    final producto = obtenerProducto(productoId);
    if (producto != null) {
      producto.reducirInventario(cantidad);
      await _actualizarProducto(producto);
    } else {
      throw Exception('Producto no encontrado');
    }
  }

  Future<void> descontarInventarioPorVenta(
    String productoId,
    int cantidad,
  ) async {
    final producto = obtenerProducto(productoId);
    if (producto != null) {
      producto.reducirInventario(cantidad);
      await _actualizarProducto(producto);
    }
  }

  Future<void> adjuntarImagenAProducto(
    String productoId,
    String rutaImagen,
  ) async {
    final producto = obtenerProducto(productoId);
    if (producto != null) {
      producto.agregarImagen(rutaImagen);
      await _actualizarProducto(producto);
    } else {
      throw Exception('Producto no encontrado');
    }
  }

  Future<void> actualizarNombreProducto(
    String productoId,
    String nuevoNombre,
  ) async {
    final producto = obtenerProducto(productoId);
    if (producto != null) {
      producto.nombre = nuevoNombre;
      await _actualizarProducto(producto);
    } else {
      throw Exception('Producto no encontrado');
    }
  }

  Future<void> actualizarNotasProducto(
    String productoId,
    String nuevasNotas,
  ) async {
    final producto = obtenerProducto(productoId);
    if (producto != null) {
      producto.notas = nuevasNotas;
      await _actualizarProducto(producto);
    } else {
      throw Exception('Producto no encontrado');
    }
  }

  Future<void> actualizarExistenciasYUmbral(
    String productoId,
    int nuevaCantidad,
    int nuevoUmbral,
  ) async {
    final producto = obtenerProducto(productoId);
    if (producto != null) {
      producto.cantidadEnInventario = nuevaCantidad;
      producto.umbralStockCritico = nuevoUmbral;
      await _actualizarProducto(producto);
    } else {
      throw Exception('Producto no encontrado');
    }
  }

  Future<void> _actualizarProducto(Producto producto) async {
    final db = await BaseDeDatos.instancia.database;
    await db.update(
      'productos',
      producto.toMap(),
      where: 'id = ?',
      whereArgs: [producto.id],
    );
  }

  List<Producto> buscarProductos(String consulta) {
    if (consulta.isEmpty) return _productos;
    return _productos.where((p) => p.coincideConBusqueda(consulta)).toList();
  }

  Producto? obtenerProducto(String id) {
    try {
      return _productos.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}
