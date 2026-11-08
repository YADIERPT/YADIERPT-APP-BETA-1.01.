import 'package:flutter/material.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_biometrico.dart';
import '../Servicios/servicio_biometrico.dart';

/// Vista de Hardware y Periféricos:
/// Gestiona la conexión con lectores de huellas externos (WiFi, Bluetooth, Cable USB, Sensor Nativo)
/// y la preparación para futuros dispositivos del punto de venta (como impresoras térmicas de tickets).
class HardwareVista extends StatefulWidget {
  final ControladorBiometrico controladorBiometrico;

  const HardwareVista({
    super.key,
    required this.controladorBiometrico,
  });

  @override
  State<HardwareVista> createState() => _HardwareVistaState();
}

class _HardwareVistaState extends State<HardwareVista> {
  // Controladores de texto para conexión del lector
  late TextEditingController _wifiHostCtrl;
  late TextEditingController _wifiPuertoCtrl;
  late TextEditingController _btDispositivoCtrl;
  late TextEditingController _cablePuertoCtrl;

  late String _tipoConexion;
  late int _cableBaudRate;

  bool _probandoConexion = false;
  ResultadoConexionHardware? _ultimoResultado;

  // Estado para la sección de impresora de tickets
  String _tipoConexionImpresora = 'bluetooth';
  String _anchoPapelImpresora = '80mm';

  @override
  void initState() {
    super.initState();
    final cfg = widget.controladorBiometrico.config;
    _wifiHostCtrl = TextEditingController(text: cfg.wifiHost);
    _wifiPuertoCtrl = TextEditingController(text: cfg.wifiPuerto.toString());
    _btDispositivoCtrl = TextEditingController(text: cfg.bluetoothDispositivo);
    _cablePuertoCtrl = TextEditingController(text: cfg.cablePuertoSerial);
    _tipoConexion = cfg.tipoConexion;
    _cableBaudRate = cfg.cableBaudRate;
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _guardarConfiguracion({bool notificar = true}) async {
    final int puerto = int.tryParse(_wifiPuertoCtrl.text.trim()) ?? 4370;

    final nuevaConfig = widget.controladorBiometrico.config.copyWith(
      tipoConexion: _tipoConexion,
      wifiHost: _wifiHostCtrl.text.trim(),
      wifiPuerto: puerto,
      bluetoothDispositivo: _btDispositivoCtrl.text.trim(),
      cablePuertoSerial: _cablePuertoCtrl.text.trim(),
      cableBaudRate: _cableBaudRate,
    );

    await widget.controladorBiometrico.guardarConfiguracion(nuevaConfig);
    if (notificar) {
      _mostrarToast('Configuración de periféricos guardada correctamente.');
    }
  }

  Future<void> _probarConexion() async {
    await _guardarConfiguracion(notificar: false);

    setState(() {
      _probandoConexion = true;
      _ultimoResultado = null;
    });

    final resultado =
        await widget.controladorBiometrico.probarYActualizarConexion();

    if (mounted) {
      setState(() {
        _probandoConexion = false;
        _ultimoResultado = resultado;
      });

      _mostrarToast(
        resultado.mensaje,
        esError: !resultado.exito,
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

                // Selector de interfaz
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

                // Formulario dependiente del tipo de conexión
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
                      if (_tipoConexion == 'wifi') ...[
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
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
                      ] else ...[
                        Text(
                          'Sensor Biométrico Integrado / Nativo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Utiliza el lector de huellas dactilares integrado en el teléfono, tablet o sensor biométrico del sistema operativo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Botones Probar Conexión y Guardar
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _probandoConexion ? null : _probarConexion,
                              icon: _probandoConexion
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync, size: 16),
                              label: Text(
                                _probandoConexion
                                    ? 'Probando...'
                                    : 'Probar Conexión',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: AppColors.primary),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
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
                // 2. SECCIÓN: IMPRESORA TÉRMICA DE TICKETS
                // ==========================================
                Text(
                  'IMPRESORA TÉRMICA POS (TICKETS)',
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
                              color: AppColors.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.print_outlined,
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
                                  'Impresora de Tickets ESC/POS',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Compatible con rollos estándar térmicos de 58mm y 80mm.',
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
                                  'Ancho de Papel',
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
                                          child: Text('58 mm'),
                                        ),
                                        DropdownMenuItem(
                                          value: '80mm',
                                          child: Text('80 mm'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _anchoPapelImpresora = val);
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
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: AppColors.brightGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Configurada para ticket PDF y salida térmica',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
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

