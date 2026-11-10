import 'package:flutter/material.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_biometrico.dart';
import '../Controladores/controlador_hardware.dart';
import '../Modelos/configuracion_hardware.dart';
import '../Servicios/servicio_biometrico.dart';

/// Vista de Hardware y Periféricos 100% Funcional (IoT / POS):
/// Conecta con lectores biométricos (Sensor nativo local_auth, WiFi TCP Socket, Bluetooth, Cable USB Serial)
/// y gestiona el escaneo, enlace y prueba de impresoras térmicas ESC/POS (58mm y 80mm).
class HardwareVista extends StatefulWidget {
  final ControladorBiometrico controladorBiometrico;
  final ControladorHardware? controladorHardware;

  const HardwareVista({
    super.key,
    required this.controladorBiometrico,
    this.controladorHardware,
  });

  @override
  State<HardwareVista> createState() => _HardwareVistaState();
}

class _HardwareVistaState extends State<HardwareVista> {
  late ControladorHardware _hardwareCtrl;

  // Controladores de texto para lector biométrico
  late TextEditingController _wifiHostCtrl;
  late TextEditingController _wifiPuertoCtrl;
  late TextEditingController _btDispositivoCtrl;
  late TextEditingController _cablePuertoCtrl;

  late String _tipoConexion;
  late int _cableBaudRate;

  bool _probandoConexion = false;
  ResultadoConexionHardware? _ultimoResultado;

  // Estado para la impresora térmica
  late String _tipoConexionImpresora;
  late String _anchoPapelImpresora;
  String _impresoraNombre = '';
  String _impresoraMac = '';
  bool _imprimiendoPrueba = false;

  @override
  void initState() {
    super.initState();
    _hardwareCtrl = widget.controladorHardware ?? ControladorHardware();

    final bioCfg = widget.controladorBiometrico.config;
    _wifiHostCtrl = TextEditingController(text: bioCfg.wifiHost);
    _wifiPuertoCtrl = TextEditingController(text: bioCfg.wifiPuerto.toString());
    _btDispositivoCtrl = TextEditingController(text: bioCfg.bluetoothDispositivo);
    _cablePuertoCtrl = TextEditingController(text: bioCfg.cablePuertoSerial);
    _tipoConexion = bioCfg.tipoConexion;
    _cableBaudRate = bioCfg.cableBaudRate;

    _tipoConexionImpresora = 'bluetooth';
    _anchoPapelImpresora = '80mm';

    _hardwareCtrl.addListener(_sincronizarEstadoHardware);
    _cargarConfiguracionHardware();
  }

  void _sincronizarEstadoHardware() {
    if (mounted) {
      setState(() {
        _impresoraNombre = _hardwareCtrl.config.impresoraNombre;
        _impresoraMac = _hardwareCtrl.config.impresoraMac;
        _tipoConexionImpresora = _hardwareCtrl.config.impresoraTipo;
        _anchoPapelImpresora = _hardwareCtrl.config.impresoraAnchoPapel;
      });
    }
  }

  Future<void> _cargarConfiguracionHardware() async {
    await _hardwareCtrl.inicializar();
    if (!mounted) return;

    final hw = _hardwareCtrl.config;
    setState(() {
      _tipoConexionImpresora = hw.impresoraTipo;
      _anchoPapelImpresora = hw.impresoraAnchoPapel;
      _impresoraNombre = hw.impresoraNombre;
      _impresoraMac = hw.impresoraMac;
      if (hw.tipoLector.isNotEmpty) {
        _tipoConexion = hw.tipoLector;
      }
    });
  }

  @override
  void dispose() {
    _hardwareCtrl.removeListener(_sincronizarEstadoHardware);
    _wifiHostCtrl.dispose();
    _wifiPuertoCtrl.dispose();
    _btDispositivoCtrl.dispose();
    _cablePuertoCtrl.dispose();
    super.dispose();
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

  // =========================================================================
  // PRUEBA REAL DE CONEXIÓN DEL LECTOR
  // =========================================================================

  Future<void> _probarConexionLector() async {
    setState(() {
      _probandoConexion = true;
      _ultimoResultado = null;
    });

    ResultadoConexionHardware resultado;

    switch (_tipoConexion) {
      case 'local':
        // 1. Diagnóstico real del sensor nativo con local_auth y prompt de huella
        resultado = await _hardwareCtrl.probarLectorNativo();
        break;

      case 'wifi':
        // 2. Detección de red activa y verificación de Socket TCP
        final int puerto = int.tryParse(_wifiPuertoCtrl.text.trim()) ?? 4370;
        resultado = await _hardwareCtrl.probarConexionWifi(
          host: _wifiHostCtrl.text.trim(),
          puerto: puerto,
        );
        break;

      case 'bluetooth':
        // 3. Solicitud de permisos Bluetooth (BLUETOOTH_SCAN/CONNECT) y verificación
        resultado = await _hardwareCtrl.probarConexionBluetooth(
          dispositivo: _btDispositivoCtrl.text.trim(),
        );
        break;

      case 'cable':
      default:
        // 4. Diagnóstico de puerto serial y baud rate
        resultado = await _hardwareCtrl.probarConexionCable(
          puertoSerial: _cablePuertoCtrl.text.trim(),
          baudRate: _cableBaudRate,
        );
        break;
    }

    if (mounted) {
      setState(() {
        _probandoConexion = false;
        _ultimoResultado = resultado;
      });

      _mostrarToast(
        resultado.mensaje,
        esError: !resultado.exito,
      );

      // Si fue exitosa, guarda automáticamente el estado
      if (resultado.exito) {
        await _guardarConfiguracion(notificar: false);
      }
    }
  }

  Future<void> _guardarConfiguracion({bool notificar = true}) async {
    final int puerto = int.tryParse(_wifiPuertoCtrl.text.trim()) ?? 4370;

    // Guarda en el modelo de hardware completo
    final nuevaConfigHw = _hardwareCtrl.config.copyWith(
      tipoLector: _tipoConexion,
      wifiHost: _wifiHostCtrl.text.trim(),
      wifiPuerto: puerto,
      bluetoothDispositivo: _btDispositivoCtrl.text.trim(),
      cablePuertoSerial: _cablePuertoCtrl.text.trim(),
      cableBaudRate: _cableBaudRate,
      impresoraTipo: _tipoConexionImpresora,
      impresoraAnchoPapel: _anchoPapelImpresora,
      impresoraNombre: _impresoraNombre,
      impresoraMac: _impresoraMac,
    );

    await _hardwareCtrl.guardarConfiguracion(nuevaConfigHw);

    // Guarda en retrocompatibilidad con el controlador biométrico
    final bioConfig = widget.controladorBiometrico.config.copyWith(
      tipoConexion: _tipoConexion,
      wifiHost: _wifiHostCtrl.text.trim(),
      wifiPuerto: puerto,
      bluetoothDispositivo: _btDispositivoCtrl.text.trim(),
      cablePuertoSerial: _cablePuertoCtrl.text.trim(),
      cableBaudRate: _cableBaudRate,
    );
    await widget.controladorBiometrico.guardarConfiguracion(bioConfig);

    if (notificar) {
      _mostrarToast('Configuración de hardware y periféricos guardada en SQLite.');
    }
  }

  // =========================================================================
  // ESCANEO Y VINCULACIÓN REAL DE IMPRESORA TÉRMICA (EXCLUSIVAMENTE BLUETOOTH)
  // =========================================================================

  Future<void> _iniciarBusquedaImpresora() async {
    if (_hardwareCtrl.escaneandoImpresoras) return;

    // 1. Diagnóstico de Bluetooth físico
    final diagnosticoBt =
        await _hardwareCtrl.verificarPermisosYEstadoBluetooth();
    if (!diagnosticoBt['encendido']) {
      if (mounted) {
        _mostrarToast(
          'El adaptador Bluetooth está apagado en este dispositivo. Por favor actívalo para buscar impresoras.',
          esError: true,
        );
      }
      return;
    }

    // 2. Escaneo real con print_bluetooth_thermal
    final impresoras = await _hardwareCtrl.escanearImpresorasBluetooth();
    if (!mounted) return;

    if (impresoras.isEmpty) {
      _mostrarToast(
        'No se detectaron impresoras Bluetooth vinculadas. Asegúrate de encender tu impresora y vincularla en Ajustes.',
        esError: true,
      );
      return;
    }

    // 3. Selección intuitiva mediante showModalBottomSheet elegante
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
        _tipoConexionImpresora = 'bluetooth';
      });
      await _guardarConfiguracion(notificar: false);
      _mostrarToast(
        'Impresora "${seleccionada.nombre}" conectada y guardada con éxito.',
      );
    }
  }

  Future<void> _abrirDialogoEscanearImpresoras() => _iniciarBusquedaImpresora();

  Widget _buildAnchoChip(String valor, String label) {
    final bool seleccionado = _anchoPapelImpresora == valor;
    return InkWell(
      onTap: () {
        setState(() => _anchoPapelImpresora = valor);
        _guardarConfiguracion(notificar: false);
      },
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

  Future<void> _probarImpresionTicket() async {
    if (!_hardwareCtrl.config.impresoraConectada) {
      _mostrarToast(
        'Debes conectar una impresora térmica Bluetooth antes de imprimir la prueba.',
        esError: true,
      );
      return;
    }

    setState(() => _imprimiendoPrueba = true);

    await _guardarConfiguracion(notificar: false);
    final exito = await _hardwareCtrl.imprimirTicketPrueba(context: context);

    if (mounted) {
      setState(() => _imprimiendoPrueba = false);
      if (exito) {
        _mostrarToast(
          'Ticket de prueba enviado a la impresora térmica ($_anchoPapelImpresora).',
        );
      }
    }
  }

  Widget _buildPestanaConexion(String tipo, String etiqueta, IconData icono) {
    final bool activo = _tipoConexion == tipo;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tipoConexion = tipo;
            _ultimoResultado = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: activo ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: activo ? AppColors.primary : AppColors.border,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icono,
                color: activo ? Colors.white : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: activo ? FontWeight.bold : FontWeight.w500,
                  color: activo ? Colors.white : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            actions: [
              IconButton(
                icon: const Icon(Icons.save_outlined),
                tooltip: 'Guardar configuración',
                onPressed: () => _guardarConfiguracion(),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                // ==========================================
                // 1. SECCIÓN: LECTOR BIOMÉTRICO
                // ==========================================
                Text(
                  'LECTOR DE HUELLAS DACTILARES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    _buildPestanaConexion('local', 'Integrado', Icons.devices),
                    const SizedBox(width: 6),
                    _buildPestanaConexion('wifi', 'WiFi / Red', Icons.wifi),
                    const SizedBox(width: 6),
                    _buildPestanaConexion('bluetooth', 'Bluetooth', Icons.bluetooth),
                    const SizedBox(width: 6),
                    _buildPestanaConexion('cable', 'Cable USB', Icons.usb),
                  ],
                ),
                const SizedBox(height: 12),

                // Formulario del lector
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_tipoConexion == 'local') ...[
                        Text(
                          'Sensor Biométrico Integrado / Nativo (local_auth)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Utiliza el lector de huellas dactilares nativo de tu teléfono Android, tablet o sensor biométrico del equipo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ] else if (_tipoConexion == 'wifi') ...[
                        Text(
                          'Conexión WiFi (Socket TCP / IP)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _wifiHostCtrl,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Dirección IP / Host',
                                  labelStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.secondarySurface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _wifiPuertoCtrl,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Puerto TCP',
                                  labelStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.secondarySurface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (_tipoConexion == 'bluetooth') ...[
                        Text(
                          'Lector Inalámbrico Bluetooth',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _btDispositivoCtrl,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Nombre o Dirección MAC del Lector',
                            hintText: 'Ej. POS-BioReader / 00:1A:7D:DA:71:13',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            labelStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor: AppColors.secondarySurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ] else if (_tipoConexion == 'cable') ...[
                        Text(
                          'Conexión Directa por Cable / Puerto Serial',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _cablePuertoCtrl,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Puerto Serial (COM / tty)',
                                  hintText: 'COM1, COM3, etc.',
                                  labelStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.secondarySurface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.secondarySurface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _cableBaudRate,
                                    isExpanded: true,
                                    dropdownColor: AppColors.card,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                    ),
                                    items: [9600, 19200, 38400, 57600, 115200]
                                        .map((b) => DropdownMenuItem(
                                              value: b,
                                              child: Text('$b bps'),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _cableBaudRate = val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Botones Probar y Guardar
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _probandoConexion
                                  ? null
                                  : _probarConexionLector,
                              icon: _probandoConexion
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.fingerprint, size: 16),
                              label: Text(
                                _probandoConexion
                                    ? 'Verificando...'
                                    : 'Probar Conexión',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _guardarConfiguracion(),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text(
                                'Guardar',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_ultimoResultado != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _ultimoResultado!.exito
                                ? AppColors.subtleGreen
                                : AppColors.subtleAmber,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _ultimoResultado!.exito
                                  ? AppColors.brightGreen
                                  : AppColors.amber,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _ultimoResultado!.exito
                                    ? Icons.check_circle_outline
                                    : Icons.warning_amber_rounded,
                                color: _ultimoResultado!.exito
                                    ? AppColors.brightGreen
                                    : AppColors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _ultimoResultado!.mensaje,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                // ==========================================
                // 2. SECCIÓN: IMPRESORA TÉRMICA POS
                // ==========================================
                Text(
                  'IMPRESORA TÉRMICA DE TICKETS (ESC/POS)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _hardwareCtrl.config.impresoraConectada
                        ? AppColors.subtleGreen.withValues(alpha: 0.22)
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hardwareCtrl.config.impresoraConectada
                          ? AppColors.brightGreen.withValues(alpha: 0.6)
                          : AppColors.border,
                      width: _hardwareCtrl.config.impresoraConectada ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado de la impresora: Icono, Nombre, MAC y Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _hardwareCtrl.config.impresoraConectada
                                  ? AppColors.subtleGreen
                                  : (_impresoraMac.isNotEmpty
                                      ? AppColors.primaryContainer
                                      : AppColors.secondarySurface),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.print_outlined,
                              color: _hardwareCtrl.config.impresoraConectada
                                  ? AppColors.brightGreen
                                  : (_impresoraMac.isNotEmpty
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
                                  _impresoraNombre.isNotEmpty
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
                                  _impresoraMac.isNotEmpty
                                      ? 'MAC: $_impresoraMac · Bluetooth'
                                      : 'Empareja tu impresora por Bluetooth para emitir tickets.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Badge de Estado en Tiempo Real
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _hardwareCtrl.config.impresoraConectada
                                  ? AppColors.subtleGreen
                                  : AppColors.secondarySurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _hardwareCtrl.config.impresoraConectada
                                    ? AppColors.brightGreen
                                    : AppColors.border,
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
                                    color: _hardwareCtrl.config.impresoraConectada
                                        ? AppColors.brightGreen
                                        : AppColors.textSecondary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _hardwareCtrl.config.impresoraConectada
                                      ? 'Conectada'
                                      : 'Desconectada',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _hardwareCtrl.config.impresoraConectada
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

                      // Selector Limpio de Ancho de Rollo (Fijado exclusivamente a Bluetooth)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.secondarySurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.straighten_rounded,
                                    size: 18, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Ancho de Rollo',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                _buildAnchoChip('58mm', '58 mm'),
                                const SizedBox(width: 8),
                                _buildAnchoChip('80mm', '80 mm'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. Botón Prominente: Buscar Impresora (con estado "Buscando..." y spinner)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _hardwareCtrl.escaneandoImpresoras
                              ? null
                              : _iniciarBusquedaImpresora,
                          icon: _hardwareCtrl.escaneandoImpresoras
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.bluetooth_searching, size: 18),
                          label: Text(
                            _hardwareCtrl.escaneandoImpresoras
                                ? 'Buscando...'
                                : 'Buscar Impresora',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 2. Botón de Validación Física: Ticket Prueba (Habilitado solo si está conectada)
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: (_hardwareCtrl.config.impresoraConectada &&
                                  !_imprimiendoPrueba)
                              ? _probarImpresionTicket
                              : null,
                          icon: _imprimiendoPrueba
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.receipt_long, size: 16),
                          label: Text(
                            _imprimiendoPrueba
                                ? 'Imprimiendo...'
                                : 'Ticket Prueba',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _hardwareCtrl.config.impresoraConectada
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _hardwareCtrl.config.impresoraConectada
                                    ? AppColors.primary
                                    : AppColors.secondarySurface,
                            foregroundColor:
                                _hardwareCtrl.config.impresoraConectada
                                    ? Colors.white
                                    : AppColors.textSecondary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
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
                  child: Icon(Icons.print_rounded,
                      color: AppColors.primary, size: 22),
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
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.subtleGreen,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.brightGreen, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check,
                                        size: 14, color: AppColors.brightGreen),
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
                                      horizontal: 14, vertical: 8),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Conectar',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
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
      final diagnosticoBt =
          await widget.controladorHardware.verificarPermisosYEstadoBluetooth();
      if (!diagnosticoBt['encendido']) {
        if (mounted) {
          setState(() {
            _cargando = false;
            _error =
                'El adaptador Bluetooth está apagado en este dispositivo. Por favor enciéndelo e intenta nuevamente.';
          });
        }
        return;
      }

      final lista =
          await widget.controladorHardware.escanearImpresorasBluetooth();

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
            child: Icon(Icons.bluetooth_searching, color: AppColors.primary, size: 24),
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
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContenido(),
      ),
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
            CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
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
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
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
            Icon(Icons.bluetooth_disabled_rounded, size: 44, color: AppColors.amber),
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
            Icon(Icons.print_disabled_outlined, size: 44, color: AppColors.textSecondary),
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
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
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
            separatorBuilder: (_, __) => Divider(color: AppColors.border, height: 1),
            itemBuilder: (context, idx) {
              final imp = _impresoras[idx];
              final bool conectandoEste = _conectandoMac == imp.macOUrl;
              final bool esLaConectada =
                  widget.controladorHardware.config.impresoraConectada &&
                  widget.controladorHardware.config.impresoraMac == imp.macOUrl;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: esLaConectada ? AppColors.subtleGreen : AppColors.secondarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bluetooth,
                    color: esLaConectada ? AppColors.brightGreen : AppColors.primary,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.subtleGreen,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.brightGreen, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check, size: 14, color: AppColors.brightGreen),
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
                            onPressed: _conectandoMac != null ? null : () => _conectar(imp),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Conectar', style: TextStyle(fontSize: 12)),
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

