import '../Modelos/resumen_inicio.dart';
import '../Modelos/venta.dart';
import '../IA/Controladores/controlador_ia_compras.dart';
import 'controlador_inventario.dart';
import 'controlador_ventas.dart';
import 'controlador_finanzas.dart';
import 'controlador_perfil.dart';
import 'controlador_biometrico.dart';

class ControladorInicio {
  final ControladorInventario controladorInventario;
  final ControladorVentas controladorVentas;
  final ControladorFinanzas controladorFinanzas;
  final ControladorPerfil controladorPerfil;
  final ControladorBiometrico controladorBiometrico;
  final ControladorIACompras controladorIA;

  ControladorInicio({
    required this.controladorInventario,
    required this.controladorVentas,
    required this.controladorFinanzas,
    required this.controladorPerfil,
    ControladorBiometrico? controladorBiometrico,
    ControladorIACompras? controladorIA,
  })  : controladorBiometrico =
            controladorBiometrico ?? ControladorBiometrico(),
        controladorIA = controladorIA ??
            ControladorIACompras(controladorInventario: controladorInventario);

  Future<void> inicializarDatosOffline() async {
    await controladorPerfil.cargarConfiguracion();
    await controladorInventario.cargarProductos();
    await controladorFinanzas.cargarTransacciones();
    await controladorVentas.cargarVentas();
    await controladorBiometrico.inicializar();
    await controladorIA.inicializar(controladorVentas.ventas);
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
