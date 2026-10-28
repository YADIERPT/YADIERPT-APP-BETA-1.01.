import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../BaseDatos/base_datos.dart';
import '../../Controladores/controlador_inventario.dart';
import '../../Modelos/venta.dart';
import '../Modelos/calibracion_producto.dart';
import '../Modelos/recomendacion_compra.dart';
import '../Motores/motor_ia_recomendacion.dart';

class ControladorIACompras extends ChangeNotifier {
  final ControladorInventario controladorInventario;

  List<RecomendacionCompra> _recomendaciones = [];
  Map<String, CalibracionProducto> _calibraciones = {};
  int _horizonteReposicionDias = 14; // Default para viveros
  bool _cargando = false;
  DateTime? _ultimaCalibracion;

  ControladorIACompras({
    required this.controladorInventario,
  });

  List<RecomendacionCompra> get recomendaciones => _recomendaciones;
  Map<String, CalibracionProducto> get calibraciones => _calibraciones;
  int get horizonteReposicionDias => _horizonteReposicionDias;
  bool get cargando => _cargando;
  DateTime? get ultimaCalibracion => _ultimaCalibracion;

  List<RecomendacionCompra> get recomendacionesActivas => _recomendaciones
      .where((r) => r.estado == EstadoRecomendacion.pendiente)
      .toList();

  int get totalComprasRecomendadas =>
      recomendacionesActivas.where((r) => r.sugiereCompra).length;

  int get totalCriticos => recomendacionesActivas
      .where((r) => r.nivelUrgencia == NivelUrgencia.critico && r.sugiereCompra)
      .length;

  int get totalPlantasRecomendadas => recomendacionesActivas
      .where((r) => r.esPlanta && r.sugiereCompra)
      .length;

  int get totalArticulosRecomendados => recomendacionesActivas
      .where((r) => !r.esPlanta && r.sugiereCompra)
      .length;

  double get inversionTotalEstimada => recomendacionesActivas.fold(
        0.0,
        (sum, r) => sum + r.costoTotalEstimado,
      );

  double get gananciaProyectadaTotal => recomendacionesActivas.fold(
        0.0,
        (sum, r) => sum + r.gananciaEstimada,
      );

  RecomendacionCompra? get recomendacionDestacada {
    final activas = recomendacionesActivas;
    if (activas.isEmpty) return null;
    final urgenteConCompra = activas.where((r) => r.sugiereCompra).toList();
    if (urgenteConCompra.isNotEmpty) {
      return urgenteConCompra.first;
    }
    return activas.first;
  }

  Future<void> inicializar(List<Venta> ventas) async {
    _cargando = true;
    notifyListeners();

    try {
      final db = await BaseDeDatos.instancia.database;

      // Cargar calibraciones previas
      final mapasCalibraciones = await db.query('ia_calibracion_productos');
      _calibraciones.clear();
      for (var map in mapasCalibraciones) {
        final c = CalibracionProducto.fromMap(map);
        _calibraciones[c.productoId] = c;
      }

      // Cargar recomendaciones previas
      final mapasSugerencias = await db.query(
        'ia_sugerencias_compra',
        orderBy: 'fecha_generacion DESC',
      );

      _recomendaciones.clear();
      for (var map in mapasSugerencias) {
        final pId = map['producto_id'] as String;
        final producto = controladorInventario.obtenerProducto(pId);
        if (producto != null) {
          final cal = _calibraciones[pId];
          _recomendaciones.add(
            RecomendacionCompra.fromDbMap(
              map: map,
              nombreProducto: producto.nombre,
              tipo: producto.tipo,
              stockActual: producto.cantidadEnInventario,
              umbralStockCritico: producto.umbralStockCritico,
              costoUnitario: producto.costo,
              precioVenta: producto.precioVenta,
              velocidadDiaria: cal?.velocidadDiaria ?? 0.0,
            ),
          );
        }
      }

      // Si no hay datos guardados o están vacíos, correr análisis completo
      if (_recomendaciones.isEmpty || _calibraciones.isEmpty) {
        await ejecutarCalibracionCompleta(ventas, guardarEnBd: true);
      } else {
        _ultimaCalibracion = _calibraciones.values.isNotEmpty
            ? _calibraciones.values.first.ultimaCalibracion
            : DateTime.now();
      }
    } catch (e) {
      debugPrint('Error al inicializar ControladorIACompras: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Ejecuta el análisis de IA y actualiza las calibraciones con el historial de ventas
  Future<void> ejecutarCalibracionCompleta(
    List<Venta> ventas, {
    int? horizonteDias,
    bool guardarEnBd = true,
  }) async {
    _cargando = true;
    notifyListeners();

    if (horizonteDias != null) {
      _horizonteReposicionDias = horizonteDias;
    }

    try {
      final resultado = MotorIARecomendacion.ejecutarAnalisis(
        productos: controladorInventario.productos,
        ventas: ventas,
        horizonteReposicionDias: _horizonteReposicionDias,
      );

      _calibraciones = resultado.calibraciones;
      _recomendaciones = resultado.recomendaciones;
      _ultimaCalibracion = DateTime.now();

      if (guardarEnBd) {
        await _guardarEnBaseDeDatos();
      }
    } catch (e) {
      debugPrint('Error en ejecutarCalibracionCompleta: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Calibración en tiempo real cuando se efectúa una venta en el POS
  Future<void> recalibrarPorVenta({
    required Venta venta,
    required List<Venta> todasLasVentas,
  }) async {
    // Al registrar una venta, los productos afectados aumentan su velocidad de salida
    await ejecutarCalibracionCompleta(
      todasLasVentas,
      horizonteDias: _horizonteReposicionDias,
      guardarEnBd: true,
    );
  }

  Future<void> cambiarHorizonteReposicion(
    int nuevosDias,
    List<Venta> ventas,
  ) async {
    _horizonteReposicionDias = nuevosDias;
    await ejecutarCalibracionCompleta(
      ventas,
      horizonteDias: nuevosDias,
      guardarEnBd: true,
    );
  }

  Future<void> descartarRecomendacion(String id) async {
    final idx = _recomendaciones.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _recomendaciones[idx] = _recomendaciones[idx].copyWith(
        estado: EstadoRecomendacion.descartada,
      );
      notifyListeners();

      try {
        final db = await BaseDeDatos.instancia.database;
        await db.update(
          'ia_sugerencias_compra',
          {'estado': 'DESCARTADA'},
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (e) {
        debugPrint('Error al descartar recomendación en BD: $e');
      }
    }
  }

  Future<void> marcarComoAplicada(String id) async {
    final idx = _recomendaciones.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _recomendaciones[idx] = _recomendaciones[idx].copyWith(
        estado: EstadoRecomendacion.aplicada,
      );
      notifyListeners();

      try {
        final db = await BaseDeDatos.instancia.database;
        await db.update(
          'ia_sugerencias_compra',
          {'estado': 'APLICADA'},
          where: 'id = ?',
          whereArgs: [id],
        );
      } catch (e) {
        debugPrint('Error al marcar aplicada en BD: $e');
      }
    }
  }

  Future<void> _guardarEnBaseDeDatos() async {
    final db = await BaseDeDatos.instancia.database;

    await db.transaction((txn) async {
      // Guardar calibraciones
      for (var cal in _calibraciones.values) {
        await txn.insert(
          'ia_calibracion_productos',
          cal.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Mantener recomendaciones pendientes actualizadas
      await txn.delete('ia_sugerencias_compra');
      for (var rec in _recomendaciones) {
        await txn.insert(
          'ia_sugerencias_compra',
          rec.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
