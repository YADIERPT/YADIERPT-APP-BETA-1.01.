import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../Modelos/finanzas.dart';
import '../BaseDatos/base_datos.dart';

/// Controlador reactivo de Finanzas y Balance Contable.
///
/// Extiende [ChangeNotifier] para proveer actualizaciones reactivas a la UI
/// cuando se asientan ventas de contado, ingresos extraordinarios, egresos o mermas.
class ControladorFinanzas extends ChangeNotifier {
  List<TransaccionFinanciera> _transacciones = [];
  bool _cargando = false;

  List<TransaccionFinanciera> get transacciones => List.unmodifiable(_transacciones);
  bool get cargando => _cargando;

  // Propiedades reactivas derivadas memoizadas/calculadas
  double get totalIngresos =>
      _transacciones.where((t) => t.esIngreso).fold(0.0, (acc, t) => acc + t.monto);

  double get totalEgresos =>
      _transacciones.where((t) => t.esEgreso).fold(0.0, (acc, t) => acc + t.monto);

  double get totalMermas =>
      _transacciones.where((t) => t.tipo == TipoTransaccion.merma).fold(0.0, (acc, t) => acc + t.monto);

  double get balanceTotal => totalIngresos - totalEgresos;

  RendimientoFinanciero get rendimientoGlobal => calcularRendimientoGlobal();

  /// Recarga el historial de transacciones desde SQLite y notifica a los suscriptores
  Future<void> cargarTransacciones() async {
    _cargando = true;
    notifyListeners();

    try {
      final db = await BaseDeDatos.instancia.database;
      final mapas = await db.query('transacciones', orderBy: 'fecha DESC');
      _transacciones = mapas
          .map((mapa) => TransaccionFinanciera.fromMap(mapa))
          .toList();
    } catch (e) {
      debugPrint('ControladorFinanzas: Error al cargar transacciones: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Registra un ingreso financiero genérico
  Future<void> registrarIngreso(
    String descripcion,
    double monto, {
    DatabaseExecutor? executor,
  }) async {
    final transaccion = TransaccionFinanciera(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: TipoTransaccion.ingreso,
      monto: monto,
      fecha: DateTime.now(),
      descripcion: descripcion,
    );
    await _guardarTransaccion(transaccion, executor: executor);
  }

  /// Método semántico formal para registrar ingresos por ventas de contado dentro del escudo ACID
  Future<void> registrarIngresoVentaContado({
    required String ventaId,
    required double monto,
    DatabaseExecutor? executor,
  }) async {
    await registrarIngreso(
      'Venta completada: $ventaId',
      monto,
      executor: executor,
    );
  }

  /// Registra un egreso de caja (gastos operativos, compra de insumos, sueldos)
  Future<void> registrarEgreso(
    String descripcion,
    double monto, {
    DatabaseExecutor? executor,
  }) async {
    final transaccion = TransaccionFinanciera(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: TipoTransaccion.egreso,
      monto: monto,
      fecha: DateTime.now(),
      descripcion: descripcion,
    );
    await _guardarTransaccion(transaccion, executor: executor);
  }

  /// Registra una pérdida o merma botánica/material
  Future<void> registrarMerma(
    String descripcion,
    double costoPerdido, {
    DatabaseExecutor? executor,
  }) async {
    final transaccion = TransaccionFinanciera(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: TipoTransaccion.merma,
      monto: costoPerdido,
      fecha: DateTime.now(),
      descripcion: 'Merma: $descripcion',
    );
    await _guardarTransaccion(transaccion, executor: executor);
  }

  /// Inserta la transacción en SQLite respetando transacciones externas [executor]
  /// y actualiza la lista local en memoria notificando inmediatamente a la UI.
  Future<void> _guardarTransaccion(
    TransaccionFinanciera transaccion, {
    DatabaseExecutor? executor,
  }) async {
    if (executor != null) {
      await executor.insert('transacciones', transaccion.toMap());
    } else {
      try {
        final db = await BaseDeDatos.instancia.database;
        await db.insert('transacciones', transaccion.toMap());
      } catch (e) {
        debugPrint('ControladorFinanzas: Inserción en BD omitida ($e)');
      }
    }
    _transacciones.insert(0, transaccion);
    notifyListeners();
  }

  /// Retorna el balance neto acumulado (Ingresos - Egresos/Mermas)
  double obtenerBalance() {
    return balanceTotal;
  }

  /// Calcula el rendimiento financiero global
  RendimientoFinanciero calcularRendimientoGlobal() {
    double totalIngr = 0;
    double totalEgr = 0;

    for (var t in _transacciones) {
      if (t.esIngreso) {
        totalIngr += t.monto;
      } else if (t.esEgreso) {
        totalEgr += t.monto;
      }
    }

    return RendimientoFinanciero(
      totalIngresos: totalIngr,
      totalEgresos: totalEgr,
    );
  }

  /// Calcula el rendimiento filtrado por un rango temporal
  RendimientoFinanciero calcularRendimientoPorFecha(
    DateTime inicio,
    DateTime fin,
  ) {
    double totalIngr = 0;
    double totalEgr = 0;

    for (var t in _transacciones) {
      if (t.fecha.isAfter(inicio) && t.fecha.isBefore(fin)) {
        if (t.esIngreso) {
          totalIngr += t.monto;
        } else if (t.esEgreso) {
          totalEgr += t.monto;
        }
      }
    }

    return RendimientoFinanciero(
      totalIngresos: totalIngr,
      totalEgresos: totalEgr,
    );
  }
}
