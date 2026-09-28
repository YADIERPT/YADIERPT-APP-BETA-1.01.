import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:math' as math;

import '../Controladores/controlador_inicio.dart';
import '../Controladores/controlador_inventario.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_autenticacion.dart';
import '../Tema/app_theme.dart';
import 'pos_vista.dart';
import 'inventario_vista.dart';
import 'perfil.dart';
import 'login.dart';

class InicioVista extends StatefulWidget {
  final ControladorInicio controladorInicio;
  final ControladorInventario controladorInventario;
  final ControladorVentas controladorVentas;
  final ControladorAutenticacion controladorAutenticacion;

  const InicioVista({
    super.key,
    required this.controladorInicio,
    required this.controladorInventario,
    required this.controladorVentas,
    required this.controladorAutenticacion,
  });

  @override
  State<InicioVista> createState() => _InicioVistaState();
}

class _InicioVistaState extends State<InicioVista> {
  int _indiceActual = 0;
  late final List<Widget> paginas;

  @override
  void initState() {
    super.initState();
    paginas = [
      _VistaDashboard(
        controladorInicio: widget.controladorInicio,
        controladorInventario: widget.controladorInventario,
        controladorVentas: widget.controladorVentas,
        controladorAutenticacion: widget.controladorAutenticacion,
        alNavegar: (indice) {
          setState(() {
            _indiceActual = indice;
          });
        },
      ),
      PosVista(
        controladorInicio: widget.controladorInicio,
        controladorInventario: widget.controladorInventario,
        controladorVentas: widget.controladorVentas,
      ),
      InventarioVista(controladorInventario: widget.controladorInventario),
      PerfilVista(
        controladorPerfil: widget.controladorInicio.controladorPerfil,
        controladorVentas: widget.controladorVentas,
        controladorAutenticacion: widget.controladorAutenticacion,
        onLogout: () {
          widget.controladorAutenticacion.cerrarSesion();
          Navigator.of(context, rootNavigator: true).pushReplacement(
            MaterialPageRoute(
              builder: (context) => LoginVista(
                controladorInicio: widget.controladorInicio,
                controladorInventario: widget.controladorInventario,
                controladorVentas: widget.controladorVentas,
                controladorAutenticacion: widget.controladorAutenticacion,
              ),
            ),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final productosBajoStock = widget.controladorInventario.productos
        .where((p) => p.cantidadEnInventario <= 5)
        .toList();

    String titulo = 'Inicio';
    String subtitulo = 'Vivero';
    if (_indiceActual == 0) {
      titulo = 'Inicio';
      subtitulo = 'Resumen General';
    } else if (_indiceActual == 1) {
      titulo = 'Punto de Venta';
      subtitulo = 'Vivero';
    } else if (_indiceActual == 2) {
      titulo = 'Inventario';
      subtitulo = 'Control Botánico';
    } else if (_indiceActual == 3) {
      titulo = 'Mi Cuenta';
      subtitulo = 'Configuración';
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.eco, color: AppColors.primary, size: 28),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                titulo,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            subtitulo,
                            style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: AppColors.surfaceContainerLowest,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                            ),
                            builder: (context) {
                              return SafeArea(
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  constraints: BoxConstraints(
                                    maxHeight:
                                        MediaQuery.of(context).size.height *
                                        0.6,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Notificaciones',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      if (productosBajoStock.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: Text(
                                            'No hay alertas de inventario en este momento.',
                                            style: TextStyle(
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                          ),
                                        )
                                      else
                                        Expanded(
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount:
                                                productosBajoStock.length,
                                            itemBuilder: (context, index) {
                                              final p =
                                                  productosBajoStock[index];
                                              return ListTile(
                                                leading: const Icon(
                                                  Icons.warning_amber,
                                                  color: AppColors.secondary,
                                                ),
                                                title: Text(
                                                  'Stock Crítico: ${p.nombre}',
                                                ),
                                                subtitle: Text(
                                                  'Quedan ${p.cantidadEnInventario} unidades.',
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.notifications_none,
                                color: AppColors.onSurface,
                                size: 20,
                              ),
                              if (productosBajoStock.isNotEmpty)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.surfaceContainerHigh,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _indiceActual = 3;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: AppColors.onSurface,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(index: _indiceActual, children: paginas),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(
            top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.5)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(Icons.home_outlined, Icons.home, 'Inicio', 0),
                _buildTabItem(
                  Icons.shopping_cart_outlined,
                  Icons.shopping_cart,
                  'Ventas',
                  1,
                ),
                _buildTabItem(
                  Icons.inventory_2_outlined,
                  Icons.inventory_2,
                  'Inventario',
                  2,
                ),
                _buildTabItem(
                  Icons.person_outline,
                  Icons.person,
                  'Mi Cuenta',
                  3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(
    IconData iconoNormal,
    IconData iconoActivo,
    String etiqueta,
    int indice,
  ) {
    bool estaActivo = _indiceActual == indice;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _indiceActual = indice;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: estaActivo
                      ? AppColors.primary.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  estaActivo ? iconoActivo : iconoNormal,
                  color: estaActivo
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                etiqueta,
                style: TextStyle(
                  color: estaActivo
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: estaActivo ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VistaDashboard extends StatefulWidget {
  final ControladorInicio controladorInicio;
  final ControladorInventario controladorInventario;
  final ControladorVentas controladorVentas;
  final ControladorAutenticacion controladorAutenticacion;
  final Function(int) alNavegar;

  const _VistaDashboard({
    required this.controladorInicio,
    required this.controladorInventario,
    required this.controladorVentas,
    required this.controladorAutenticacion,
    required this.alNavegar,
  });

  @override
  State<_VistaDashboard> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_VistaDashboard> {
  late String fechaActualFormateada;

  @override
  void initState() {
    super.initState();
    _formatDate();
  }

  void _formatDate() {
    final ahora = DateTime.now();
    final dias = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];

    final diaSemana = dias[ahora.weekday - 1];
    final mes = meses[ahora.month - 1];
    final hr = ahora.hour.toString().padLeft(2, '0');
    final min = ahora.minute.toString().padLeft(2, '0');

    fechaActualFormateada = "$diaSemana, ${ahora.day} $mes · $hr:$min";
  }

  @override
  Widget build(BuildContext context) {
    final resumen = widget.controladorInicio.generarResumenDelDia();
    final totalVentas = resumen.ingresosHoy;
    final cantidadVentas = resumen.ventasCompletadasHoy;
    final ticketPromedio = cantidadVentas > 0
        ? totalVentas / cantidadVentas
        : 0.0;

    final productosBajoStock = widget.controladorInventario.productos
        .where((p) => p.cantidadEnInventario <= 5)
        .toList();

    final hoy = DateTime.now();
    final ventasHoy = widget.controladorVentas.ventas
        .where(
          (v) =>
              v.fecha.year == hoy.year &&
              v.fecha.month == hoy.month &&
              v.fecha.day == hoy.day,
        )
        .toList();

    final ventasRecientes = ventasHoy.reversed.take(3).toList();
    final List<Map<String, dynamic>> puntosGrafico = [
      {'hora': '8am', 'monto': 0.0},
      {'hora': '9am', 'monto': 0.0},
      {'hora': '10am', 'monto': 0.0},
      {'hora': '11am', 'monto': 0.0},
      {'hora': '12pm', 'monto': 0.0},
      {'hora': '1pm', 'monto': 0.0},
      {'hora': '2pm', 'monto': 0.0},
      {'hora': '3pm', 'monto': 0.0},
    ];

    for (var v in ventasHoy) {
      int hr = v.fecha.hour;
      int idx = -1;
      if (hr == 8)
        idx = 0;
      else if (hr == 9)
        idx = 1;
      else if (hr == 10)
        idx = 2;
      else if (hr == 11)
        idx = 3;
      else if (hr == 12)
        idx = 4;
      else if (hr == 13)
        idx = 5;
      else if (hr == 14)
        idx = 6;
      else if (hr >= 15)
        idx = 7;

      if (idx != -1) {
        puntosGrafico[idx]['monto'] += v.total;
      }
    }

    double maxMonto = 0;
    for (var p in puntosGrafico) {
      if (p['monto'] > maxMonto) maxMonto = p['monto'];
    }

    final nombreUsuario =
        widget.controladorAutenticacion.usuarioActual?.nombre.split(' ')[0] ??
        "Usuario";
    final inicialUsuario = nombreUsuario.isNotEmpty
        ? nombreUsuario[0].toUpperCase()
        : "U";

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          children: [
            Container(
              color: AppColors.primary,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fechaActualFormateada,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Buenos días, $nombreUsuario 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 80, height: 36),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ventas hoy',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '\$${totalVentas.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.trending_up,
                                    color: Colors.greenAccent,
                                    size: 12,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '+18.4%',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 64,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: puntosGrafico.map((p) {
                              double porcentaje = maxMonto > 0
                                  ? (p['monto'] / maxMonto)
                                  : 0.0;
                              double factorAltura = p['monto'] > 0
                                  ? math.max(0.1, porcentaje)
                                  : 0.05;
                              bool isMax =
                                  p['monto'] == maxMonto && maxMonto > 0;

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: FractionallySizedBox(
                                            heightFactor: factorAltura,
                                            child: Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: isMax
                                                    ? AppColors.secondary
                                                    : Colors.white.withOpacity(
                                                        0.3,
                                                      ),
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(3),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        p['hora'],
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$cantidadVentas',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Ventas',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '\$${ticketPromedio.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Ticket prom.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${productosBajoStock.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Stock bajo',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (productosBajoStock.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.outlineVariant.withOpacity(0.3),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFFFE082)),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Stock bajo',
                                    style: TextStyle(
                                      color: AppColors.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${productosBajoStock.length}',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...productosBajoStock.take(3).map((prod) {
                            double porcentajeStock =
                                (prod.cantidadEnInventario / 10.0).clamp(
                                  0.0,
                                  1.0,
                                );
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: AppColors.outlineVariant.withOpacity(
                                      0.3,
                                    ),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: prod.imagenes.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              prod.imagenes.first,
                                              fit: BoxFit.cover,
                                              errorBuilder: (c, e, s) =>
                                                  const Icon(
                                                    Icons.local_florist,
                                                    color:
                                                        AppColors.surfaceTint,
                                                    size: 16,
                                                  ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.local_florist,
                                            color: AppColors.surfaceTint,
                                            size: 16,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prod.nombre,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade300,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                                child: FractionallySizedBox(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  widthFactor: porcentajeStock,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.redAccent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            2,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${prod.cantidadEnInventario} ud.',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  InkWell(
                                    onTap: () => widget.alNavegar(2),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.primary.withOpacity(
                                            0.3,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Reponer',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  const Text(
                    'ACCESOS RÁPIDOS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.outline,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => widget.alNavegar(1),
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.point_of_sale,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Punto de Venta',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Cobrar ahora',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => widget.alNavegar(2),
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.inventory_2,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Inventario',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${widget.controladorInventario.productos.length} productos',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ÚLTIMAS VENTAS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.outline,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: ventasRecientes.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                'No hay ventas registradas hoy',
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            children: ventasRecientes.asMap().entries.map((
                              entry,
                            ) {
                              int idx = entry.key;
                              var venta = entry.value;
                              int cantidadArticulos = venta.articulos.fold(
                                0,
                                (sum, art) => sum + art.cantidad,
                              );
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: idx < ventasRecientes.length - 1
                                      ? Border(
                                          bottom: BorderSide(
                                            color: AppColors.outlineVariant
                                                .withOpacity(0.3),
                                          ),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainer,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.payments_outlined,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Venta #${venta.id.substring(venta.id.length > 5 ? venta.id.length - 5 : 0)}',
                                            style: const TextStyle(
                                              color: AppColors.onSurface,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '$cantidadArticulos artículos · ${venta.fecha.hour.toString().padLeft(2, '0')}:${venta.fecha.minute.toString().padLeft(2, '0')} hrs',
                                            style: const TextStyle(
                                              color: AppColors.onSurfaceVariant,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '\$${venta.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: AppColors.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
