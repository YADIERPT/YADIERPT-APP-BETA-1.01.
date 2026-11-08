import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../Modelos/producto.dart';
import '../Modelos/venta.dart';
import '../Modelos/abono.dart';
import '../Modelos/finanzas.dart';
import '../BaseDatos/base_datos.dart';
import '../IA/Controladores/controlador_ia_compras.dart';
import 'controlador_inventario.dart';
import 'controlador_finanzas.dart';
import 'controlador_perfil.dart';

class ControladorVentas extends ChangeNotifier {
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

  /// Carga y restaura el historial completo de ventas desde la base de datos SQLite
  /// ordenado descendentemente (la venta más reciente primero).
  /// Se ejecuta automáticamente al arrancar la app y al entrar a la vista de historial.
  Future<List<Venta>> cargarVentasHistorial() async {
    await cargarVentas();
    return _ventas;
  }

  /// Carga la totalidad de las ventas registradas ordenadas descendentemente por fecha.
  Future<void> cargarVentas() async {
    try {
      final db = await BaseDeDatos.instancia.database;
      final mapasVentas = await db.query(
        'ventas',
        orderBy: 'fecha DESC',
      );

      final ventasCargadas = await _mapearVentasDesdeSQLite(db, mapasVentas);
      _ventas.clear();
      _ventas.addAll(ventasCargadas);
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('CRÍTICO: Error al cargar ventas desde SQLite: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Consulta en SQLite las últimas ventas registradas con orden descendente (más reciente arriba)
  /// y límite configurable (ej. para alimentar el Dashboard con las 3 a 5 más recientes).
  Future<List<Venta>> cargarUltimasVentas({int limite = 5}) async {
    try {
      final db = await BaseDeDatos.instancia.database;
      final mapasVentas = await db.query(
        'ventas',
        orderBy: 'fecha DESC',
        limit: limite,
      );

      return await _mapearVentasDesdeSQLite(db, mapasVentas);
    } catch (e, stackTrace) {
      debugPrint('Error al consultar últimas ventas en SQLite: $e\n$stackTrace');
      return _ventas.take(limite).toList();
    }
  }

  /// Mapea de forma segura los registros crudos de SQLite a objetos Venta y sus ArticuloVenta
  Future<List<Venta>> _mapearVentasDesdeSQLite(
    Database db,
    List<Map<String, dynamic>> mapasVentas,
  ) async {
    List<Venta> lista = [];
    for (var mapaVenta in mapasVentas) {
      final ventaId = mapaVenta['id'].toString();
      final int? ventaIdInt = int.tryParse(ventaId);

      // Consulta compatible con identificadores String o int en SQLite
      final mapasArticulos = await db.query(
        'articulos_venta',
        where: ventaIdInt != null ? 'venta_id = ? OR venta_id = ?' : 'venta_id = ?',
        whereArgs: ventaIdInt != null ? [ventaId, ventaIdInt] : [ventaId],
      );

      List<ArticuloVenta> articulos = [];
      for (var mapaArticulo in mapasArticulos) {
        final productoId = mapaArticulo['producto_id'].toString();
        var producto = controladorInventario.obtenerProducto(productoId);

        // Si el producto no está cargado en memoria, buscarlo directamente en la BD
        if (producto == null) {
          final int? prodIdInt = int.tryParse(productoId);
          final prodMaps = await db.query(
            'productos',
            where: prodIdInt != null ? 'id = ? OR id = ?' : 'id = ?',
            whereArgs: prodIdInt != null ? [productoId, prodIdInt] : [productoId],
          );
          if (prodMaps.isNotEmpty) {
            producto = Producto.fromMap(prodMaps.first);
          }
        }

        // Fallback defensivo para asegurar que ningún artículo ni total se pierda
        producto ??= Producto(
          id: productoId,
          nombre: 'Producto #$productoId',
          precioVenta: (mapaArticulo['precioUnitario'] as num?)?.toDouble() ?? 0.0,
          costo: 0.0,
          cantidadEnInventario: 0,
          tipo: 'articulo',
        );

        articulos.add(ArticuloVenta.fromMap(mapaArticulo, producto));
      }

      lista.add(Venta.fromMap(mapaVenta, articulos));
    }
    return lista;
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
      _ventas.insert(0, _ventaActual!);
      _ventaActual = null;
      notifyListeners();
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
          await txn.insert('abonos_venta', abono.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
          await txn.insert('transacciones', {
            'id': '${DateTime.now().millisecondsSinceEpoch}_tr_init',
            'tipo': TipoTransaccion.ingreso.name,
            'monto': montoAbonoInicial,
            'fecha': DateTime.now().toIso8601String(),
            'descripcion': 'Anticipo/Abono inicial venta apartada: ${venta.id} ($cliente)',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });

      // 5. Actualizar inventario en memoria tras éxito del commit
      for (var articulo in venta.articulos) {
        final prodMemoria =
            controladorInventario.obtenerProducto(articulo.producto.id);
        prodMemoria?.reducirInventario(articulo.cantidad);
      }

      _ventaActual = null;
      await cargarVentasHistorial();
      if (montoAbonoInicial > 0) {
        await controladorFinanzas.cargarTransacciones();
      }
      notifyListeners();
    }
  }

  Future<void> completarVentaActual() async {
    if (_ventaActual != null) {
      final ventaTerminada = _ventaActual!;

      try {
        ventaTerminada.completarVenta();
        await _guardarVentaYDescontarStockEnBD(ventaTerminada);

        // Recargar el historial directamente desde SQLite para asegurar sincronización 100% real
        await cargarVentasHistorial();

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
            debugPrint('Aviso: recalibración IA completada con fallback: $e');
          }
        }

        notifyListeners();
      } catch (e, stack) {
        debugPrint('CRÍTICO: Error al completar venta: $e\n$stack');
        rethrow;
      }
    }
  }

  /// Retorna la lista de todas las cuentas por cobrar (tanto activas con saldo como liquidadas)
  Future<List<Venta>> obtenerCuentasPorCobrar({bool recargar = true}) async {
    if (recargar) {
      await cargarVentas();
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

    return _ventas.where((v) {
      if (v.estado == EstadoVenta.cancelada) return false;
      return v.estado == EstadoVenta.apartada ||
          v.estado == EstadoVenta.liquidada ||
          idsConAbonos.contains(v.id.trim()) ||
          v.tieneSaldoPendiente;
    }).toList();
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
      final String artWhere = idInt != null ? 'venta_id = ? OR venta_id = ?' : 'venta_id = ?';
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
      final double pctIva = (mapaVenta['porcentajeIva'] as num?)?.toDouble() ?? 0.16;
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
    await cargarVentas();
    await controladorFinanzas.cargarTransacciones();
  }

  /// Liquida el total del saldo pendiente de una venta de forma atómica
  Future<void> liquidarDeudaTotal({
    required String ventaId,
    String metodoPago = 'Efectivo',
  }) async {
    final venta = _ventas.where((v) => v.id == ventaId).firstOrNull;
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

  /// Inserta una venta sin alterar el inventario (ej. ventas canceladas).
  Future<void> _guardarVentaEnBD(Venta venta) async {
    final db = await BaseDeDatos.instancia.database;
    try {
      await db.transaction((txn) async {
        await txn.insert(
          'ventas',
          venta.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (var articulo in venta.articulos) {
          await txn.insert(
            'articulos_venta',
            articulo.toMap(venta.id),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
      debugPrint('Venta guardada en SQLite (sin alterar stock): ${venta.id}');
    } catch (e, stackTrace) {
      debugPrint('CRÍTICO: Error al insertar venta en SQLite (_guardarVentaEnBD): $e\n$stackTrace');
      rethrow;
    }
  }

  /// Guarda la venta y descuenta el stock de inventario de forma estrictamente atómica.
  /// Si cualquier inserción o actualización falla, SQLite revierte automáticamente (rollback)
  /// todas las operaciones dentro de la transacción, previniendo datos corruptos o desincronizados.
  Future<void> _guardarVentaYDescontarStockEnBD(Venta venta) async {
    final db = await BaseDeDatos.instancia.database;

    try {
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
            await txn.insert(
              'productos',
              mapProd,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        // 2. Registrar la venta en la tabla principal con validación explícita
        final int rowIdVenta = await txn.insert(
          'ventas',
          venta.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        debugPrint('Venta insertada en SQLite: ${venta.id} (Row ID: $rowIdVenta)');

        // 3. Registrar los artículos de la venta
        for (var articulo in venta.articulos) {
          final int rowIdArticulo = await txn.insert(
            'articulos_venta',
            articulo.toMap(venta.id),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          debugPrint('Artículo de venta insertado: ${articulo.producto.nombre} x${articulo.cantidad} (Row ID: $rowIdArticulo)');
        }
      });

      // 4. Tras confirmarse el COMMIT exitoso de la transacción, sincronizamos la memoria local
      for (var articulo in venta.articulos) {
        final prodMemoria =
            controladorInventario.obtenerProducto(articulo.producto.id);
        prodMemoria?.reducirInventario(articulo.cantidad);
      }
    } catch (e, stackTrace) {
      debugPrint('CRÍTICO: Fallo al guardar venta en SQLite: $e\n$stackTrace');
      rethrow;
    }
  }
}
