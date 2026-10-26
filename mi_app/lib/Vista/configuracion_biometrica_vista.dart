import 'package:flutter/material.dart';

import '../Tema/app_theme.dart';
import '../Controladores/controlador_biometrico.dart';
import '../Controladores/controlador_autenticacion.dart';
import '../Servicios/servicio_biometrico.dart';

class ConfiguracionBiometricaVista extends StatefulWidget {
  final ControladorBiometrico controladorBiometrico;
  final ControladorAutenticacion controladorAutenticacion;

  const ConfiguracionBiometricaVista({
    super.key,
    required this.controladorBiometrico,
    required this.controladorAutenticacion,
  });

  @override
  State<ConfiguracionBiometricaVista> createState() =>
      _ConfiguracionBiometricaVistaState();
}

class _ConfiguracionBiometricaVistaState
    extends State<ConfiguracionBiometricaVista> {
  late TextEditingController _wifiHostCtrl;
  late TextEditingController _wifiPuertoCtrl;
  late TextEditingController _btDispositivoCtrl;
  late TextEditingController _cablePuertoCtrl;

  late String _tipoConexion;
  late int _cableBaudRate;
  late bool _biometriaHabilitada;

  bool _probandoConexion = false;
  ResultadoConexionHardware? _ultimoResultado;

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
    _biometriaHabilitada = cfg.biometriaHabilitada;
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
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: esError ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _guardarConfiguracion({bool notificar = true}) async {
    final int puerto = int.tryParse(_wifiPuertoCtrl.text.trim()) ?? 4370;

    final nuevaConfig = widget.controladorBiometrico.config.copyWith(
      biometriaHabilitada: _biometriaHabilitada,
      tipoConexion: _tipoConexion,
      wifiHost: _wifiHostCtrl.text.trim(),
      wifiPuerto: puerto,
      bluetoothDispositivo: _btDispositivoCtrl.text.trim(),
      cablePuertoSerial: _cablePuertoCtrl.text.trim(),
      cableBaudRate: _cableBaudRate,
    );

    await widget.controladorBiometrico.guardarConfiguracion(nuevaConfig);
    if (notificar) {
      _mostrarToast('Configuración biométrica guardada correctamente.');
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

  Future<void> _abrirDialogoAgregarHuella() async {
    final colaboradores =
        await widget.controladorAutenticacion.obtenerColaboradores();
    if (!mounted) return;

    String idColaboradorSeleccionado =
        widget.controladorAutenticacion.usuarioActual?.id ??
            (colaboradores.isNotEmpty ? colaboradores.first.id : 'VO-4092');

    final nombreHuellaCtrl =
        TextEditingController(text: 'Huella Dactilar Principal');

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.fingerprint, color: AppColors.primary, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    'Registrar Huella',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asocia una huella al perfil de un colaborador para permitir acceso biométrico.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Colaborador asociado',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: idColaboradorSeleccionado,
                          isExpanded: true,
                          dropdownColor: AppColors.card,
                          style: TextStyle(color: AppColors.textPrimary),
                          items: colaboradores.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.id,
                              child: Text('${c.nombre} (${c.rol})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                idColaboradorSeleccionado = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Etiqueta de la huella',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nombreHuellaCtrl,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Ej. Índice Derecho',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.secondarySurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
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
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.fingerprint, size: 18),
                  label: const Text('Escanear y Guardar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmar == true) {
      final compatible =
          await widget.controladorBiometrico.servicio.verificarSoporteBiometrico();
      if (!compatible && mounted) {
        _mostrarToast(
          'No se detectó un sensor biométrico disponible o habilitado en este dispositivo.',
          esError: true,
        );
        return;
      }

      final exito = await widget.controladorBiometrico.registrarHuella(
        colaboradorId: idColaboradorSeleccionado,
        nombreHuella: nombreHuellaCtrl.text,
      );

      if (mounted) {
        if (exito) {
          setState(() {
            _biometriaHabilitada = true;
          });
          _mostrarToast('Huella dactilar registrada y activada exitosamente');
        } else {
          _mostrarToast(
            'No se completó la lectura biométrica o fue cancelada.',
            esError: true,
          );
        }
      }
    }
  }

  Future<void> _abrirDialogoEliminarHuella() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Eliminar Huella?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Se eliminará la huella vinculada. Los colaboradores deberán ingresar con su ID y contraseña.',
          style: TextStyle(color: AppColors.textSecondary),
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
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await widget.controladorBiometrico.eliminarHuella();
      if (mounted) {
        setState(() {
          _biometriaHabilitada = false;
        });
        _mostrarToast('Huella dactilar eliminada correctamente');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.controladorBiometrico.config;
    final bool tieneHuella = cfg.tieneHuellaRegistrada;

    return AnimatedBuilder(
      animation: ThemeManager.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            title: Text(
              'Lector de Huellas y Biometría',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppColors.surface,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.save_outlined),
                tooltip: 'Guardar cambios',
                onPressed: () => _guardarConfiguracion(),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Switch Activar Biometría
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.primary,
                    title: Text(
                      'Activar Acceso Biométrico',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      'Permite iniciar sesión rápidamente con huella dactilar',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    value: _biometriaHabilitada,
                    onChanged: (val) async {
                      if (val && !tieneHuella) {
                        _abrirDialogoAgregarHuella();
                      } else {
                        setState(() => _biometriaHabilitada = val);
                        await widget.controladorBiometrico
                            .activarBiometria(val);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Tarjeta Estado de la Huella
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: tieneHuella
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: tieneHuella
                                  ? AppColors.primaryContainer
                                  : AppColors.secondarySurface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.fingerprint,
                              color: tieneHuella
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tieneHuella
                                      ? (cfg.nombreHuella ?? 'Huella Activa')
                                      : 'Sin Huella Registrada',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tieneHuella
                                      ? 'Vinculada al colaborador ID: ${cfg.usuarioVinculadoId}'
                                      : 'Registra una huella para activar el acceso.',
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
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _abrirDialogoAgregarHuella,
                              icon: Icon(
                                tieneHuella ? Icons.refresh : Icons.add,
                                size: 18,
                              ),
                              label: Text(
                                tieneHuella
                                    ? 'Re-escanear Huella'
                                    : 'Agregar Huella',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          if (tieneHuella) ...[
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: _abrirDialogoEliminarHuella,
                              tooltip: 'Eliminar Huella',
                              icon: const Icon(Icons.delete_outline),
                              color: AppColors.error,
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    AppColors.error.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Sección: Conexión de Lector (WiFi, Bluetooth, Cable, Local)
                Text(
                  'Tipo de Lector / Conexión',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    _buildPestanaConexion('local', 'Integrado', Icons.devices),
                    const SizedBox(width: 6),
                    _buildPestanaConexion('wifi', 'WiFi (Red)', Icons.wifi),
                    const SizedBox(width: 6),
                    _buildPestanaConexion(
                      'bluetooth',
                      'Bluetooth',
                      Icons.bluetooth,
                    ),
                    const SizedBox(width: 6),
                    _buildPestanaConexion('cable', 'Cable USB', Icons.usb),
                  ],
                ),
                const SizedBox(height: 16),

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
                            fontSize: 13,
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
                            fontSize: 13,
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
                            fontSize: 13,
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
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Utiliza el lector de huellas dactilares nativo de tu teléfono Android, tablet o sensor Windows Hello del equipo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

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
                                    : 'Probar y Conectar',
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
                          padding: const EdgeInsets.all(10),
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
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _ultimoResultado!.mensaje,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 11,
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
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPestanaConexion(String clave, String etiqueta, IconData icono) {
    final bool seleccionado = _tipoConexion == clave;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _tipoConexion = clave;
            _ultimoResultado = null;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: seleccionado ? AppColors.primary : AppColors.secondarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icono,
                size: 18,
                color: seleccionado ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                etiqueta,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: seleccionado ? Colors.white : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight:
                      seleccionado ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
