import '../Modelos/venta.dart';
import '../Modelos/abono.dart';
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
    final mapasVentas = await db.query('ventas', orderBy: 'fecha DESC');

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

  /// Registra la venta actual bajo modalidad de apartado / cuenta por cobrar
  Future<void> apartarVentaActual({
    String cliente = 'Cliente Mostrador',
    double montoAbonoInicial = 0.0,
    String notas = '',
    String metodoPagoAbono = 'Efectivo',
  }) async {
    if (_ventaActual != null) {
      final venta = _ventaActual!;
      venta.apartarVenta(
        abonoInicial: montoAbonoInicial,
        nombreCliente: cliente,
      );
      venta.notas = notas;

      final db = await BaseDeDatos.instancia.database;
      await db.transaction((txn) async {
        // 1. Descuento atómico de existencias dentro de la transacción
        for (var articulo in venta.articulos) {
          final List<Map<String, dynamic>> res = await txn.query(
            'productos',
            columns: ['cantidadEnInventario', 'nombre'],
            where: 'id = ?',
            whereArgs: [articulo.producto.id],
          );

          if (res.isNotEmpty) {
            final int stockActual =
                (res.first['cantidadEnInventario'] as int?) ?? 0;
            final int nuevoStock = stockActual - articulo.cantidad;

            if (nuevoStock < 0) {
              throw Exception(
                'Stock insuficiente para apartar "${articulo.producto.nombre}". '
                'Disponible: $stockActual, Requerido: ${articulo.cantidad}.',
              );
            }

            await txn.update(
              'productos',
              {'cantidadEnInventario': nuevoStock},
              where: 'id = ?',
              whereArgs: [articulo.producto.id],
            );
          } else {
            final prod = controladorInventario.obtenerProducto(articulo.producto.id) ?? articulo.producto;
            final nuevoStock = (prod.cantidadEnInventario - articulo.cantidad).clamp(0, 999999);
            final mapProd = prod.toMap();
            mapProd['cantidadEnInventario'] = nuevoStock;
            await txn.insert('productos', mapProd);
          }
        }

        // 2. Inserción de la venta
        await txn.insert('ventas', venta.toMap());

        // 3. Inserción de los artículos
        for (var articulo in venta.articulos) {
          await txn.insert('articulos_venta', articulo.toMap(venta.id));
        }

        // 4. Inserción de abono inicial y asiento financiero
        if (montoAbonoInicial > 0) {
          final abono = Abono(
            id: '${DateTime.now().millisecondsSinceEpoch}_init',
            ventaId: venta.id,
            monto: montoAbonoInicial,
            fecha: DateTime.now(),
            metodoPago: metodoPagoAbono,
          );
          await txn.insert('abonos_venta', abono.toMap());
          await txn.insert('transacciones', {
            'id': '${DateTime.now().millisecondsSinceEpoch}_tr_init',
            'tipo': 'INGRESO',
            'monto': montoAbonoInicial,
            'fecha': DateTime.now().toIso8601String(),
            'descripcion': 'Anticipo/Abono inicial venta apartada: ${venta.id} ($cliente)',
          });
        }
      });

      // 5. Actualizar inventario en memoria tras éxito del commit
      for (var articulo in venta.articulos) {
        final prodMemoria =
            controladorInventario.obtenerProducto(articulo.producto.id);
        prodMemoria?.reducirInventario(articulo.cantidad);
      }

      _ventas.insert(0, venta);
      _ventaActual = null;
      if (montoAbonoInicial > 0) {
        await controladorFinanzas.cargarTransacciones();
      }
    }
  }

  Future<void> completarVentaActual() async {
    if (_ventaActual != null) {
      final ventaTerminada = _ventaActual!;

      ventaTerminada.completarVenta();
      await _guardarVentaYDescontarStockEnBD(ventaTerminada);
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
        } catch (_) {}
      }
    }
  }

  /// Retorna la lista de ventas apartadas o con saldo adeudado
  Future<List<Venta>> obtenerCuentasPorCobrar({bool recargar = true}) async {
    if (recargar) {
      await cargarVentas();
    }
    return _ventas
        .where((v) =>
            v.estado == EstadoVenta.apartada ||
            (v.estado != EstadoVenta.cancelada && v.tieneSaldoPendiente))
        .toList();
  }

  /// Consulta el historial cronológico de abonos vinculados a una venta
  Future<List<Abono>> obtenerAbonosDeVenta(String ventaId) async {
    final db = await BaseDeDatos.instancia.database;
    final resultados = await db.query(
      'abonos_venta',
      where: 'venta_id = ?',
      whereArgs: [ventaId],
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
      final ventasQuery = await txn.query(
        'ventas',
        where: 'id = ?',
        whereArgs: [ventaId],
      );

      if (ventasQuery.isEmpty) {
        throw Exception('Venta no encontrada en la base de datos');
      }

      final mapaVenta = ventasQuery.first;
      final articulosQuery = await txn.query(
        'articulos_venta',
        where: 'venta_id = ?',
        whereArgs: [ventaId],
      );

      double subtotalVenta = 0.0;
      for (var art in articulosQuery) {
        subtotalVenta +=
            (art['cantidad'] as num) * (art['precioUnitario'] as num);
      }
      final bool aplicarIva = mapaVenta['aplicarIva'] == 1;
      final double pctIva = (mapaVenta['porcentajeIva'] as num).toDouble();
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
          liquidada ? EstadoVenta.completada.name : EstadoVenta.apartada.name;

      final abono = Abono(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ventaId: ventaId,
        monto: monto,
        fecha: DateTime.now(),
        metodoPago: metodoPago,
      );

      // 1. Insertar el abono en el registro histórico
      await txn.insert('abonos_venta', abono.toMap());

      // 2. Actualizar monto acumulado y estado de la venta
      await txn.update(
        'ventas',
        {
          'montoPagado': nuevoMontoPagado,
          'estado': nuevoEstado,
        },
        where: 'id = ?',
        whereArgs: [ventaId],
      );

      // 3. Registrar el ingreso financiero correspondiente
      final cliente = mapaVenta['cliente']?.toString() ?? 'Cliente';
      await txn.insert('transacciones', {
        'id': '${abono.id}_ingreso',
        'tipo': 'INGRESO',
        'monto': monto,
        'fecha': DateTime.now().toIso8601String(),
        'descripcion': liquidada
            ? 'Liquidación final cuenta por cobrar (Venta #$ventaId - $cliente)'
            : 'Abono recibido (Venta #$ventaId - $cliente)',
      });
    });

    // Refrescar estado local y financiero en memoria
    await cargarVentas();
    await controladorFinanzas.cargarTransacciones();
  }

  /// Liquida el total del saldo pendiente de una venta de forma atómica
  Future<void> liquidarDeudaTotal({
    required String ventaId,
    String metodoPago = 'Efectivo',
  }) async {
    final venta = _ventas.firstWhere(
      (v) => v.id == ventaId,
      orElse: () => throw Exception('Venta no encontrada'),
    );
    if (venta.saldoPendiente <= 0) return;
    await registrarAbono(
      ventaId: ventaId,
      monto: venta.saldoPendiente,
      metodoPago: metodoPago,
      notas: 'Liquidación total de deuda',
    );
  }

  /// Inserta una venta sin alterar el inventario (ej. ventas canceladas).
  Future<void> _guardarVentaEnBD(Venta venta) async {
    final db = await BaseDeDatos.instancia.database;
    await db.transaction((txn) async {
      await txn.insert('ventas', venta.toMap());
      for (var articulo in venta.articulos) {
        await txn.insert('articulos_venta', articulo.toMap(venta.id));
      }
    });
  }

  /// Guarda la venta y descuenta el stock de inventario de forma estrictamente atómica.
  /// Si cualquier inserción o actualización falla, SQLite revierte automáticamente (rollback)
  /// todas las operaciones dentro de la transacción, previniendo datos corruptos o desincronizados.
  Future<void> _guardarVentaYDescontarStockEnBD(Venta venta) async {
    final db = await BaseDeDatos.instancia.database;

    await db.transaction((txn) async {
      // 1. Descontar el stock de cada producto dentro de la transacción
      for (var articulo in venta.articulos) {
        final List<Map<String, dynamic>> res = await txn.query(
          'productos',
          columns: ['cantidadEnInventario', 'nombre'],
          where: 'id = ?',
          whereArgs: [articulo.producto.id],
        );

        if (res.isNotEmpty) {
          final int stockActual =
              (res.first['cantidadEnInventario'] as int?) ?? 0;
          final int nuevoStock = stockActual - articulo.cantidad;

          if (nuevoStock < 0) {
            throw Exception(
              'Stock insuficiente para "${articulo.producto.nombre}". '
              'Disponible: $stockActual, Solicitado: ${articulo.cantidad}.',
            );
          }

          await txn.update(
            'productos',
            {'cantidadEnInventario': nuevoStock},
            where: 'id = ?',
            whereArgs: [articulo.producto.id],
          );
        } else {
          final prod = controladorInventario.obtenerProducto(articulo.producto.id) ?? articulo.producto;
          final nuevoStock = (prod.cantidadEnInventario - articulo.cantidad).clamp(0, 999999);
          final mapProd = prod.toMap();
          mapProd['cantidadEnInventario'] = nuevoStock;
          await txn.insert('productos', mapProd);
        }
      }

      // 2. Registrar la venta en la tabla principal
      await txn.insert('ventas', venta.toMap());

      // 3. Registrar los artículos de la venta
      for (var articulo in venta.articulos) {
        await txn.insert('articulos_venta', articulo.toMap(venta.id));
      }
    });

    // 4. Tras confirmarse el COMMIT exitoso de la transacción, sincronizamos la memoria local
    for (var articulo in venta.articulos) {
      final prodMemoria =
          controladorInventario.obtenerProducto(articulo.producto.id);
      prodMemoria?.reducirInventario(articulo.cantidad);
    }
  }
}
