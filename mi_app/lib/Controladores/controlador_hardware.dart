import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../BaseDatos/base_datos.dart';
import '../Modelos/configuracion_hardware.dart';
import '../Servicios/servicio_biometrico.dart';

/// Controlador Senior para la Gestión de Hardware y Periféricos IoT / POS.
/// Coordina la autenticación biométrica real (local_auth), conectividad de red,
/// permisos Bluetooth y escaneo / enlace de impresoras térmicas ESC/POS.
class ControladorHardware extends ChangeNotifier {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final ServicioBiometrico _servicioBiometrico = ServicioBiometrico();

  ConfiguracionHardware _config = ConfiguracionHardware();
  bool _cargando = false;
  bool _escaneandoImpresoras = false;

  ConfiguracionHardware get config => _config;
  bool get cargando => _cargando;
  bool get escaneandoImpresoras => _escaneandoImpresoras;

  /// Inicializa y carga la configuración persistida desde SQLite
  Future<void> inicializar() async {
    try {
      final db = await BaseDeDatos.instancia.database;

      // Asegura la existencia de la tabla en SQLite de manera auto-reparable
      await db.execute('''
        CREATE TABLE IF NOT EXISTS configuracion_hardware (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          tipoLector TEXT NOT NULL DEFAULT 'local',
          wifiHost TEXT NOT NULL DEFAULT '192.168.1.100',
          wifiPuerto INTEGER NOT NULL DEFAULT 4370,
          bluetoothDispositivo TEXT NOT NULL DEFAULT '',
          cablePuertoSerial TEXT NOT NULL DEFAULT 'COM3',
          cableBaudRate INTEGER NOT NULL DEFAULT 9600,
          ultimoEstadoLector TEXT NOT NULL DEFAULT 'Desconectado',
          impresoraTipo TEXT NOT NULL DEFAULT 'bluetooth',
          impresoraNombre TEXT NOT NULL DEFAULT '',
          impresoraMac TEXT NOT NULL DEFAULT '',
          impresoraAnchoPapel TEXT NOT NULL DEFAULT '80mm',
          impresoraConectada INTEGER NOT NULL DEFAULT 0
        )
      ''');

      final registros = await db.query(
        'configuracion_hardware',
        where: 'id = 1',
      );

      if (registros.isNotEmpty) {
        _config = ConfiguracionHardware.fromMap(registros.first);
      } else {
        _config = ConfiguracionHardware();
        await db.insert('configuracion_hardware', _config.toMap());
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error al inicializar ControladorHardware: $e');
    }
  }

  /// Persiste la configuración actualizada en SQLite
  Future<void> guardarConfiguracion(ConfiguracionHardware nuevaConfig) async {
    _config = nuevaConfig;
    try {
      final db = await BaseDeDatos.instancia.database;
      await db.insert(
        'configuracion_hardware',
        _config.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error al guardar configuración de hardware: $e');
    }
  }

  // =========================================================================
  // 1. LECTOR DE HUELLAS INTEGRADO (NATIVO - local_auth)
  // =========================================================================

  /// Ejecuta el diagnóstico real del sensor biométrico del dispositivo:
  /// 1. Comprueba disponibilidad y soporte de hardware.
  /// 2. Consulta los biométricos enrolados.
  /// 3. Lanza el prompt nativo pidiendo la huella del usuario.
  Future<ResultadoConexionHardware> probarLectorNativo() async {
    try {
      final bool puedeVerificar = await _localAuth.canCheckBiometrics;
      final bool esCompatible = await _localAuth.isDeviceSupported();

      if (!puedeVerificar && !esCompatible) {
        return ResultadoConexionHardware(
          exito: false,
          mensaje: 'Sensor biométrico no disponible o no soportado en este dispositivo.',
        );
      }

      final List<BiometricType> biometricos =
          await _localAuth.getAvailableBiometrics();

      if (biometricos.isEmpty) {
        return ResultadoConexionHardware(
          exito: false,
          mensaje: 'El equipo soporta biometría pero no hay ninguna huella registrada en los Ajustes del sistema.',
        );
      }

      // Despliega el prompt nativo del sistema operativo
      final bool autenticado = await _localAuth.authenticate(
        localizedReason: 'Prueba de Diagnóstico: Coloca tu dedo en el sensor para verificar la conexión',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (autenticado) {
        _config.ultimoEstadoLector = 'Conectado';
        await guardarConfiguracion(_config);
        return ResultadoConexionHardware(
          exito: true,
          mensaje: 'Sensor biométrico operativo. Huella dactilar reconocida exitosamente.',
          dispositivosDetectados: biometricos.map((b) => b.name).toList(),
        );
      } else {
        return ResultadoConexionHardware(
          exito: false,
          mensaje: 'Lectura no reconocida o prueba cancelada por el usuario.',
        );
      }
    } on PlatformException catch (e) {
      String mensajeError = 'Error de sensor biométrico: ${e.message}';
      if (e.code == 'PasscodeNotSet') {
        mensajeError = 'Debes configurar un bloqueo de pantalla (PIN o patrón) en el teléfono.';
      } else if (e.code == 'NotAvailable') {
        mensajeError = 'El hardware biométrico no está disponible temporalmente.';
      } else if (e.code == 'LockedOut') {
        mensajeError = 'Sensor bloqueado temporalmente por demasiados intentos.';
      }
      return ResultadoConexionHardware(exito: false, mensaje: mensajeError);
    } catch (e) {
      return ResultadoConexionHardware(
        exito: false,
        mensaje: 'Excepción inesperada en biometría: $e',
      );
    }
  }

  // =========================================================================
  // 2. DETECCIÓN DE RED Y CONECTIVIDAD (WIFI Y BLUETOOTH)
  // =========================================================================

  /// Comprueba si el dispositivo tiene una conexión de red local activa
  /// y posteriormente verifica el socket TCP con el host y puerto especificados.
  Future<ResultadoConexionHardware> probarConexionWifi({
    required String host,
    required int puerto,
  }) async {
    // 1. Verificación de interfaces de red activas en el dispositivo
    bool interfazActiva = false;
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      interfazActiva = interfaces.any((i) => i.addresses.isNotEmpty);
    } catch (_) {
      interfazActiva = true; // Fallback permisivo
    }

    if (!interfazActiva) {
      return ResultadoConexionHardware(
        exito: false,
        mensaje: 'Sin conexión de red activa: Conecta tu dispositivo a una red WiFi o Local antes de probar.',
      );
    }

    // 2. Prueba de Socket TCP contra el lector en red
    return await _servicioBiometrico.probarConexionWifi(
      host: host,
      puerto: puerto,
    );
  }

  /// Solicita permisos de Bluetooth en tiempo de ejecución (Android 12+ y legacy)
  /// y diagnostica el adaptador inalámbrico.
  Future<ResultadoConexionHardware> probarConexionBluetooth({
    required String dispositivo,
  }) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();

      final bool permitido = (scanStatus.isGranted || scanStatus.isLimited) &&
          (connectStatus.isGranted || connectStatus.isLimited);

      if (!permitido) {
        return ResultadoConexionHardware(
          exito: false,
          mensaje: 'Permisos de Bluetooth denegados. Habilita los permisos de dispositivos cercanos en Ajustes.',
        );
      }
    }

    return await _servicioBiometrico.probarConexionBluetooth(
      dispositivo: dispositivo,
    );
  }

  /// Comprueba el puerto serial por cable USB
  Future<ResultadoConexionHardware> probarConexionCable({
    required String puertoSerial,
    required int baudRate,
  }) async {
    return await _servicioBiometrico.probarConexionCable(
      puertoSerial: puertoSerial,
      baudRate: baudRate,
    );
  }

  // =========================================================================
  // 3. IMPRESORA TÉRMICA POS (ESC/POS Y BLUETOOTH)
  // =========================================================================

  /// Realiza un escaneo activo de impresoras disponibles en el sistema
  /// y dispositivos Bluetooth emparejados.
  Future<List<DispositivoImpresora>> escanearImpresoras() async {
    _escaneandoImpresoras = true;
    notifyListeners();

    List<DispositivoImpresora> lista = [];

    try {
      // Solicita permisos de Bluetooth para dispositivos móviles
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await Permission.bluetoothScan.request();
        await Permission.bluetoothConnect.request();
      }

      // Consulta de impresoras nativas/Bluetooth mediante el motor Printing
      final List<Printer> impresorasNativas = await Printing.listPrinters();

      for (var p in impresorasNativas) {
        lista.add(
          DispositivoImpresora(
            nombre: p.name,
            macOUrl: p.url,
            tipo: p.url.startsWith('bt') || p.url.contains(':')
                ? 'bluetooth'
                : 'usb',
            esPredeterminada: p.isDefault,
          ),
        );
      }

      // Fallbacks para Windows si no se detectaron en spooler
      if (lista.isEmpty && !kIsWeb && Platform.isWindows) {
        final res = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          "Get-Printer | Select-Object -ExpandProperty Name",
        ]);
        final nombres = res.stdout
            .toString()
            .split(RegExp(r'\r?\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty);

        for (var n in nombres) {
          lista.add(
            DispositivoImpresora(
              nombre: n,
              macOUrl: 'winspool://$n',
              tipo: 'usb',
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error durante el escaneo de impresoras: $e');
    } finally {
      _escaneandoImpresoras = false;
      notifyListeners();
    }

    return lista;
  }

  /// Vincula la impresora seleccionada en la configuración persistente
  Future<void> vincularImpresora(DispositivoImpresora impresora) async {
    _config.impresoraNombre = impresora.nombre;
    _config.impresoraMac = impresora.macOUrl;
    _config.impresoraTipo = impresora.tipo;
    _config.impresoraConectada = true;
    await guardarConfiguracion(_config);
  }

  /// Genera e imprime un ticket térmico de prueba en formato 58mm u 80mm
  Future<bool> imprimirTicketPrueba() async {
    try {
      final doc = pw.Document();
      final es80mm = _config.impresoraAnchoPapel == '80mm';
      final pageFormat = es80mm ? PdfPageFormat.roll80 : PdfPageFormat.roll57;

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context ctx) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'PLANTEAPP POS',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  pw.Text(
                    'Biznaga Kíix • Vivero Botánico',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '*** TICKET DE PRUEBA ***',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      'Fecha: ${DateTime.now().toLocal().toString().split('.')[0]}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      'Impresora: ${_config.impresoraNombre.isNotEmpty ? _config.impresoraNombre : "Genérica"}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      'Formato: ${_config.impresoraAnchoPapel} (${_config.impresoraTipo.toUpperCase()})',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 0.8),
                  pw.Text(
                    '¡Conexión y comunicación exitosa con el hardware de impresión!',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'www.planteapp.com.mx',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            );
          },
        ),
      );

      // Si existe una impresora vinculada específica, intenta enviar el trabajo directo
      if (_config.tieneImpresoraVinculada) {
        final impresoras = await Printing.listPrinters();
        final target = impresoras.where(
          (p) =>
              p.url == _config.impresoraMac ||
              p.name == _config.impresoraNombre,
        ).firstOrNull;

        if (target != null) {
          return await Printing.directPrintPdf(
            printer: target,
            onLayout: (format) async => doc.save(),
          );
        }
      }

      // Si no hay vinculación previa o no se encuentra en línea, abre el layout del sistema
      return await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
        name: 'Ticket_Prueba_Planteapp',
      );
    } catch (e) {
      debugPrint('Error al imprimir ticket de prueba: $e');
      return false;
    }
  }
}

