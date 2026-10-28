import '../Modelos/venta.dart';
import '../BaseDatos/base_datos.dart';
import '../IA/Controladores/controlador_ia_compras.dart';
import 'controlador_inventario.dart';
import 'controlador_finanzas.dart';
import 'controlador_perfil.dart';

class ControladorVentas {
  final ControladorInventario controladorInventario;
  final ControladorFinanzas controladorFinanzas;
  final ControladorPerfil controladorPerfil;
  ControladorIACompras? controladorIA;
  final List<Venta> _ventas = [];

  Venta? _ventaActual;

  ControladorVentas({
    required this.controladorInventario,
    required this.controladorFinanzas,
    required this.controladorPerfil,
    this.controladorIA,
  });

  List<Venta> get ventas => _ventas;
  Venta? get ventaActual => _ventaActual;

  Future<void> cargarVentas() async {
    final db = await BaseDeDatos.instancia.database;
    final mapasVentas = await db.query('ventas');

    _ventas.clear();
    for (var mapaVenta in mapasVentas) {
      final ventaId = mapaVenta['id'] as String;
      final mapasArticulos = await db.query(
        'articulos_venta',
        where: 'venta_id = ?',
        whereArgs: [ventaId],
      );

      List<ArticuloVenta> articulos = [];
      for (var mapaArticulo in mapasArticulos) {
        final productoId = mapaArticulo['producto_id'] as String;
        final producto = controladorInventario.obtenerProducto(productoId);

        if (producto != null) {
          articulos.add(ArticuloVenta.fromMap(mapaArticulo, producto));
        }
      }

      _ventas.add(Venta.fromMap(mapaVenta, articulos));
    }
  }

  void iniciarVenta() {
    _ventaActual = Venta(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fecha: DateTime.now(),
      porcentajeIva: controladorPerfil.configuracion.porcentajeIvaDefecto,
      aplicarIva: controladorPerfil.configuracion.aplicarIva,
    );
  }

  void agregarProductoAVentaActual(String productoId, int cantidad) {
    if (_ventaActual == null) {
      throw Exception('No hay una venta en proceso.');
    }

    final producto = controladorInventario.obtenerProducto(productoId);
    if (producto != null) {
      int cantidadActualEnCarrito = 0;
      final idx = _ventaActual!.articulos.indexWhere(
        (art) => art.producto.id == productoId,
      );
      if (idx != -1) {
        cantidadActualEnCarrito = _ventaActual!.articulos[idx].cantidad;
      }

      if (producto.cantidadEnInventario >=
          (cantidadActualEnCarrito + cantidad)) {
        _ventaActual!.agregarArticulo(producto, cantidad);
      } else {
        throw Exception(
          'Stock insuficiente para el producto: ${producto.nombre}',
        );
      }
    } else {
      throw Exception('Producto no encontrado en el inventario.');
    }
  }

  Future<void> cancelarVentaActual() async {
    if (_ventaActual != null) {
      _ventaActual!.cancelarVenta();
      await _guardarVentaEnBD(_ventaActual!);
      _ventas.add(_ventaActual!);
      _ventaActual = null;
    }
  }

  Future<void> apartarVentaActual() async {
    if (_ventaActual != null) {
      await _descontarInventarioDeVenta(_ventaActual!);
      _ventaActual!.apartarVenta();
      await _guardarVentaEnBD(_ventaActual!);
      _ventas.add(_ventaActual!);
      _ventaActual = null;
    }
  }

  Future<void> completarVentaActual() async {
    if (_ventaActual != null) {
      final ventaTerminada = _ventaActual!;
      await _descontarInventarioDeVenta(ventaTerminada);

      ventaTerminada.completarVenta();
      await _guardarVentaEnBD(ventaTerminada);
      _ventas.add(ventaTerminada);

      await controladorFinanzas.registrarIngreso(
        'Venta completada: ${ventaTerminada.id}',
        ventaTerminada.total,
      );

      _ventaActual = null;

      // Calibración reactiva local de la IA de compras
      if (controladorIA != null) {
        try {
          await controladorIA!.recalibrarPorVenta(
            venta: ventaTerminada,
            todasLasVentas: _ventas,
          );
        } catch (e) {
          // No detener el flujo de venta si la IA arroja advertencia
        }
      }
    }
  }

  Future<void> _guardarVentaEnBD(Venta venta) async {
    final db = await BaseDeDatos.instancia.database;
    await db.transaction((txn) async {
      await txn.insert('ventas', venta.toMap());
      for (var articulo in venta.articulos) {
        await txn.insert('articulos_venta', articulo.toMap(venta.id));
      }
    });
  }

  Future<void> _descontarInventarioDeVenta(Venta venta) async {
    for (var articulo in venta.articulos) {
      await controladorInventario.descontarInventarioPorVenta(
        articulo.producto.id,
        articulo.cantidad,
      );
    }
  }
}
