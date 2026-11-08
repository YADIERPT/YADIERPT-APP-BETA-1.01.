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

    _cargarConfiguracionHardware();
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
  // ESCANEO Y VINCULACIÓN REAL DE IMPRESORA TÉRMICA
  // =========================================================================

  Future<void> _abrirDialogoEscanearImpresoras() async {
    final listaImpresoras = await _hardwareCtrl.escanearImpresoras();

    if (!mounted) return;

    final DispositivoImpresora? seleccionada =
        await showDialog<DispositivoImpresora>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.print_outlined, color: AppColors.primary, size: 26),
              const SizedBox(width: 10),
              Text(
                'Seleccionar Impresora',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: listaImpresoras.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bluetooth_searching_rounded,
                          size: 40,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No se encontraron impresoras Bluetooth ni de red emparejadas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Asegúrate de encender la impresora térmica y emparejarla primero en los Ajustes de Bluetooth de tu teléfono o PC.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: listaImpresoras.length,
                    separatorBuilder: (_, __) => Divider(
                      color: AppColors.border,
                      height: 1,
                    ),
                    itemBuilder: (context, idx) {
                      final imp = listaImpresoras[idx];
                      final bool esSeleccionada =
                          imp.macOUrl == _impresoraMac ||
                              imp.nombre == _impresoraNombre;

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: esSeleccionada
                                ? AppColors.primaryContainer
                                : AppColors.secondarySurface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            imp.tipo == 'bluetooth'
                                ? Icons.bluetooth
                                : Icons.print_outlined,
                            size: 20,
                            color: esSeleccionada
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        title: Text(
                          imp.nombre,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: esSeleccionada
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          imp.macOUrl.isNotEmpty ? imp.macOUrl : 'Directo POS',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: esSeleccionada
                            ? Icon(Icons.check_circle,
                                color: AppColors.primary, size: 20)
                            : null,
                        onTap: () => Navigator.pop(ctx, imp),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cerrar',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        );
      },
    );

    if (seleccionada != null) {
      await _hardwareCtrl.vincularImpresora(seleccionada);
      if (mounted) {
        setState(() {
          _impresoraNombre = seleccionada.nombre;
          _impresoraMac = seleccionada.macOUrl;
          _tipoConexionImpresora = seleccionada.tipo;
        });
        _mostrarToast(
          'Impresora "${seleccionada.nombre}" vinculada correctamente.',
        );
      }
    }
  }

  Future<void> _probarImpresionTicket() async {
    setState(() => _imprimiendoPrueba = true);

    await _guardarConfiguracion(notificar: false);
    final exito = await _hardwareCtrl.imprimirTicketPrueba();

    if (mounted) {
      setState(() => _imprimiendoPrueba = false);
      _mostrarToast(
        exito
            ? 'Ticket de prueba enviado a la impresora térmico ($_anchoPapelImpresora).'
            : 'No se pudo completar el trabajo de impresión térmica.',
        esError: !exito,
      );
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _impresoraMac.isNotEmpty
                                  ? AppColors.primaryContainer
                                  : AppColors.secondarySurface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.print_outlined,
                              color: _impresoraMac.isNotEmpty
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
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
                                      ? 'Dirección MAC / URL: $_impresoraMac'
                                      : 'Empareja tu impresora por Bluetooth para imprimir tickets.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Selectores de interfaz y ancho de papel
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Interfaz',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondarySurface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _tipoConexionImpresora,
                                      isExpanded: true,
                                      dropdownColor: AppColors.card,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'bluetooth',
                                          child: Text('Bluetooth'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'usb',
                                          child: Text('USB Directo'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'red',
                                          child: Text('Red Ethernet/WiFi'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _tipoConexionImpresora = val);
                                          _guardarConfiguracion(notificar: false);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ancho de Rollo',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondarySurface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _anchoPapelImpresora,
                                      isExpanded: true,
                                      dropdownColor: AppColors.card,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: '58mm',
                                          child: Text('58 mm (Estándar)'),
                                        ),
                                        DropdownMenuItem(
                                          value: '80mm',
                                          child: Text('80 mm (Amplio)'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _anchoPapelImpresora = val);
                                          _guardarConfiguracion(notificar: false);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Botones de acción de la impresora
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _hardwareCtrl.escaneandoImpresoras
                                  ? null
                                  : _abrirDialogoEscanearImpresoras,
                              icon: _hardwareCtrl.escaneandoImpresoras
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.bluetooth_searching, size: 16),
                              label: const Text(
                                'Buscar Impresora',
                                style: TextStyle(fontSize: 12),
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
                              onPressed: _imprimiendoPrueba
                                  ? null
                                  : _probarImpresionTicket,
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
                              label: const Text(
                                'Ticket Prueba',
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
