import '../Modelos/finanzas.dart';
import '../BaseDatos/base_datos.dart';

class ControladorFinanzas {
  List<TransaccionFinanciera> _transacciones = [];

  List<TransaccionFinanciera> get transacciones => _transacciones;

  Future<void> cargarTransacciones() async {
    final db = await BaseDeDatos.instancia.database;
    final mapas = await db.query('transacciones');
    _transacciones = mapas
        .map((mapa) => TransaccionFinanciera.fromMap(mapa))
        .toList();
  }

  Future<void> registrarIngreso(String descripcion, double monto) async {
    final transaccion = TransaccionFinanciera(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: TipoTransaccion.ingreso,
      monto: monto,
      fecha: DateTime.now(),
      descripcion: descripcion,
    );
    await _guardarTransaccion(transaccion);
  }

  Future<void> registrarEgreso(String descripcion, double monto) async {
    final transaccion = TransaccionFinanciera(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: TipoTransaccion.egreso,
      monto: monto,
      fecha: DateTime.now(),
      descripcion: descripcion,
    );
    await _guardarTransaccion(transaccion);
  }

  Future<void> registrarMerma(String descripcion, double costoPerdido) async {
    final transaccion = TransaccionFinanciera(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tipo: TipoTransaccion.merma,
      monto: costoPerdido,
      fecha: DateTime.now(),
      descripcion: 'Merma: $descripcion',
    );
    await _guardarTransaccion(transaccion);
  }

  Future<void> _guardarTransaccion(TransaccionFinanciera transaccion) async {
    final db = await BaseDeDatos.instancia.database;
    await db.insert('transacciones', transaccion.toMap());
    _transacciones.add(transaccion);
  }

  RendimientoFinanciero calcularRendimientoGlobal() {
    double totalIngresos = 0;
    double totalEgresos = 0;

    for (var t in _transacciones) {
      if (t.esIngreso) {
        totalIngresos += t.monto;
      } else if (t.esEgreso) {
        totalEgresos += t.monto;
      }
    }

    return RendimientoFinanciero(
      totalIngresos: totalIngresos,
      totalEgresos: totalEgresos,
    );
  }

  RendimientoFinanciero calcularRendimientoPorFecha(
    DateTime inicio,
    DateTime fin,
  ) {
    double totalIngresos = 0;
    double totalEgresos = 0;

    for (var t in _transacciones) {
      if (t.fecha.isAfter(inicio) && t.fecha.isBefore(fin)) {
        if (t.esIngreso) {
          totalIngresos += t.monto;
        } else if (t.esEgreso) {
          totalEgresos += t.monto;
        }
      }
    }

    return RendimientoFinanciero(
      totalIngresos: totalIngresos,
      totalEgresos: totalEgresos,
    );
  }
}
