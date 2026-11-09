import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../BaseDatos/base_datos.dart';
import '../Modelos/abono.dart';
import '../Modelos/finanzas.dart';
import '../Modelos/venta.dart';
import 'controlador_finanzas.dart';
import 'controlador_ventas.dart';

/// Controlador especializado en Cuentas por Cobrar, Deudores y Abonos para Planteapp.
///
/// Cumple estrictamente con el Principio de Responsabilidad Única (SRP), aislando
/// la lógica de créditos, amortizaciones, auditoría de abonos y liquidación total
/// de saldos de la caja principal del POS.
class ControladorCuentasPorCobrar extends ChangeNotifier {
  final ControladorVentas controladorVentas;
  final ControladorFinanzas controladorFinanzas;

  List<Venta> _cuentasPorCobrar = [];
  bool _cargando = false;

  ControladorCuentasPorCobrar({
    required this.controladorVentas,
    required this.controladorFinanzas,
  });

  List<Venta> get cuentasPorCobrar => _cuentasPorCobrar;
  bool get cargando => _cargando;

  /// Saldo pendiente total acumulado por cobrar a clientes
  double get totalSaldoPendiente => _cuentasPorCobrar.fold(
        0.0,
        (sum, v) => sum + v.saldoPendiente,
      );

  /// Total de cuentas que todavía registran saldo adeudado
  int get totalCuentasActivas =>
      _cuentasPorCobrar.where((v) => v.tieneSaldoPendiente).length;

  /// Retorna la lista de todas las cuentas por cobrar (tanto activas con saldo como liquidadas).
  /// Sincroniza el catálogo de ventas y consulta en SQLite los folios con abonos vinculados.
  Future<List<Venta>> obtenerCuentasPorCobrar({bool recargar = true}) async {
    _cargando = true;
    notifyListeners();

    try {
      if (recargar) {
        await controladorVentas.cargarVentas();
      }
      final db = await BaseDeDatos.instancia.database;

      // Consulta los IDs de todas las ventas que tienen historial de abonos en SQLite
      final rawAbonos = await db.query(
        'abonos_venta',
        columns: ['venta_id'],
        distinct: true,
      );
      final Set<String> idsConAbonos =
          rawAbonos.map((r) => r['venta_id'].toString().trim()).toSet();

      _cuentasPorCobrar = controladorVentas.ventas.where((v) {
        if (v.estado == EstadoVenta.cancelada) return false;
        return v.estado == EstadoVenta.apartada ||
            v.estado == EstadoVenta.liquidada ||
            idsConAbonos.contains(v.id.trim()) ||
            v.tieneSaldoPendiente;
      }).toList();

      return _cuentasPorCobrar;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Consulta el historial cronológico de abonos vinculados a una venta específica
  Future<List<Abono>> obtenerAbonosDeVenta(String ventaId) async {
    final db = await BaseDeDatos.instancia.database;
    final resultados = await db.query(
      'abonos_venta',
      where: 'venta_id = ?',
      whereArgs: [ventaId.trim()],
      orderBy: 'fecha DESC',
    );
    return resultados.map((mapa) => Abono.fromMap(mapa)).toList();
  }

  /// Registra un abono parcial o abono final a una venta apartada en SQLite
  /// ejecutando todas las mutaciones dentro de una transacción segura ACID (txn).
  Future<void> registrarAbono({
    required String ventaId,
    required double monto,
    String metodoPago = 'Efectivo',
    String notas = '',
  }) async {
    if (monto <= 0) {
      throw ArgumentError('El monto del abono debe ser mayor a 0');
    }

    final db = await BaseDeDatos.instancia.database;
    await db.transaction((txn) async {
      // 1. Manejo seguro de tipos para whereArgs (compatibilidad String vs int)
      final String idStr = ventaId.trim();
      final int? idInt = int.tryParse(idStr);

      final String whereClause = idInt != null ? 'id = ? OR id = ?' : 'id = ?';
      final List<dynamic> whereArgs = idInt != null ? [idStr, idInt] : [idStr];

      final List<Map<String, dynamic>> ventasQuery = await txn.query(
        'ventas',
        where: whereClause,
        whereArgs: whereArgs,
      );

      // 2. Extracción segura sin lanzar 'Bad state: No element'
      final Map<String, dynamic>? mapaVenta =
          ventasQuery.isNotEmpty ? ventasQuery.first : null;

      // 3. Validación de nulidad controlada
      if (mapaVenta == null) {
        throw Exception('No se encontró el folio o registro de la venta #$ventaId');
      }

      // Consulta de artículos vinculados con compatibilidad de tipo
      final String artWhere =
          idInt != null ? 'venta_id = ? OR venta_id = ?' : 'venta_id = ?';
      final List<dynamic> artArgs = idInt != null ? [idStr, idInt] : [idStr];

      final List<Map<String, dynamic>> articulosQuery = await txn.query(
        'articulos_venta',
        where: artWhere,
        whereArgs: artArgs,
      );

      double subtotalVenta = 0.0;
      for (var art in articulosQuery) {
        final cant = (art['cantidad'] as num?)?.toDouble() ?? 0.0;
        final precio = (art['precioUnitario'] as num?)?.toDouble() ?? 0.0;
        subtotalVenta += cant * precio;
      }
      final bool aplicarIva = mapaVenta['aplicarIva'] == 1;
      final double pctIva =
          (mapaVenta['porcentajeIva'] as num?)?.toDouble() ?? 0.16;
      final double totalVenta =
          subtotalVenta + (aplicarIva ? subtotalVenta * pctIva : 0.0);

      final double montoPagadoActual =
          (mapaVenta['montoPagado'] as num?)?.toDouble() ?? 0.0;
      final double saldoPendiente =
          (totalVenta - montoPagadoActual).clamp(0.0, double.infinity);

      if (monto > saldoPendiente + 0.01) {
        throw ArgumentError(
          'El abono (\$${monto.toStringAsFixed(2)}) supera el saldo pendiente (\$${saldoPendiente.toStringAsFixed(2)})',
        );
      }

      final double nuevoMontoPagado = montoPagadoActual + monto;
      final bool liquidada = nuevoMontoPagado >= (totalVenta - 0.01);
      final String nuevoEstado =
          liquidada ? EstadoVenta.liquidada.name : EstadoVenta.apartada.name;

      final abono = Abono(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ventaId: idStr,
        monto: monto,
        fecha: DateTime.now(),
        metodoPago: metodoPago,
      );

      // 4. Insertar el abono en el registro histórico
      await txn.insert('abonos_venta', abono.toMap());

      // 5. Actualizar monto acumulado y estado de la venta
      await txn.update(
        'ventas',
        {
          'montoPagado': nuevoMontoPagado,
          'estado': nuevoEstado,
        },
        where: whereClause,
        whereArgs: whereArgs,
      );

      // 6. Registrar el ingreso financiero correspondiente
      final cliente = mapaVenta['cliente']?.toString() ?? 'Cliente';
      await txn.insert('transacciones', {
        'id': '${abono.id}_ingreso',
        'tipo': TipoTransaccion.ingreso.name,
        'monto': monto,
        'fecha': DateTime.now().toIso8601String(),
        'descripcion': liquidada
            ? 'Liquidación final cuenta por cobrar (Venta #$idStr - $cliente)'
            : 'Abono recibido (Venta #$idStr - $cliente)',
      });
    });

    // Refrescar estado local y financiero en memoria
    await controladorVentas.cargarVentas();
    await controladorFinanzas.cargarTransacciones();
    await obtenerCuentasPorCobrar(recargar: false);
    notifyListeners();
  }

  /// Liquida el total del saldo pendiente de una venta de forma atómica
  Future<void> liquidarDeudaTotal({
    required String ventaId,
    String metodoPago = 'Efectivo',
  }) async {
    final venta = controladorVentas.ventas
        .where((v) => v.id == ventaId)
        .firstOrNull;
    if (venta == null) {
      throw Exception('Cuenta de deudor no encontrada en el sistema');
    }
    if (venta.saldoPendiente <= 0) return;
    await registrarAbono(
      ventaId: ventaId,
      monto: venta.saldoPendiente,
      metodoPago: metodoPago,
      notas: 'Liquidación total de deuda',
    );
  }
}
