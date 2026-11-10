import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_cuentas_por_cobrar.dart';
import '../Modelos/venta.dart';
import '../Modelos/abono.dart';
import '../Servicios/servicio_ticket_pdf.dart';
import '../Utilidades/formateador.dart';
import '../Utilidades/debouncer.dart';

class DeudoresVista extends StatefulWidget {
  final ControladorCuentasPorCobrar? controladorCuentasPorCobrar;
  final ControladorVentas? controladorVentas;

  const DeudoresVista({
    super.key,
    this.controladorCuentasPorCobrar,
    this.controladorVentas,
  });

  @override
  State<DeudoresVista> createState() => _DeudoresVistaState();
}

class _DeudoresVistaState extends State<DeudoresVista> {
  List<Venta> _cuentas = [];
  bool _cargando = true;
  String _busqueda = '';
  String _filtroActivo = 'pendientes'; // 'pendientes', 'todos', 'liquidados'
  final TextEditingController _busquedaController = TextEditingController();
  final Debouncer _busquedaDebouncer =
      Debouncer(delay: const Duration(milliseconds: 300));

  ControladorCuentasPorCobrar get _cobrables {
    if (widget.controladorCuentasPorCobrar != null) {
      return widget.controladorCuentasPorCobrar!;
    }
    try {
      return context.read<ControladorCuentasPorCobrar>();
    } catch (_) {
      return ControladorCuentasPorCobrar(
        controladorVentas: widget.controladorVentas!,
        controladorFinanzas: widget.controladorVentas!.controladorFinanzas,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargarCuentas();
    });
  }

  @override
  void dispose() {
    _busquedaDebouncer.dispose();
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarCuentas() async {
    final cuentas = await _cobrables.obtenerCuentasPorCobrar();
    if (mounted) {
      setState(() {
        _cuentas = cuentas;
        _cargando = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    await _cargarCuentas();
    await Future.delayed(const Duration(milliseconds: 300));
  }

  List<Venta> get _cuentasFiltradas {
    return _cuentas.where((v) {
      // Filtro por búsqueda
      final coincideNombre =
          v.cliente.toLowerCase().contains(_busqueda.toLowerCase());
      final coincideId = v.id.contains(_busqueda);
      if (_busqueda.isNotEmpty && !coincideNombre && !coincideId) {
        return false;
      }

      // Filtro por estado
      if (_filtroActivo == 'pendientes') {
        return v.tieneSaldoPendiente;
      } else if (_filtroActivo == 'liquidados') {
        return !v.tieneSaldoPendiente;
      }
      return true;
    }).toList();
  }

  double get _totalPorCobrar {
    return _cuentas.fold(
      0.0,
      (sum, v) => sum + (v.tieneSaldoPendiente ? v.saldoPendiente : 0.0),
    );
  }

  double get _totalRecuperado {
    return _cuentas.fold(0.0, (sum, v) => sum + v.montoPagado);
  }

  int get _cantidadDeudoresActivos {
    return _cuentas.where((v) => v.tieneSaldoPendiente).length;
  }

  int get _cantidadLiquidados {
    return _cuentas.where((v) => !v.tieneSaldoPendiente).length;
  }

  void _mostrarToast(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              esError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: esError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _abrirModalAbono(Venta venta) {
    // Consulta segura del deudor evitando 'Bad state: No element'
    final deudorActual = _cuentas.where((v) => v.id == venta.id).firstOrNull;
    if (deudorActual == null) {
      _mostrarToast(
        'Error: No se encontró la cuenta o el deudor seleccionado.',
        esError: true,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModalAbonoSheet(
        venta: deudorActual,
        onRegistrar: (monto, metodoPago) async {
          try {
            final comprobante = await _cobrables.registrarAbono(
              ventaId: deudorActual.id,
              monto: monto,
              metodoPago: metodoPago,
            );
            await _cargarCuentas();
            _mostrarToast(
              'Abono de \$${monto.toStringAsFixed(2)} registrado correctamente',
            );
            if (mounted) {
              await ServicioTicketPdf.instancia.descargarYAbrirComprobanteAbono(
                context,
                comprobante: comprobante,
              );
            }
          } catch (e) {
            _mostrarToast('Error al registrar abono: $e', esError: true);
          }
        },
      ),
    );
  }

  Future<void> _confirmarLiquidacionTotal(Venta venta) async {
    // Consulta segura del deudor
    final deudorActual = _cuentas.where((v) => v.id == venta.id).firstOrNull;
    if (deudorActual == null) {
      _mostrarToast(
        'Error: No se encontró la cuenta del deudor para liquidar.',
        esError: true,
      );
      return;
    }

    final saldo = deudorActual.saldoPendiente;
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.subtleAmber,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: AppColors.amber,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Liquidar Cuenta',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Deseas saldar en su totalidad la deuda de ${deudorActual.cliente}?',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondarySurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monto a liquidar:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '\$${saldo.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppColors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Se registrará una transacción de ingreso y el estado del apartado pasará a Completada.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Liquidar Total'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        final comprobante = await _cobrables.liquidarDeudaTotal(ventaId: deudorActual.id);
        await _cargarCuentas();
        _mostrarToast('Cuenta liquidada en su totalidad con éxito.');
        if (mounted && comprobante != null) {
          await ServicioTicketPdf.instancia.descargarYAbrirComprobanteAbono(
            context,
            comprobante: comprobante,
          );
        }
      } catch (e) {
        _mostrarToast('Error al liquidar deuda: $e', esError: true);
      }
    }
  }

  void _verHistorialAbonos(Venta venta) {
    final deudorActual = _cuentas.where((v) => v.id == venta.id).firstOrNull;
    if (deudorActual == null) {
      _mostrarToast(
        'Error: No se encontró la cuenta para consultar historial.',
        esError: true,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _HistorialAbonosSheet(
        venta: deudorActual,
        controladorCuentasPorCobrar: _cobrables,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuentasMostradas = _cuentasFiltradas;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          'Cuentas por Cobrar',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.surface,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _handleRefresh,
          ),
        ],
      ),
      body: _cargando
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.card,
              strokeWidth: 2.5,
              onRefresh: _handleRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // 1. Resumen KPI de la cartera
                  _buildResumenCartera(),
                  const SizedBox(height: 16),

                  // 2. Buscador con Debounce de 300 ms y RepaintBoundary
                  RepaintBoundary(
                    child: TextField(
                      controller: _busquedaController,
                      onChanged: (val) {
                        _busquedaDebouncer.run(() {
                          if (mounted) {
                            setState(() {
                              _busqueda = val.trim();
                            });
                          }
                        });
                      },
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar por cliente o folio #...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        suffixIcon: _busqueda.isNotEmpty || _busquedaController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: AppColors.textSecondary,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _busquedaDebouncer.cancel();
                                  _busquedaController.clear();
                                  setState(() {
                                    _busqueda = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.secondarySurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Chips de Filtro
                  Row(
                    children: [
                      _buildChipFiltro('pendientes', 'Con Saldo ($_cantidadDeudoresActivos)'),
                      const SizedBox(width: 8),
                      _buildChipFiltro('todos', 'Todos (${_cuentas.length})'),
                      const SizedBox(width: 8),
                      _buildChipFiltro('liquidados', 'Liquidados ($_cantidadLiquidados)'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Listado de Deudores
                  if (cuentasMostradas.isEmpty)
                    _buildEstadoVacio()
                  else
                    ...cuentasMostradas.map((venta) => _buildTarjetaDeudor(venta)),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildResumenCartera() {
    return RepaintBoundary(
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CARTERA PENDIENTE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.amber,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.subtleAmber,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_cantidadDeudoresActivos pendientes',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${_totalPorCobrar.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Recuperado',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${_totalRecuperado.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 28,
                width: 1,
                color: AppColors.border,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total en Apartados',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${(_totalPorCobrar + _totalRecuperado).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildChipFiltro(String filtro, String etiqueta) {
    final bool activo = _filtroActivo == filtro;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filtroActivo = filtro;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: activo ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          etiqueta,
          style: TextStyle(
            fontSize: 12,
            fontWeight: activo ? FontWeight.bold : FontWeight.w500,
            color: activo ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTarjetaDeudor(Venta venta) {
    final bool tieneSaldo = venta.tieneSaldoPendiente;
    final double progreso = venta.porcentajePagado;
    final String fechaFormato =
        '${venta.fecha.day.toString().padLeft(2, '0')}/${venta.fecha.month.toString().padLeft(2, '0')}/${venta.fecha.year}';

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        clipBehavior: Clip.antiAlias, // Forzar clipping de bordes redondeados y evitar bleeding
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: tieneSaldo
                ? AppColors.amber.withValues(alpha: 0.25)
                : AppColors.border,
            width: 1,
          ),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado: Cliente y Estado
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venta.cliente,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Folio: #${venta.id.substring(venta.id.length > 6 ? venta.id.length - 6 : 0)} · Registrado el $fechaFormato',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tieneSaldo
                      ? AppColors.subtleAmber
                      : AppColors.subtleGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tieneSaldo ? 'PENDIENTE' : 'LIQUIDADA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: tieneSaldo ? AppColors.amber : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barra de Progreso de Pago
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 6,
              backgroundColor: AppColors.secondarySurface,
              valueColor: AlwaysStoppedAnimation<Color>(
                tieneSaldo ? AppColors.amber : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Desglose de montos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL VENTA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '\$${venta.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'ABONADO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '\$${venta.montoPagado.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'SALDO RESTANTE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '\$${venta.saldoPendiente.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.amber,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (venta.articulos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Artículos: ${venta.articulos.map((a) => "${a.cantidad}x ${a.producto.nombre}").join(", ")}',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          // Acciones: Abonar, Liquidar, Historial (Envueltas en Wrap responsivo para evitar overflow)
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Grupo de acciones informativas (Historial + Ticket PDF)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => _verHistorialAbonos(venta),
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('Historial', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ticket de Crédito PDF',
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    color: AppColors.textSecondary,
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      await ServicioTicketPdf.instancia.descargarYAbrirTicket(
                        context,
                        venta,
                        esCredito: true,
                      );
                    },
                  ),
                ],
              ),

              // Grupo de acciones transaccionales (Liquidar + Abonar)
              if (tieneSaldo)
                Wrap(
                  spacing: 8.0,
                  runSpacing: 6.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _confirmarLiquidacionTotal(venta),
                      icon: const Icon(Icons.done_all_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Liquidar', style: TextStyle(fontSize: 12)),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _abrirModalAbono(venta),
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Abonar',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Totalmente cubierto',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _filtroActivo == 'liquidados'
                ? 'Sin cuentas liquidadas'
                : 'Sin cuentas por cobrar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _busqueda.isNotEmpty
                ? 'No se encontraron resultados para "$_busqueda".'
                : _filtroActivo == 'liquidados'
                    ? 'Aún no hay cuentas liquidadas registradas en el historial.'
                    : 'No hay deudas o apartados pendientes en esta sección.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal BottomSheet para el registro seguro de abonos
class _ModalAbonoSheet extends StatefulWidget {
  final Venta venta;
  final Function(double monto, String metodoPago) onRegistrar;

  const _ModalAbonoSheet({
    required this.venta,
    required this.onRegistrar,
  });

  @override
  State<_ModalAbonoSheet> createState() => _ModalAbonoSheetState();
}

class _ModalAbonoSheetState extends State<_ModalAbonoSheet> {
  final TextEditingController _montoCtrl = TextEditingController();
  final Debouncer _montoDebouncer =
      Debouncer(delay: const Duration(milliseconds: 300));
  String _metodoPago = 'Efectivo';
  String? _errorTexto;

  @override
  void dispose() {
    _montoDebouncer.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  void _asignarPorcentaje(double pct) {
    _montoDebouncer.cancel();
    final monto = widget.venta.saldoPendiente * pct;
    _montoCtrl.text = monto.toStringAsFixed(2);
    _validarMonto();
  }

  void _validarMonto() {
    final valor = Formateador.parsearMoneda(_montoCtrl.text);
    if (valor <= 0) {
      setState(() => _errorTexto = 'Ingresa un monto válido mayor a 0');
    } else if (valor > widget.venta.saldoPendiente + 0.01) {
      setState(() => _errorTexto = 'Supera el saldo pendiente');
    } else {
      setState(() => _errorTexto = null);
    }
  }

  void _confirmarAbono() {
    _validarMonto();
    if (_errorTexto != null) return;

    final monto = Formateador.parsearMoneda(_montoCtrl.text);
    if (monto > 0) {
      Navigator.pop(context);
      widget.onRegistrar(monto, _metodoPago);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saldo = widget.venta.saldoPendiente;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Asa de arrastre
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registrar Abono',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cliente: ${widget.venta.cliente}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.subtleAmber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'SALDO PENDIENTE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.amber,
                        ),
                      ),
                      Text(
                        '\$${saldo.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Accesos directos de porcentaje
            Row(
              children: [
                _buildQuickButton('25%', () => _asignarPorcentaje(0.25)),
                const SizedBox(width: 8),
                _buildQuickButton('50%', () => _asignarPorcentaje(0.50)),
                const SizedBox(width: 8),
                _buildQuickButton('Total', () => _asignarPorcentaje(1.0)),
              ],
            ),
            const SizedBox(height: 14),

            // Campo de Monto con RepaintBoundary y Debounce
            RepaintBoundary(
              child: TextField(
                controller: _montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FormateadorMilesMonetario(max: widget.venta.saldoPendiente + 0.01),
                ],
                onChanged: (_) {
                  _montoDebouncer.run(() {
                    if (mounted) _validarMonto();
                  });
                },
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  labelText: 'Monto a abonar',
                  labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  errorText: _errorTexto,
                  filled: true,
                  fillColor: AppColors.secondarySurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selector de Método de Pago
            Text(
              'Método de Pago',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildMetodoChip('Efectivo', Icons.money),
                const SizedBox(width: 8),
                _buildMetodoChip('Tarjeta', Icons.credit_card),
                const SizedBox(width: 8),
                _buildMetodoChip('Transferencia', Icons.account_balance),
              ],
            ),
            const SizedBox(height: 22),

            // Botón de Confirmación
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _confirmarAbono,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Registrar Pago en SQLite',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(String etiqueta, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        child: Text(
          etiqueta,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildMetodoChip(String metodo, IconData icono) {
    final bool seleccionado = _metodoPago == metodo;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _metodoPago = metodo),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: seleccionado ? AppColors.primary : AppColors.secondarySurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: seleccionado ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icono,
                size: 16,
                color: seleccionado ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                metodo,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: seleccionado ? Colors.white : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sheet para consultar el historial cronológico de abonos de una cuenta
class _HistorialAbonosSheet extends StatelessWidget {
  final Venta venta;
  final ControladorCuentasPorCobrar? controladorCuentasPorCobrar;
  final ControladorVentas? controladorVentas;

  const _HistorialAbonosSheet({
    required this.venta,
    this.controladorCuentasPorCobrar,
    this.controladorVentas,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historial de Abonos',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Venta #${venta.id} · ${venta.cliente}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          Expanded(
            child: FutureBuilder<List<Abono>>(
              future: (controladorCuentasPorCobrar ??
                      context.read<ControladorCuentasPorCobrar>())
                  .obtenerAbonosDeVenta(venta.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final abonos = snapshot.data ?? [];
                if (abonos.isEmpty) {
                  return Center(
                    child: Text(
                      'No se han registrado abonos previos para esta cuenta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: abonos.length,
                  itemBuilder: (context, index) {
                    final abono = abonos[index];
                    final fecha =
                        '${abono.fecha.day.toString().padLeft(2, '0')}/${abono.fecha.month.toString().padLeft(2, '0')}/${abono.fecha.year} ${abono.fecha.hour.toString().padLeft(2, '0')}:${abono.fecha.minute.toString().padLeft(2, '0')}';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 0.8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.subtleGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.payment,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    abono.metodoPago,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    fecha,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '+\$${abono.monto.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Comprobante PDF',
                                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                                color: AppColors.primary,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  final comp = ComprobanteAbono(
                                    idAbono: abono.id,
                                    ventaId: venta.id,
                                    cliente: venta.cliente,
                                    totalOriginal: venta.total,
                                    abonoHoy: abono.monto,
                                    saldoRestante: venta.saldoPendiente,
                                    totalPagado: venta.montoPagado,
                                    fecha: abono.fecha,
                                    metodoPago: abono.metodoPago,
                                    liquidado: !venta.tieneSaldoPendiente,
                                  );
                                  await ServicioTicketPdf.instancia.descargarYAbrirComprobanteAbono(
                                    context,
                                    comprobante: comp,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
