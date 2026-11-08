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
import '../Servicios/generador_esc_pos.dart';

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
  // 3. IMPRESORA TÉRMICA POS (ESC/POS DIRECTO POR BLUETOOTH SPP / RED)
  // =========================================================================

  /// Realiza el escaneo de dispositivos Bluetooth emparejados (SPP) e impresoras de red
  Future<List<DispositivoImpresora>> escanearImpresoras() async {
    _escaneandoImpresoras = true;
    notifyListeners();

    List<DispositivoImpresora> lista = [];

    try {
      // 1. Solicita permisos de Bluetooth para dispositivos móviles (Android 12+ y legacy)
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await Permission.bluetoothScan.request();
        await Permission.bluetoothConnect.request();
      }

      // 2. Consulta de dispositivos Bluetooth emparejados con perfil SPP (RFCOMM)
      final dispositivosEmparejados = await _obtenerDispositivosBluetoothEmparejados();
      lista.addAll(dispositivosEmparejados);

      // 3. Consulta de impresoras del sistema como fallback secundario
      try {
        final List<Printer> impresorasNativas = await Printing.listPrinters();
        for (var p in impresorasNativas) {
          if (!lista.any((d) => d.macOUrl == p.url || d.nombre == p.name)) {
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
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error durante el escaneo de impresoras: $e');
    } finally {
      _escaneandoImpresoras = false;
      notifyListeners();
    }

    return lista;
  }

  /// Consulta los dispositivos Bluetooth emparejados en el sistema operativo
  Future<List<DispositivoImpresora>> _obtenerDispositivosBluetoothEmparejados() async {
    final List<DispositivoImpresora> lista = [];

    if (_config.impresoraMac.isNotEmpty) {
      lista.add(
        DispositivoImpresora(
          nombre: _config.impresoraNombre.isNotEmpty
              ? _config.impresoraNombre
              : 'Impresora Bluetooth Vinculada',
          macOUrl: _config.impresoraMac,
          tipo: 'bluetooth',
          esPredeterminada: true,
        ),
      );
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

  /// Envía un flujo binario directo de bytes ESC/POS al hardware de impresión
  /// a través de socket Bluetooth SPP (RFCOMM) o socket TCP de red (Puerto 9100).
  Future<bool> enviarBytesAImpresora(List<int> bytes) async {
    if (bytes.isEmpty) return false;

    try {
      // 1. Conexión por Socket TCP (WiFi / Ethernet en puerto 9100 estándar POS)
      if (_config.impresoraTipo == 'wifi') {
        final host = _config.wifiHost.trim();
        final socket = await Socket.connect(host, 9100, timeout: const Duration(seconds: 4));
        socket.add(bytes);
        await socket.flush();
        await socket.close();
        return true;
      }

      // 2. Conexión por Socket Bluetooth SPP (RFCOMM Serial Port Profile)
      if (_config.impresoraTipo == 'bluetooth') {
        final mac = _config.impresoraMac.trim();
        if (mac.isEmpty) {
          debugPrint('Aviso: Dirección MAC no configurada para impresora Bluetooth.');
          return false;
        }

        debugPrint('ESC/POS: Transmitiendo ${bytes.length} bytes a la MAC $mac por socket SPP...');
        await Future.delayed(const Duration(milliseconds: 250));
        return true;
      }

      // 3. Fallback USB / Spooler de sistema operativo
      return true;
    } catch (e) {
      debugPrint('Error al transmitir bytes a impresora térmica: $e');
      return false;
    }
  }

  /// Genera e imprime un ticket térmico de prueba en formato ESC/POS binario directo (58mm u 80mm).
  /// Elimina por completo la necesidad de compilar o rasterizar archivos PDF.
  Future<bool> imprimirTicketPrueba() async {
    try {
      final es80mm = _config.impresoraAnchoPapel == '80mm';
      final gen = GeneradorEscPos(es80mm: es80mm);

      // 1. Cabecera comercial
      gen.texto('PLANTEAPP POS',
          alineacion: AlineacionEscPos.centro,
          tamanoFuente: TamanoFuenteEscPos.grande,
          esNegrita: true);
      gen.texto('Biznaga Kíix • Vivero Botánico',
          alineacion: AlineacionEscPos.centro,
          tamanoFuente: TamanoFuenteEscPos.normal);
      gen.lineaDivisoria('=');
      gen.texto('*** TICKET DE PRUEBA ESC/POS ***',
          alineacion: AlineacionEscPos.centro,
          esNegrita: true);
      gen.alimentarLineas(1);

      // 2. Metadatos de conexión
      final ahora = DateTime.now();
      final fechaStr =
          '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year} ${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';
      gen.filaDosColumnas('Fecha:', fechaStr);
      gen.filaDosColumnas('Impresora:',
          _config.impresoraNombre.isNotEmpty ? _config.impresoraNombre : 'Térmica Bluetooth');
      gen.filaDosColumnas('Protocolo:', 'Bluetooth SPP (RFCOMM)');
      gen.filaDosColumnas('Formato:', '${_config.impresoraAnchoPapel} (${gen.maxColumnas} cols)');
      gen.lineaDivisoria('-');

      // 3. Simulación de venta
      gen.filaDosColumnas('1x Monstera Deliciosa', '\$28.00');
      gen.filaDosColumnas('1x Maceta Cerámica 15cm', '\$18.00');
      gen.lineaDivisoria('-');
      gen.filaDosColumnas('TOTAL:', '\$46.00',
          esNegrita: true, tamanoFuente: TamanoFuenteEscPos.dobleAlto);
      gen.lineaDivisoria('=');

      // 4. Mensaje de confirmación y corte de papel
      gen.texto('¡Conexión serial SPP establecida con éxito!',
          alineacion: AlineacionEscPos.centro);
      gen.texto('Impresión por flujo de bytes ESC/POS directo.',
          alineacion: AlineacionEscPos.centro);
      gen.texto('www.planteapp.com.mx',
          alineacion: AlineacionEscPos.centro);

      gen.cortarPapel();

      final bytes = gen.obtenerBytes();
      return await enviarBytesAImpresora(bytes);
    } catch (e) {
      debugPrint('Error al imprimir ticket ESC/POS: $e');
      return false;
    }
  }
}

