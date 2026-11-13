import 'package:flutter/material.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_biometrico.dart';
import '../Controladores/controlador_hardware.dart';
import '../Modelos/configuracion_hardware.dart';
import '../Servicios/motor_feedback.dart';

/// Vista modular de Hardware POS (KISS):
/// Tarjeta unificada de impresora térmica ESC/POS con selector por pestañas
/// ("Bluetooth", "WiFi / Red", "Cable USB") y transición animada entre modos.
class HardwareVista extends StatefulWidget {
  final ControladorBiometrico? controladorBiometrico;
  final ControladorHardware? controladorHardware;

  const HardwareVista({
    super.key,
    this.controladorBiometrico,
    this.controladorHardware,
  });

  @override
  State<HardwareVista> createState() => _HardwareVistaState();
}

class _HardwareVistaState extends State<HardwareVista> {
  static final RegExp _regexIpv4 = RegExp(
    r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
  );

  late final ControladorHardware _hardwareCtrl;
  late final TextEditingController _ipController;

  String _tipoConexion = 'bluetooth';
  String _anchoPapelImpresora = '80mm';
  String _impresoraNombre = '';
  String _impresoraMac = '';
  bool _imprimiendoPrueba = false;
  bool _detectandoUsb = false;
  bool _ipEditadaManualmente = false;

  String _normalizarTipo(String tipo) {
    switch (tipo) {
      case 'wifi':
      case 'red':
        return 'wifi';
      case 'usb':
        return 'usb';
      default:
        return 'bluetooth';
    }
  }

  bool _esDireccionIpValida(String valor) {
    final coincidencia = _regexIpv4.firstMatch(valor.trim());
    if (coincidencia == null) return false;
    for (int i = 1; i <= 4; i++) {
      final octeto = int.tryParse(coincidencia.group(i) ?? '');
      if (octeto == null || octeto < 0 || octeto > 255) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _hardwareCtrl = widget.controladorHardware ?? ControladorHardware();
    final hw = _hardwareCtrl.config;
    _tipoConexion = _normalizarTipo(hw.impresoraTipo);
    _anchoPapelImpresora = hw.impresoraAnchoPapel;
    _impresoraNombre = hw.impresoraNombre;
    _impresoraMac = hw.impresoraMac;
    _ipController = TextEditingController(text: hw.wifiHost);

    _hardwareCtrl.addListener(_sincronizarEstadoHardware);
    _cargarConfiguracionHardware();
  }

  void _sincronizarEstadoHardware() {
    if (!mounted) return;
    final hw = _hardwareCtrl.config;
    setState(() {
      _impresoraNombre = hw.impresoraNombre;
      _impresoraMac = hw.impresoraMac;
      _anchoPapelImpresora = hw.impresoraAnchoPapel;
      if (!_ipEditadaManualmente && hw.wifiHost.isNotEmpty) {
        _ipController.text = hw.wifiHost;
      }
    });
  }

  Future<void> _cargarConfiguracionHardware() async {
    await _hardwareCtrl.inicializar();
    if (!mounted) return;

    final hw = _hardwareCtrl.config;
    setState(() {
      _tipoConexion = _normalizarTipo(hw.impresoraTipo);
      _anchoPapelImpresora = hw.impresoraAnchoPapel;
      _impresoraNombre = hw.impresoraNombre;
      _impresoraMac = hw.impresoraMac;
      if (!_ipEditadaManualmente) {
        _ipController.text = hw.wifiHost;
      }
    });
  }

  @override
  void dispose() {
    _hardwareCtrl.removeListener(_sincronizarEstadoHardware);
    _ipController.dispose();
    super.dispose();
  }

  void _mostrarToast(String mensaje, {bool esError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              esError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _actualizarAnchoPapel(String valor) async {
    setState(() => _anchoPapelImpresora = valor);
    final nuevaConfigHw = _hardwareCtrl.config.copyWith(
      impresoraAnchoPapel: valor,
    );
    await _hardwareCtrl.guardarConfiguracion(nuevaConfigHw);
  }

  Future<void> _guardarConfiguracionBluetooth() async {
    final nuevaConfigHw = _hardwareCtrl.config.copyWith(
      impresoraTipo: 'bluetooth',
      impresoraAnchoPapel: _anchoPapelImpresora,
      impresoraNombre: _impresoraNombre,
      impresoraMac: _impresoraMac,
    );
    await _hardwareCtrl.guardarConfiguracion(nuevaConfigHw);
  }

  Future<bool> _guardarConfiguracionWifi({bool mostrarToast = true}) async {
    final ip = _ipController.text.trim();
    if (!_esDireccionIpValida(ip)) {
      MotorFeedback.feedbackError();
      _mostrarToast(
        'Ingresa una dirección IP válida (ej. 192.168.1.100).',
        esError: true,
      );
      return false;
    }

    final nuevaConfigHw = _hardwareCtrl.config.copyWith(
      impresoraTipo: 'wifi',
      wifiHost: ip,
      impresoraAnchoPapel: _anchoPapelImpresora,
      impresoraNombre: 'Impresora WiFi ($ip)',
      impresoraMac: ip,
      impresoraConectada: true,
    );
    await _hardwareCtrl.guardarConfiguracion(nuevaConfigHw);
    _ipEditadaManualmente = false;

    if (mostrarToast) {
      MotorFeedback.feedbackExito();
      _mostrarToast(
        'Impresora WiFi ($ip · $_anchoPapelImpresora) guardada con éxito.',
      );
    }
    return true;
  }

  Future<void> _iniciarBusquedaImpresora() async {
    if (_hardwareCtrl.escaneandoImpresoras) return;

    final diagnosticoBt =
        await _hardwareCtrl.verificarPermisosYEstadoBluetooth();
    if (!diagnosticoBt['permisos']) {
      if (mounted) {
        MotorFeedback.feedbackError();
        _mostrarToast(
          diagnosticoBt['mensaje'] ??
              'Permiso de "Dispositivos Cercanos" o "Ubicación" denegado. Concédelo en Ajustes para detectar impresoras.',
          esError: true,
        );
      }
      return;
    }

    if (!diagnosticoBt['encendido']) {
      if (mounted) {
        MotorFeedback.feedbackError();
        _mostrarToast(
          'El adaptador Bluetooth está apagado en este dispositivo. Por favor actívalo para buscar impresoras.',
          esError: true,
        );
      }
      return;
    }

    final impresoras = await _hardwareCtrl.escanearImpresorasBluetooth();
    if (!mounted) return;

    if (impresoras.isEmpty) {
      _mostrarToast(
        'No se detectaron impresoras Bluetooth vinculadas. Asegúrate de encender tu impresora y vincularla en Ajustes.',
        esError: true,
      );
      return;
    }

    final DispositivoImpresora? seleccionada =
        await showModalBottomSheet<DispositivoImpresora>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => ModalSeleccionImpresoraBluetooth(
        controladorHardware: _hardwareCtrl,
        impresoras: impresoras,
      ),
    );

    if (seleccionada != null && mounted) {
      setState(() {
        _impresoraNombre = seleccionada.nombre;
        _impresoraMac = seleccionada.macOUrl;
      });
      await _guardarConfiguracionBluetooth();
      _mostrarToast(
        'Impresora "${seleccionada.nombre}" conectada y guardada con éxito.',
      );
    }
  }

  Future<void> _ejecutarTicketPrueba({
    required String mensajeExito,
    String? mensajeError,
  }) async {
    if (!mounted) return;
    setState(() => _imprimiendoPrueba = true);
    final exito = await _hardwareCtrl.imprimirTicketPrueba(context: context);
    if (!mounted) return;
    setState(() => _imprimiendoPrueba = false);

    if (exito) {
      MotorFeedback.feedbackExito();
      _mostrarToast(mensajeExito);
    } else if (mensajeError != null) {
      MotorFeedback.feedbackError();
      _mostrarToast(mensajeError, esError: true);
    }
  }

  Future<void> _probarImpresionBluetooth() async {
    final bool btConectada = _hardwareCtrl.config.impresoraConectada &&
        _normalizarTipo(_hardwareCtrl.config.impresoraTipo) == 'bluetooth';
    if (!btConectada) {
      _mostrarToast(
        'Debes conectar una impresora térmica Bluetooth antes de imprimir la prueba.',
        esError: true,
      );
      return;
    }

    await _guardarConfiguracionBluetooth();
    await _ejecutarTicketPrueba(
      mensajeExito:
          'Ticket de prueba enviado a la impresora térmica ($_anchoPapelImpresora).',
    );
  }

  Future<void> _probarImpresionWifi() async {
    final guardada = await _guardarConfiguracionWifi(mostrarToast: false);
    if (!guardada) return;

    final ip = _ipController.text.trim();
    await _ejecutarTicketPrueba(
      mensajeExito:
          'Ticket de prueba enviado por WiFi ($ip · $_anchoPapelImpresora).',
      mensajeError:
          'No se pudo conectar con la impresora WiFi ($ip:9100). Verifica la IP y que esté encendida.',
    );
  }

  Future<void> _detectarImpresoraUsb() async {
    if (_detectandoUsb) return;
    setState(() => _detectandoUsb = true);

    final detectadas = await _hardwareCtrl.escanearImpresorasUsb();
    if (!mounted) return;
    setState(() => _detectandoUsb = false);

    if (detectadas.isEmpty) {
      MotorFeedback.feedbackError();
      _mostrarToast(
        'No se detectó ninguna impresora conectada por cable OTG/USB.',
        esError: true,
      );
      return;
    }

    final imp = detectadas.firstWhere(
      (d) => d.esPredeterminada,
      orElse: () => detectadas.first,
    );
    await _hardwareCtrl.vincularImpresora(imp);
    if (!mounted) return;
    MotorFeedback.feedbackExito();
    _mostrarToast(
      'Impresora USB "${imp.nombre}" detectada y conectada.',
    );
  }

  Widget _buildAnchoChip(String valor, String label) {
    final bool seleccionado = _anchoPapelImpresora == valor;
    return InkWell(
      onTap: () => _actualizarAnchoPapel(valor),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: seleccionado ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: seleccionado ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: seleccionado ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorAnchoRollo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.straighten_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Ancho de Rollo',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAnchoChip('58mm', '58 mm'),
              const SizedBox(width: 8),
              _buildAnchoChip('80mm', '80 mm'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotonAccion({
    required String etiqueta,
    required IconData icono,
    required VoidCallback? onPressed,
    bool cargando = false,
    double alto = 46,
    bool secundario = false,
  }) {
    final bool habilitado = onPressed != null;
    final Color fondo = secundario
        ? AppColors.secondarySurface
        : (habilitado ? AppColors.primary : AppColors.secondarySurface);
    final Color primerPlano = secundario
        ? AppColors.textPrimary
        : (habilitado ? Colors.white : AppColors.textSecondary);

    return SizedBox(
      height: alto,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: cargando
            ? SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primerPlano,
                ),
              )
            : Icon(icono, size: 17),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            etiqueta,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: primerPlano,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: fondo,
          foregroundColor: primerPlano,
          disabledBackgroundColor: AppColors.secondarySurface,
          disabledForegroundColor: AppColors.textSecondary,
          elevation: 0,
          side: secundario ? BorderSide(color: AppColors.border) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorModoImpresora() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<String>(
                  value: 'bluetooth',
                  icon: Icon(Icons.bluetooth, size: 15),
                  label: Text('Bluetooth', maxLines: 1, softWrap: false),
                ),
                ButtonSegment<String>(
                  value: 'wifi',
                  icon: Icon(Icons.wifi, size: 15),
                  label: Text('WiFi / Red', maxLines: 1, softWrap: false),
                ),
                ButtonSegment<String>(
                  value: 'usb',
                  icon: Icon(Icons.usb_rounded, size: 15),
                  label: Text('Cable USB', maxLines: 1, softWrap: false),
                ),
              ],
              selected: <String>{_tipoConexion},
              onSelectionChanged: (seleccion) {
                if (seleccion.isEmpty) return;
                final nuevoModo = seleccion.first;
                if (nuevoModo != _tipoConexion) {
                  MotorFeedback.seleccion();
                  setState(() => _tipoConexion = nuevoModo);
                }
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primary;
                  }
                  return AppColors.secondarySurface;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return AppColors.textPrimary;
                }),
                side: WidgetStateProperty.all(
                  BorderSide(color: AppColors.border, width: 1),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVistaBluetooth(bool conectada) {
    final bool tieneBtVinculada =
        _normalizarTipo(_hardwareCtrl.config.impresoraTipo) == 'bluetooth' &&
            _impresoraMac.isNotEmpty;

    return Column(
      key: const ValueKey<String>('vista_bluetooth'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Estado de conexión
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: conectada
                    ? AppColors.subtleGreen
                    : (tieneBtVinculada
                        ? AppColors.primaryContainer
                        : AppColors.secondarySurface),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.print_outlined,
                color: conectada
                    ? AppColors.brightGreen
                    : (tieneBtVinculada
                        ? AppColors.primary
                        : AppColors.textSecondary),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tieneBtVinculada && _impresoraNombre.isNotEmpty
                        ? _impresoraNombre
                        : 'Sin Impresora Vinculada',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tieneBtVinculada
                        ? 'MAC: $_impresoraMac · Bluetooth'
                        : 'Empareja tu impresora Bluetooth para emitir tickets.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: conectada
                    ? AppColors.subtleGreen
                    : AppColors.secondarySurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: conectada ? AppColors.brightGreen : AppColors.border,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: conectada
                          ? AppColors.brightGreen
                          : AppColors.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    conectada ? 'Conectada' : 'Desconectada',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: conectada
                          ? AppColors.brightGreen
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Ancho de rollo
        _buildSelectorAnchoRollo(),
        const SizedBox(height: 16),

        // 3. Botón Buscar Impresora
        _buildBotonAccion(
          etiqueta: _hardwareCtrl.escaneandoImpresoras
              ? 'Buscando...'
              : 'Buscar Impresora',
          icono: Icons.bluetooth_searching,
          cargando: _hardwareCtrl.escaneandoImpresoras,
          alto: 48,
          onPressed: _hardwareCtrl.escaneandoImpresoras
              ? null
              : _iniciarBusquedaImpresora,
        ),
        const SizedBox(height: 10),

        // 4. Botón Ticket Prueba
        _buildBotonAccion(
          etiqueta: _imprimiendoPrueba ? 'Imprimiendo...' : 'Ticket Prueba',
          icono: Icons.receipt_long,
          cargando: _imprimiendoPrueba,
          alto: 44,
          onPressed:
              (conectada && !_imprimiendoPrueba) ? _probarImpresionBluetooth : null,
        ),
      ],
    );
  }

  Widget _buildVistaWifi() {
    return Column(
      key: const ValueKey<String>('vista_wifi'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Campo único: Dirección IP
        TextField(
          controller: _ipController,
          onChanged: (_) => _ipEditadaManualmente = true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Dirección IP',
            hintText: 'Ej. 192.168.1.100',
            labelStyle: TextStyle(color: AppColors.textSecondary),
            prefixIcon: Icon(Icons.wifi, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: AppColors.secondarySurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Ancho de rollo
        _buildSelectorAnchoRollo(),
        const SizedBox(height: 16),

        // 3. Botones de Guardar y Ticket Prueba
        Row(
          children: [
            Expanded(
              child: _buildBotonAccion(
                etiqueta: 'Guardar',
                icono: Icons.save_outlined,
                secundario: true,
                onPressed:
                    _imprimiendoPrueba ? null : () => _guardarConfiguracionWifi(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBotonAccion(
                etiqueta:
                    _imprimiendoPrueba ? 'Probando...' : 'Ticket Prueba',
                icono: Icons.receipt_long,
                cargando: _imprimiendoPrueba,
                onPressed: _imprimiendoPrueba ? null : _probarImpresionWifi,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVistaUsb() {
    return Column(
      key: const ValueKey<String>('vista_usb'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.secondarySurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(
                Icons.usb_rounded,
                size: 32,
                color: AppColors.primary,
              ),
              const SizedBox(height: 10),
              Text(
                'Conecta el cable OTG/USB de la impresora',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildBotonAccion(
          etiqueta: _detectandoUsb ? 'Detectando...' : 'Detectar Impresora',
          icono: Icons.usb_rounded,
          cargando: _detectandoUsb,
          alto: 48,
          onPressed: _detectandoUsb ? null : _detectarImpresoraUsb,
        ),
      ],
    );
  }

  Widget _buildSubVistaActiva(bool conectadaModoActual) {
    switch (_tipoConexion) {
      case 'wifi':
        return _buildVistaWifi();
      case 'usb':
        return _buildVistaUsb();
      case 'bluetooth':
      default:
        return _buildVistaBluetooth(conectadaModoActual);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool conectadaModoActual = _hardwareCtrl.config.impresoraConectada &&
        _normalizarTipo(_hardwareCtrl.config.impresoraTipo) == _tipoConexion;

    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            title: Text(
              'Hardware y Periféricos',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            backgroundColor: AppColors.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: conectadaModoActual
                          ? AppColors.subtleGreen.withValues(alpha: 0.22)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: conectadaModoActual
                            ? AppColors.brightGreen.withValues(alpha: 0.6)
                            : AppColors.border,
                        width: conectadaModoActual ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'IMPRESORA TÉRMICA DE TICKETS (ESC/POS)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSelectorModoImpresora(),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                ...previousChildren,
                                ?currentChild,
                              ],
                            );
                          },
                          child: _buildSubVistaActiva(conectadaModoActual),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Modal BottomSheet elegante para la selección y conexión de impresoras térmicas Bluetooth
class ModalSeleccionImpresoraBluetooth extends StatefulWidget {
  final ControladorHardware controladorHardware;
  final List<DispositivoImpresora> impresoras;

  const ModalSeleccionImpresoraBluetooth({
    super.key,
    required this.controladorHardware,
    required this.impresoras,
  });

  @override
  State<ModalSeleccionImpresoraBluetooth> createState() =>
      _ModalSeleccionImpresoraBluetoothState();
}

class _ModalSeleccionImpresoraBluetoothState
    extends State<ModalSeleccionImpresoraBluetooth> {
  String? _conectandoMac;

  Future<void> _conectar(DispositivoImpresora imp) async {
    setState(() => _conectandoMac = imp.macOUrl);

    final bool exito = await widget.controladorHardware.conectarImpresora(
      macAddress: imp.macOUrl,
      nombre: imp.nombre,
    );

    if (!mounted) return;

    if (exito) {
      Navigator.pop(context, imp);
    } else {
      setState(() => _conectandoMac = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No fue posible conectar con "${imp.nombre}". Verifica que esté encendida.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.subtleGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.print_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Impresoras Bluetooth Encontradas',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Toca tu impresora térmica para vincular y conectar',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textSecondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.impresoras.length,
                separatorBuilder: (_, __) =>
                    Divider(color: AppColors.border, height: 1),
                itemBuilder: (context, idx) {
                  final imp = widget.impresoras[idx];
                  final bool conectandoEste = _conectandoMac == imp.macOUrl;
                  final bool esLaConectada =
                      widget.controladorHardware.config.impresoraConectada &&
                      widget.controladorHardware.config.impresoraMac ==
                          imp.macOUrl;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: esLaConectada
                            ? AppColors.subtleGreen
                            : AppColors.secondarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bluetooth,
                        color: esLaConectada
                            ? AppColors.brightGreen
                            : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      imp.nombre,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'MAC: ${imp.macOUrl}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: conectandoEste
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : esLaConectada
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.subtleGreen,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.brightGreen,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 14,
                                  color: AppColors.brightGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Conectada',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.brightGreen,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ElevatedButton(
                            onPressed: _conectandoMac != null
                                ? null
                                : () => _conectar(imp),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Conectar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    onTap: _conectandoMac != null ? null : () => _conectar(imp),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo modal interactivo para escaneo y conexión en tiempo real de impresoras Bluetooth ESC/POS
class DialogoBuscarImpresoraBluetooth extends StatefulWidget {
  final ControladorHardware controladorHardware;

  const DialogoBuscarImpresoraBluetooth({
    super.key,
    required this.controladorHardware,
  });

  @override
  State<DialogoBuscarImpresoraBluetooth> createState() =>
      _DialogoBuscarImpresoraBluetoothState();
}

class _DialogoBuscarImpresoraBluetoothState
    extends State<DialogoBuscarImpresoraBluetooth> {
  bool _cargando = true;
  String? _conectandoMac;
  String? _error;
  List<DispositivoImpresora> _impresoras = [];

  @override
  void initState() {
    super.initState();
    _iniciarEscaneo();
  }

  Future<void> _iniciarEscaneo() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final diagnosticoBt = await widget.controladorHardware
          .verificarPermisosYEstadoBluetooth();
      if (!diagnosticoBt['encendido']) {
        if (mounted) {
          setState(() {
            _cargando = false;
            _error = 'El adaptador Bluetooth está apagado en este dispositivo. Por favor enciéndelo e intenta nuevamente.';
          });
        }
        return;
      }

      final lista = await widget.controladorHardware
          .escanearImpresorasBluetooth();

      if (mounted) {
        setState(() {
          _impresoras = lista;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = 'Ocurrió un error al buscar impresoras: $e';
        });
      }
    }
  }

  Future<void> _conectar(DispositivoImpresora imp) async {
    setState(() => _conectandoMac = imp.macOUrl);

    final bool exito = await widget.controladorHardware.conectarImpresora(
      macAddress: imp.macOUrl,
      nombre: imp.nombre,
    );

    if (!mounted) return;

    if (exito) {
      Navigator.pop(context, imp);
    } else {
      setState(() => _conectandoMac = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No fue posible enlazar con "${imp.nombre}". Verifica que esté encendida.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.subtleGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bluetooth_searching,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buscar Impresora',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'Térmica ESC/POS Bluetooth',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: AppColors.textSecondary,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      content: SizedBox(width: double.maxFinite, child: _buildContenido()),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        if (!_cargando)
          TextButton.icon(
            onPressed: _iniciarEscaneo,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Volver a Escanear'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cerrar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildContenido() {
    if (_cargando) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
            const SizedBox(height: 20),
            Text(
              'Buscando impresoras Bluetooth...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Solicitando permisos y escaneando dispositivos cercanos...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bluetooth_disabled_rounded,
              size: 44,
              color: AppColors.amber,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ],
        ),
      );
    }

    if (_impresoras.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.print_disabled_outlined,
              size: 44,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'No se detectaron impresoras Bluetooth vinculadas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enciende tu impresora térmica y asegúrate de vincularla en los Ajustes de Bluetooth de tu teléfono o PC (PIN habitual: 0000 o 1234).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Impresoras encontradas (${_impresoras.length}):',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _impresoras.length,
            separatorBuilder: (_, __) =>
                Divider(color: AppColors.border, height: 1),
            itemBuilder: (context, idx) {
              final imp = _impresoras[idx];
              final bool conectandoEste = _conectandoMac == imp.macOUrl;
              final bool esLaConectada =
                  widget.controladorHardware.config.impresoraConectada &&
                  widget.controladorHardware.config.impresoraMac == imp.macOUrl;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: esLaConectada
                        ? AppColors.subtleGreen
                        : AppColors.secondarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bluetooth,
                    color: esLaConectada
                        ? AppColors.brightGreen
                        : AppColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  imp.nombre,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'MAC: ${imp.macOUrl}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: conectandoEste
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : esLaConectada
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.subtleGreen,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.brightGreen,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check,
                              size: 14,
                              color: AppColors.brightGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Conectada',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brightGreen,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _conectandoMac != null
                            ? null
                            : () => _conectar(imp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Conectar',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                onTap: _conectandoMac != null ? null : () => _conectar(imp),
              );
            },
          ),
        ),
      ],
    );
  }
}
