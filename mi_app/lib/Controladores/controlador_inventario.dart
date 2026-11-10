import 'dart:async';
import 'package:flutter/foundation.dart';

import '../Modelos/producto.dart';
import '../BaseDatos/base_datos.dart';

/// Controlador reactivo de inventario para Planteapp.
///
/// Gestiona el catálogo de plantas y artículos botánicos, notificando a todos
/// los observadores (`ChangeNotifier`) ante cualquier alta, baja o ajuste de existencias.
class ControladorInventario extends ChangeNotifier {
  List<Producto> _productos = [];
  bool _filtroSoloActivos = true;
  bool _modoPruebas = false;

  List<Producto> get productos => _productos;

  /// Inyecta productos en memoria exclusivamente para pruebas unitarias y de widgets,
  /// evitando operaciones asíncronas sobre SQLite y bloqueos de temporizadores.
  @visibleForTesting
  void establecerProductosParaPruebas(List<Producto> nuevos) {
    _modoPruebas = true;
    _productos = List.of(nuevos);
    notifyListeners();
  }

  /// Indica si el catálogo actualmente cargado corresponde a productos activos (`true`)
  /// o a productos ocultos / deshabilitados (`false`).
  bool get filtroSoloActivos => _filtroSoloActivos;

  /// Recarga el inventario de productos desde SQLite con soporte de filtro de estado,
  /// paginación y auto-recuperación de esquema.
  ///
  /// Parámetros:
  /// - [soloActivos]: `true` por defecto para mostrar únicamente productos operativos (`activo = 1`).
  ///   Si se especifica `false`, consulta y carga exclusivamente los productos deshabilitados (`activo = 0`),
  ///   permitiendo al dueño auditar artículos ocultos para restaurarlos o eliminarlos definitivamente.
  /// - [limite] y [offset]: Soporte opcional de paginación de registros.
  Future<void> cargarProductos({
    bool soloActivos = true,
    int? limite,
    int offset = 0,
  }) async {
    _filtroSoloActivos = soloActivos;
    if (_modoPruebas) return;
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
      where: 'activo = ?',
      whereArgs: [soloActivos ? 1 : 0],
      orderBy: 'nombre ASC',
      limit: limite,
      offset: offset > 0 ? offset : null,
    );
    _productos = mapas.map((mapa) => Producto.fromMap(mapa)).toList();
    notifyListeners();
  }

  /// Alias de compatibilidad semántica para recargar el inventario
  Future<void> cargarInventario() async {
    await cargarProductos();
  }

  /// Agrega un nuevo producto desacoplando la persistencia pesada en SQLite
  /// de la animación visual del hilo principal (UI Thread).
  ///
  /// Primero actualiza el estado visual mínimo necesario en memoria y notifica
  /// a la UI para renderizado inmediato a 60/120 FPS sin frame drops.
  /// Luego delega la escritura real en SQLite mediante una microtarea (`Future.microtask()`).
  Future<void> agregarProducto(Producto nuevoProducto) async {
    if (_productos.any((p) => p.id == nuevoProducto.id)) {
      throw Exception('El producto con este ID ya existe.');
    }

    // 1. Actualización inmediata del estado visual en memoria (Optimistic UI)
    _productos.add(nuevoProducto);
    notifyListeners();

    // 2. Microtareas: delega la inserción real en SQLite usando Future.microtask()
    // para que se ejecute después de que el frame de la animación visual haya terminado de pintarse.
    final completer = Completer<void>();
    Future.microtask(() async {
      try {
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
        completer.complete();
      } catch (e) {
        // En caso de fallo transaccional en SQLite, revertir el estado en memoria
        _productos.removeWhere((p) => p.id == nuevoProducto.id);
        notifyListeners();
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  /// Deshabilita un producto (Soft Delete) ejecutando `UPDATE productos SET activo = 0 WHERE id = ?`.
  ///
  /// Disponible para ambos roles ('empleado' y 'dueño').
  /// Permite ocultar un producto registrado por equivocación sin romper la integridad referencial
  /// en SQLite ni causar errores `FOREIGN KEY constraint failed (code 787)` con ventas históricas.
  Future<void> deshabilitarProducto(dynamic id) async {
    final db = await BaseDeDatos.instancia.database;
    final idParam = id.toString();
    await db.update(
      'productos',
      {'activo': 0},
      where: 'id = ?',
      whereArgs: [idParam],
    );

    // Actualización reactiva en memoria
    final prod = _productos.where((p) => p.id == idParam).firstOrNull;
    if (prod != null) {
      prod.activo = false;
      // Si la vista actual muestra solo productos activos, retirarlo de la lista visible
      if (_filtroSoloActivos) {
        _productos.removeWhere((p) => p.id == idParam);
      }
    }
    notifyListeners();
  }

  /// Restaura un producto deshabilitado ejecutando `UPDATE productos SET activo = 1 WHERE id = ?`.
  ///
  /// Acción reservada para el rol 'dueño'.
  /// Reactiva el producto para que vuelva a estar disponible en el Punto de Venta (POS) y catálogo.
  Future<void> restaurarProducto(dynamic id) async {
    final db = await BaseDeDatos.instancia.database;
    final idParam = id.toString();
    await db.update(
      'productos',
      {'activo': 1},
      where: 'id = ?',
      whereArgs: [idParam],
    );

    // Actualización reactiva en memoria
    final prod = _productos.where((p) => p.id == idParam).firstOrNull;
    if (prod != null) {
      prod.activo = true;
      // Si la vista actual muestra solo deshabilitados, retirarlo de la lista de ocultos
      if (!_filtroSoloActivos) {
        _productos.removeWhere((p) => p.id == idParam);
      }
    } else if (_filtroSoloActivos) {
      // Si estamos en la vista de activos y el producto no estaba en memoria, recargar
      await cargarProductos(soloActivos: true);
      return;
    }
    notifyListeners();
  }

  /// Elimina definitivamente un producto (Hard Delete) ejecutando `DELETE FROM productos WHERE id = ?`.
  ///
  /// Acción irreversible reservada exclusivamente para el rol 'dueño'.
  /// Si el producto no cuenta con ventas registradas, se elimina físicamente de la base de datos.
  /// En caso de poseer registros vinculados en `articulos_venta`, previene el fallo de clave foránea
  /// notificando la restricción de integridad referencial.
  Future<void> eliminarProductoDefinitivamente(dynamic id) async {
    final db = await BaseDeDatos.instancia.database;
    final idParam = id.toString();
    try {
      await db.delete(
        'productos',
        where: 'id = ?',
        whereArgs: [idParam],
      );
      _productos.removeWhere((p) => p.id == idParam);
      notifyListeners();
    } catch (e) {
      if (e.toString().contains('FOREIGN KEY')) {
        throw Exception(
          'No es posible eliminar definitivamente el producto porque posee registros de venta históricos. Consérvelo deshabilitado.',
        );
      }
      rethrow;
    }
  }

  /// Alias de retrocompatibilidad con llamadas preexistentes que ejecutan el borrado lógico (Soft Delete).
  Future<void> eliminarProducto(String id) async {
    await deshabilitarProducto(id);
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

  /// Búsqueda ultrarrápida mediante el motor de indexación FTS5 (Full-Text Search) de SQLite.
  /// Sustituye el escaneo secuencial O(N) con operador LIKE por una consulta indexada O(1)
  /// mediante sintaxis MATCH con prefijos 'token*' y ordenamiento alfabético.
  Future<List<Producto>> buscarProductosAsync(
    String consulta, {
    int limite = 100,
  }) async {
    final termino = consulta.trim();
    if (termino.isEmpty) {
      return _productos;
    }

    final db = await BaseDeDatos.instancia.database;

    // Sanitizar y extraer palabras/tokens para sintaxis FTS5 segura
    final tokens = termino
        .replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]', unicode: true), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      return _productos;
    }

    // Sintaxis FTS5: 'token1* token2*' (conjunción AND con coincidencia por prefijo)
    final ftsQuery = tokens.map((t) => '$t*').join(' ');

    try {
      final res = await db.rawQuery('''
        SELECT p.*
        FROM productos p
        JOIN productos_fts f ON p.rowid = f.rowid
        WHERE p.activo = 1 AND productos_fts MATCH ?
        ORDER BY p.nombre ASC
        LIMIT ?
      ''', [ftsQuery, limite]);

      return res.map((mapa) => Producto.fromMap(mapa)).toList();
    } catch (e) {
      // Fallback defensivo: Si FTS5 no está disponible temporalmente o la migración está pendiente
      final filtro = '%$termino%';
      final mapas = await db.query(
        'productos',
        where: 'activo = 1 AND (nombre LIKE ? OR notas LIKE ? OR tipo LIKE ?)',
        whereArgs: [filtro, filtro, filtro],
        orderBy: 'nombre ASC',
        limit: limite,
      );
      return mapas.map((mapa) => Producto.fromMap(mapa)).toList();
    }
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
