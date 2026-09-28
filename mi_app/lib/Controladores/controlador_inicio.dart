import '../Modelos/resumen_inicio.dart';
import '../Modelos/venta.dart';
import 'controlador_inventario.dart';
import 'controlador_ventas.dart';
import 'controlador_finanzas.dart';
import 'controlador_perfil.dart';

class ControladorInicio {
  final ControladorInventario controladorInventario;
  final ControladorVentas controladorVentas;
  final ControladorFinanzas controladorFinanzas;
  final ControladorPerfil controladorPerfil;

  ControladorInicio({
    required this.controladorInventario,
    required this.controladorVentas,
    required this.controladorFinanzas,
    required this.controladorPerfil,
  });
  Future<void> inicializarDatosOffline() async {
    await controladorPerfil.cargarConfiguracion();
    await controladorInventario.cargarProductos();
    await controladorFinanzas.cargarTransacciones();
    await controladorVentas.cargarVentas();
  }

  ResumenInicio generarResumenDelDia() {
    final hoy = DateTime.now();
    final inicioDelDia = DateTime(hoy.year, hoy.month, hoy.day);
    final finDelDia = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);

    final rendimientoHoy = controladorFinanzas.calcularRendimientoPorFecha(
      inicioDelDia,
      finDelDia,
    );

    int ventasCompletadas = 0;
    int ventasApartadas = 0;

    for (var venta in controladorVentas.ventas) {
      if (venta.fecha.isAfter(inicioDelDia) &&
          venta.fecha.isBefore(finDelDia)) {
        if (venta.estado == EstadoVenta.completada) {
          ventasCompletadas++;
        } else if (venta.estado == EstadoVenta.apartada) {
          ventasApartadas++;
        }
      }
    }

    int totalProductos = 0;
    for (var producto in controladorInventario.productos) {
      totalProductos += producto.cantidadEnInventario;
    }

    return ResumenInicio(
      totalProductosInventario: totalProductos,
      ventasCompletadasHoy: ventasCompletadas,
      ventasApartadas: ventasApartadas,
      ingresosHoy: rendimientoHoy.totalIngresos,
      gananciasHoy: rendimientoHoy.gananciasNetas,
    );
  }
}
