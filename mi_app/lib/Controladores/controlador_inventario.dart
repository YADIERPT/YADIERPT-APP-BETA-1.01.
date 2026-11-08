import 'package:flutter/foundation.dart';

import '../Modelos/producto.dart';
import '../BaseDatos/base_datos.dart';

/// Controlador reactivo de inventario para Planteapp.
///
/// Gestiona el catálogo de plantas y artículos botánicos, notificando a todos
/// los observadores (`ChangeNotifier`) ante cualquier alta, baja o ajuste de existencias.
class ControladorInventario extends ChangeNotifier {
  List<Producto> _productos = [];

  List<Producto> get productos => _productos;

  /// Recarga el inventario completo de productos activos desde SQLite y notifica a los escuchas reactivos.
  /// Aplica borrado lógico (`activo = 1`) y auto-recuperación de esquema para bases de datos previas.
  Future<void> cargarProductos() async {
    final db = await BaseDeDatos.instancia.database;
    try {
      await db.execute(
        'ALTER TABLE productos ADD COLUMN activo INTEGER NOT NULL DEFAULT 1',
      );
    } catch (_) {
      // La columna ya existe o ya fue migrada
    }
    final mapas = await db.query(
      'productos',
      where: 'activo = 1',
    );
    _productos = mapas.map((mapa) => Producto.fromMap(mapa)).toList();
    notifyListeners();
  }

  /// Alias de compatibilidad semántica para recargar el inventario
  Future<void> cargarInventario() async {
    await cargarProductos();
  }

  Future<void> agregarProducto(Producto nuevoProducto) async {
    if (_productos.any((p) => p.id == nuevoProducto.id)) {
      throw Exception('El producto con este ID ya existe.');
    }

    final db = await BaseDeDatos.instancia.database;

    // Verificar si el registro ya existe en SQLite (ej. borrado lógicamente con anterioridad)
    final coincidentes = await db.query(
      'productos',
      where: 'id = ?',
      whereArgs: [nuevoProducto.id],
    );

    if (coincidentes.isNotEmpty) {
      // Reactivar el producto existente y actualizar sus datos
      nuevoProducto.activo = true;
      await db.update(
        'productos',
        nuevoProducto.toMap(),
        where: 'id = ?',
        whereArgs: [nuevoProducto.id],
      );
    } else {
      await db.insert('productos', nuevoProducto.toMap());
    }

    _productos.add(nuevoProducto);
    notifyListeners();
  }

  /// Realiza un borrado lógico (Soft Delete) del producto actualizando `activo = 0`.
  /// Esto previene el error `FOREIGN KEY constraint failed (code 787)` al preservar
  /// la integridad referencial con `articulos_venta` y mantener intacto el historial de ventas.
  Future<void> eliminarProducto(String id) async {
    final db = await BaseDeDatos.instancia.database;
    await db.update(
      'productos',
      {'activo': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _productos.removeWhere((p) => p.id == id);
    notifyListeners();
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

  Future<void> actualizarProductoCompleto(Producto productoActualizado) async {
    final index = _productos.indexWhere((p) => p.id == productoActualizado.id);
    if (index != -1) {
      _productos[index] = productoActualizado;
      await _actualizarProducto(productoActualizado);
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
    notifyListeners();
  }

  List<Producto> buscarProductos(String consulta) {
    if (consulta.isEmpty) return _productos;
    return _productos.where((p) => p.coincideConBusqueda(consulta)).toList();
  }

  Producto? obtenerProducto(String id) {
    return _productos.where((p) => p.id == id).firstOrNull;
  }

  /// Obtiene un producto por ID desde SQLite incluyendo aquellos desactivados (`activo = 0`).
  /// Esencial para renderizar con total exactitud detalles de ventas históricas y recibos.
  Future<Producto?> obtenerProductoHistoricoAsync(String id) async {
    final enMemoria = obtenerProducto(id);
    if (enMemoria != null) return enMemoria;

    final db = await BaseDeDatos.instancia.database;
    final int? idInt = int.tryParse(id);
    final res = await db.query(
      'productos',
      where: idInt != null ? 'id = ? OR id = ?' : 'id = ?',
      whereArgs: idInt != null ? [id, idInt] : [id],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return Producto.fromMap(res.first);
    }
    return null;
  }
}
