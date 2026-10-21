import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../Controladores/controlador_inicio.dart';
import '../Controladores/controlador_inventario.dart';
import '../Controladores/controlador_ventas.dart';
import '../Controladores/controlador_autenticacion.dart';
import '../Tema/app_theme.dart';
import '../Tema/isometric_cube_icon.dart';
import 'pos_vista.dart';
import 'inventario_vista.dart';
import 'perfil.dart';
import 'login.dart';
import 'historial_ventas_vista.dart';

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
  final List<int> _historialTabs = [0];

  void _navegarA(int indice) {
    if (_indiceActual != indice) {
      _historialTabs.add(indice);
      setState(() {
        _indiceActual = indice;
      });
    }
  }

  Future<void> _manejarRegreso() async {
    if (_indiceActual != 0) {
      if (_historialTabs.isNotEmpty && _historialTabs.last == _indiceActual) {
        _historialTabs.removeLast();
      }
      int nuevoIndice = 0;
      if (_historialTabs.isNotEmpty) {
        nuevoIndice = _historialTabs.last;
      } else {
        _historialTabs.add(0);
      }
      setState(() {
        _indiceActual = nuevoIndice;
      });
    } else {
      await _confirmarCerrarSesion();
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final bool? salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Cerrar sesión?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          '¿Estás seguro de que deseas cerrar sesión de Planteapp?',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
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
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (salir == true && mounted) {
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
    }
  }

  List<Widget> _obtenerPaginas() {
    return [
      _VistaDashboard(
        controladorInicio: widget.controladorInicio,
        controladorInventario: widget.controladorInventario,
        controladorVentas: widget.controladorVentas,
        controladorAutenticacion: widget.controladorAutenticacion,
        alNavegar: (indice) {
          _navegarA(indice);
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
    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        final paginas = _obtenerPaginas();
        final productosBajoStock = widget.controladorInventario.productos
            .where((p) => p.esStockCritico)
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

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _manejarRegreso();
          },
          child: Scaffold(
            backgroundColor: AppColors.surface,
            body: SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _manejarRegreso,
                                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                color: AppColors.textPrimary,
                                tooltip: 'Regresar',
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.eco, color: AppColors.primary, size: 28),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            titulo,
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      subtitulo,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: AppColors.card,
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
                                        MediaQuery.of(context).size.height * 0.6,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Notificaciones',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      if (productosBajoStock.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            'No hay alertas de inventario en este momento.',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        )
                                      else
                                        Expanded(
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: productosBajoStock.length,
                                            itemBuilder: (context, index) {
                                              final p = productosBajoStock[index];
                                              return ListTile(
                                                leading: Icon(
                                                  Icons.warning_amber_rounded,
                                                  color: AppColors.warning,
                                                ),
                                                title: Text(
                                                  'Stock Crítico: ${p.nombre}',
                                                  style: TextStyle(
                                                    color: AppColors.textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  'Quedan ${p.cantidadEnInventario} unidades.',
                                                  style: TextStyle(
                                                    color: AppColors.textSecondary,
                                                  ),
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
                          decoration: BoxDecoration(
                            color: AppColors.secondarySurface,
                            shape: BoxShape.circle,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.notifications_none,
                                color: AppColors.textPrimary,
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
                                        color: AppColors.card,
                                        width: 1.5,
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
                          _navegarA(3);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.secondarySurface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_outline,
                            color: AppColors.textPrimary,
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
          color: AppColors.card,
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
                  Icons.view_in_ar_outlined,
                  Icons.view_in_ar_outlined,
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
    ),
  );
},
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
          _navegarA(indice);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: estaActivo
                      ? AppColors.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: indice == 2
                    ? IsometricCubeIcon(
                        size: 22,
                        color: estaActivo
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        strokeWidth: 1.8,
                      )
                    : Icon(
                        estaActivo ? iconoActivo : iconoNormal,
                        color: estaActivo
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 22,
                      ),
              ),
              const SizedBox(height: 3),
              Text(
                etiqueta,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: estaActivo
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: estaActivo ? FontWeight.bold : FontWeight.w500,
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
  String _periodoSeleccionado = 'Hoy';

  @override
  Widget build(BuildContext context) {
    final resumen = widget.controladorInicio.generarResumenDelDia();
    final totalVentas = resumen.ingresosHoy;
    final cantidadVentas = resumen.ventasCompletadasHoy;
    final ticketPromedio =
        cantidadVentas > 0 ? totalVentas / cantidadVentas : 0.0;

    final productosBajoStock = widget.controladorInventario.productos
        .where((p) => p.esStockCritico)
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

    final ventasRecientes = ventasHoy.reversed.take(4).toList();

    final List<Map<String, dynamic>> puntosGrafico = [
      {'hora': '8:00', 'monto': 0.0, 'conteo': 0},
      {'hora': '10:00', 'monto': 0.0, 'conteo': 0},
      {'hora': '12:00', 'monto': 0.0, 'conteo': 0},
      {'hora': '14:00', 'monto': 0.0, 'conteo': 0},
      {'hora': '16:00', 'monto': 0.0, 'conteo': 0},
      {'hora': '18:00', 'monto': 0.0, 'conteo': 0},
    ];

    for (var v in ventasHoy) {
      int hr = v.fecha.hour;
      int idx = -1;
      if (hr < 9) {
        idx = 0;
      } else if (hr < 11) {
        idx = 1;
      } else if (hr < 13) {
        idx = 2;
      } else if (hr < 15) {
        idx = 3;
      } else if (hr < 17) {
        idx = 4;
      } else {
        idx = 5;
      }

      if (idx != -1) {
        puntosGrafico[idx]['monto'] += v.total;
        puntosGrafico[idx]['conteo'] += 1;
      }
    }

    double maxMonto = 0;
    int idxDestacado = 3; // Default 14:00
    for (int i = 0; i < puntosGrafico.length; i++) {
      if (puntosGrafico[i]['monto'] > maxMonto) {
        maxMonto = puntosGrafico[i]['monto'];
        idxDestacado = i;
      }
    }

    final pDestacado = puntosGrafico[idxDestacado];
    final String horaTooltip = pDestacado['hora'];
    final double montoTooltip = pDestacado['monto'];
    final int ventasTooltip = pDestacado['conteo'];

    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Tarjeta principal de ventas del día
              Container(
                decoration: BoxDecoration(
                  color: ThemeManager.instance.isDarkMode ? null : AppColors.card,
                  gradient: ThemeManager.instance.isDarkMode
                      ? AppColors.darkCardGradient
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabecera de la tarjeta: Título, Monto y Selector Hoy / Semana / Mes
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ventas del día',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      Text(
                                        '\$${totalVentas.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.brightGreen,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '+12.5%',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Selector visual Hoy / Semana / Mes (flexible y compacto para no desbordar)
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.secondarySurface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: ['Hoy', 'Semana', 'Mes'].map((opcion) {
                                final bool activa = _periodoSeleccionado == opcion;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _periodoSeleccionado = opcion;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: activa
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      opcion,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: activa
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: activa
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Gráfica de barras táctil con etiqueta flotante sobre la barra seleccionada
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HistorialVentasVista(
                              controladorVentas: widget.controladorVentas,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Column(
                          children: [
                            // Etiqueta flotante con hora, monto y número de ventas
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.darkGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$horaTooltip • \$${montoTooltip.toStringAsFixed(2)} ($ventasTooltip ventas)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 72,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children:
                                    puntosGrafico.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final p = entry.value;
                                  final bool isDestacado = idx == idxDestacado;
                                  double factor = maxMonto > 0
                                      ? (p['monto'] / maxMonto)
                                      : 0.0;
                                  double factorAltura = math.max(0.12, factor);

                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.bottomCenter,
                                              child: FractionallySizedBox(
                                                heightFactor: factorAltura,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: isDestacado
                                                        ? AppColors.brightGreen
                                                        : (ThemeManager.instance.isDarkMode
                                                            ? const Color(0xFF2C2C2E)
                                                            : AppColors.secondarySurface),
                                                    borderRadius:
                                                        const BorderRadius
                                                            .vertical(
                                                      top: Radius.circular(4),
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
                                              color: isDestacado
                                                  ? AppColors.brightGreen
                                                  : AppColors.textSecondary,
                                              fontSize: 9,
                                              fontWeight: isDestacado
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
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
                    ),

                    // Botón de texto "Ver historial >" en la parte inferior derecha de la tarjeta
                    Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HistorialVentasVista(
                                  controladorVentas: widget.controladorVentas,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Ver historial',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Divisor horizontal
                    Divider(height: 1, color: AppColors.border),

                    // Franja plana con divisores verticales para las 3 métricas (solo lectura)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          // Métrica 1: Ventas
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '$cantidadVentas',
                                  style: TextStyle(
                                    color: AppColors.turquoise,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ventas',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
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
                          // Métrica 2: Ticket promedio
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '\$${ticketPromedio.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: AppColors.amber,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ticket prom.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
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
                          // Métrica 3: Stock bajo (solo lectura, sin botón Reponer)
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '${productosBajoStock.length}',
                                  style: TextStyle(
                                    color: productosBajoStock.isNotEmpty
                                        ? AppColors.warning
                                        : AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Stock bajo',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

          const SizedBox(height: 20),

          // Alerta de stock bajo si existen productos en riesgo
          if (productosBajoStock.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.subtleAmber,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.amber.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.subtleAmber,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Alerta: Productos con stock bajo',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
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
                            color: AppColors.amber,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${productosBajoStock.length}',
                            style: const TextStyle(
                              color: Color(0xFF161616),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...productosBajoStock.take(3).map((prod) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.spa_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod.nombre,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${prod.cantidadEnInventario} u. disponibles',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => widget.alNavegar(2),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: AppColors.onWarning,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: const Size(60, 28),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Reponer',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Sección Últimas ventas (con enlace directo a Historial de Ventas)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Últimas ventas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HistorialVentasVista(
                        controladorVentas: widget.controladorVentas,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Ver historial',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: ventasRecientes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 28.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 40,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Aún no hay ventas el día de hoy',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cuando registres una venta, aparecerá aquí.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: ventasRecientes.asMap().entries.map((entry) {
                      int idx = entry.key;
                      var venta = entry.value;
                      int cantidadArticulos = venta.articulos.fold(
                        0,
                        (sum, art) => sum + art.cantidad,
                      );
                      final String folio = venta.id.length > 5
                          ? venta.id.substring(venta.id.length - 5)
                          : venta.id;
                      final String hora =
                          '${venta.fecha.hour.toString().padLeft(2, '0')}:${venta.fecha.minute.toString().padLeft(2, '0')} hrs';

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: idx < ventasRecientes.length - 1
                              ? Border(
                                  bottom: BorderSide(
                                    color: AppColors.border,
                                    width: 0.5,
                                  ),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.subtleGreen,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.payments_outlined,
                                color: AppColors.brightGreen,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Venta #$folio',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '$cantidadArticulos artículos · $hora',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '\$${venta.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: AppColors.brightGreen,
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
          const SizedBox(height: 24),
        ],
      ),
    );
  },
);
}
}
