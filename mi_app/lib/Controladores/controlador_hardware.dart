import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../BaseDatos/base_datos.dart';
import '../Modelos/configuracion_hardware.dart';
import '../Modelos/venta.dart';
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
  // 3. IMPRESORA TÉRMICA POS (SOCKET NATIVO BLUETOOTH SPP / TCP RAW 9100)
  // =========================================================================

  /// Comprueba permisos de Bluetooth y si el adaptador físico está encendido.
  /// Proporciona un diagnóstico exhaustivo para guiar al usuario en la UI.
  Future<Map<String, dynamic>> verificarPermisosYEstadoBluetooth() async {
    bool permisosConcedidos = true;

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final scanStatus = await Permission.bluetoothScan.status;
      final connectStatus = await Permission.bluetoothConnect.status;

      if (!scanStatus.isGranted || !connectStatus.isGranted) {
        final scanReq = await Permission.bluetoothScan.request();
        final connectReq = await Permission.bluetoothConnect.request();
        permisosConcedidos = scanReq.isGranted && connectReq.isGranted;
      }
    }

    final bool isGrantedPlugin =
        await PrintBluetoothThermal.isPermissionBluetoothGranted;
    final bool btEncendido = await PrintBluetoothThermal.bluetoothEnabled;

    return {
      'permisos': permisosConcedidos && isGrantedPlugin,
      'encendido': btEncendido,
      'listo': permisosConcedidos && isGrantedPlugin && btEncendido,
      'mensaje': !btEncendido
          ? 'El Bluetooth está apagado en este dispositivo.'
          : (!permisosConcedidos || !isGrantedPlugin)
              ? 'Permisos de dispositivos cercanos denegados.'
              : 'Bluetooth operativo y listo para conectar.',
    };
  }

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
      final dispositivosEmparejados =
          await _obtenerDispositivosBluetoothEmparejados();
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

  /// Consulta los dispositivos Bluetooth emparejados en el sistema operativo mediante el socket nativo
  Future<List<DispositivoImpresora>> _obtenerDispositivosBluetoothEmparejados() async {
    final List<DispositivoImpresora> lista = [];

    try {
      final bool btActivo = await PrintBluetoothThermal.bluetoothEnabled;
      if (btActivo) {
        final List<BluetoothInfo> dispositivosNativos =
            await PrintBluetoothThermal.pairedBluetooths;

        for (final d in dispositivosNativos) {
          final mac = d.macAdress.trim();
          final nombre = d.name.trim();
          if (mac.isNotEmpty) {
            final bool esVinculada = _config.impresoraMac == mac;
            lista.add(
              DispositivoImpresora(
                nombre: nombre.isNotEmpty ? nombre : 'Impresora Térmica ($mac)',
                macOUrl: mac,
                tipo: 'bluetooth',
                esPredeterminada: esVinculada,
              ),
            );
          }
        }
      } else {
        debugPrint('Bluetooth apagado durante la lectura de emparejados.');
      }
    } catch (e) {
      debugPrint(
        'Error al consultar dispositivos con PrintBluetoothThermal: $e',
      );
    }

    // Fallback: Si no se detectaron emparejados pero hay una MAC guardada previamente
    if (lista.isEmpty && _config.impresoraMac.isNotEmpty) {
      lista.add(
        DispositivoImpresora(
          nombre: _config.impresoraNombre.isNotEmpty
              ? _config.impresoraNombre
              : 'Impresora Bluetooth Guardada',
          macOUrl: _config.impresoraMac,
          tipo: 'bluetooth',
          esPredeterminada: true,
        ),
      );
    }

    return lista;
  }

  /// Comprueba el estado de la conexión física del socket Bluetooth
  Future<bool> verificarEstadoConexionImpresora() async {
    if (_config.impresoraTipo != 'bluetooth') {
      return _config.impresoraConectada;
    }
    try {
      final bool conectado = await PrintBluetoothThermal.connectionStatus;
      if (_config.impresoraConectada != conectado) {
        _config.impresoraConectada = conectado;
        notifyListeners();
      }
      return conectado;
    } catch (_) {
      return false;
    }
  }

  /// Abre la conexión directa por socket RFCOMM / SPP hacia la impresora especificada o guardada
  Future<bool> conectarImpresora({String? macAddress}) async {
    final mac = (macAddress ?? _config.impresoraMac).trim();
    if (mac.isEmpty) {
      debugPrint('No se especificó dirección MAC para conectar la impresora.');
      return false;
    }

    try {
      final bool btActivo = await PrintBluetoothThermal.bluetoothEnabled;
      if (!btActivo) {
        debugPrint('El adaptador Bluetooth está apagado.');
        return false;
      }

      final bool yaConectado = await PrintBluetoothThermal.connectionStatus;
      if (yaConectado && _config.impresoraMac == mac) {
        _config.impresoraConectada = true;
        notifyListeners();
        return true;
      }

      debugPrint('Abriendo socket SPP nativo a $mac...');
      final bool conectado =
          await PrintBluetoothThermal.connect(macPrinterAddress: mac);

      _config.impresoraConectada = conectado;
      if (conectado) {
        _config.impresoraMac = mac;
      }
      await guardarConfiguracion(_config);
      notifyListeners();
      return conectado;
    } catch (e) {
      debugPrint('Excepción al conectar socket de impresora: $e');
      _config.impresoraConectada = false;
      notifyListeners();
      return false;
    }
  }

  /// Cierra el socket Bluetooth activo con la impresora
  Future<bool> desconectarImpresora() async {
    try {
      final bool desconectado = await PrintBluetoothThermal.disconnect;
      _config.impresoraConectada = false;
      await guardarConfiguracion(_config);
      notifyListeners();
      return desconectado;
    } catch (e) {
      debugPrint('Error al desconectar socket de impresora: $e');
      return false;
    }
  }

  /// Vincula la impresora seleccionada en la configuración persistente e intenta el enlace por socket
  Future<bool> vincularImpresora(DispositivoImpresora impresora) async {
    _config.impresoraNombre = impresora.nombre;
    _config.impresoraMac = impresora.macOUrl;
    _config.impresoraTipo = impresora.tipo;
    await guardarConfiguracion(_config);

    if (impresora.tipo == 'bluetooth') {
      return await conectarImpresora(macAddress: impresora.macOUrl);
    } else {
      _config.impresoraConectada = true;
      await guardarConfiguracion(_config);
      return true;
    }
  }

  /// Envía un flujo binario directo de bytes ESC/POS al hardware de impresión
  /// a través de socket Bluetooth SPP (RFCOMM) o socket TCP de red (Puerto 9100).
  Future<bool> enviarBytesAImpresora(List<int> bytes) async {
    if (bytes.isEmpty) return false;

    try {
      // 1. Conexión por Socket TCP (WiFi / Ethernet en puerto 9100 estándar POS)
      if (_config.impresoraTipo == 'wifi') {
        final host = _config.wifiHost.trim();
        final socket = await Socket.connect(
          host,
          9100,
          timeout: const Duration(seconds: 4),
        );
        socket.add(bytes);
        await socket.flush();
        await socket.close();
        return true;
      }

      // 2. Conexión por Socket Físico Bluetooth SPP (RFCOMM Serial Port Profile)
      if (_config.impresoraTipo == 'bluetooth') {
        final mac = _config.impresoraMac.trim();
        if (mac.isEmpty) {
          debugPrint(
            'Aviso: Dirección MAC no configurada para impresora Bluetooth.',
          );
          return false;
        }

        final bool btActivo = await PrintBluetoothThermal.bluetoothEnabled;
        if (!btActivo) {
          debugPrint(
            'Error: El adaptador Bluetooth está desactivado en el dispositivo.',
          );
          return false;
        }

        // Verifica si el socket ya está abierto; si no, lo establece
        bool conectado = await PrintBluetoothThermal.connectionStatus;
        if (!conectado) {
          debugPrint('Socket no activo. Conectando a MAC $mac...');
          conectado =
              await PrintBluetoothThermal.connect(macPrinterAddress: mac);
        }

        if (!conectado) {
          debugPrint('No fue posible abrir el socket Bluetooth RFCOMM con $mac.');
          _config.impresoraConectada = false;
          notifyListeners();
          return false;
        }

        _config.impresoraConectada = true;
        notifyListeners();

        debugPrint(
          'ESC/POS: Transmitiendo ${bytes.length} bytes a la MAC $mac por socket SPP nativo...',
        );
        final bool exitoEnvio = await PrintBluetoothThermal.writeBytes(bytes);
        debugPrint('ESC/POS: Resultado de transmisión por socket: $exitoEnvio');
        return exitoEnvio;
      }

      // 3. Fallback USB / Impresora de sistema de escritorio
      if (_config.impresoraTipo == 'usb') {
        try {
          return await PrintBluetoothThermal.writeBytes(bytes);
        } catch (_) {
          return false;
        }
      }

      return false;
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

  /// Imprime un ticket de venta real en formato ESC/POS binario directo sobre el socket térmico
  Future<bool> imprimirTicketVentaEscPos(
    Venta venta, {
    double recibido = 0.0,
  }) async {
    try {
      final es80mm = _config.impresoraAnchoPapel == '80mm';
      final gen = GeneradorEscPos(es80mm: es80mm);

      // Cabecera de marca
      gen.texto('PLANTEAPP POS',
          alineacion: AlineacionEscPos.centro,
          tamanoFuente: TamanoFuenteEscPos.grande,
          esNegrita: true);
      gen.texto('Biznaga Kíix • Vivero Botánico',
          alineacion: AlineacionEscPos.centro);
      gen.lineaDivisoria('=');

      gen.filaDosColumnas(
        'Ticket #:',
        venta.id.length >= 8 ? venta.id.substring(0, 8) : venta.id,
      );
      final ahora = venta.fecha;
      final fechaStr =
          '${ahora.day.toString().padLeft(2, '0')}/${ahora.month.toString().padLeft(2, '0')}/${ahora.year} ${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';
      gen.filaDosColumnas('Fecha:', fechaStr);

      if (venta.cliente != null && venta.cliente!.trim().isNotEmpty) {
        gen.filaDosColumnas('Cliente:', venta.cliente!);
      }
      gen.lineaDivisoria('-');

      // Artículos
      gen.filaDosColumnas('CANT x ARTÍCULO', 'TOTAL', esNegrita: true);
      for (final art in venta.articulos) {
        gen.filaDosColumnas(
          '${art.cantidad}x ${art.producto.nombre}',
          '\$${art.subtotal.toStringAsFixed(2)}',
        );
      }
      gen.lineaDivisoria('-');

      gen.filaDosColumnas(
        'SUBTOTAL:',
        '\$${venta.subtotal.toStringAsFixed(2)}',
      );
      if (venta.aplicarIva) {
        final ivaPct = (venta.porcentajeIva > 1
                ? venta.porcentajeIva
                : venta.porcentajeIva * 100)
            .toInt();
        gen.filaDosColumnas(
          'IVA ($ivaPct%):',
          '\$${venta.montoIva.toStringAsFixed(2)}',
        );
      }
      gen.filaDosColumnas(
        'TOTAL:',
        '\$${venta.total.toStringAsFixed(2)}',
        esNegrita: true,
        tamanoFuente: TamanoFuenteEscPos.dobleAlto,
      );

      if (recibido > 0) {
        gen.filaDosColumnas('Recibido:', '\$${recibido.toStringAsFixed(2)}');
        final cambio = recibido - venta.total;
        if (cambio > 0) {
          gen.filaDosColumnas('Cambio:', '\$${cambio.toStringAsFixed(2)}');
        }
      }

      gen.lineaDivisoria('=');
      gen.texto('¡Gracias por su compra!',
          alineacion: AlineacionEscPos.centro);
      gen.texto('Vivero Botánico y Accesorios',
          alineacion: AlineacionEscPos.centro);
      gen.alimentarLineas(2);
      gen.cortarPapel();

      final bytes = gen.obtenerBytes();
      return await enviarBytesAImpresora(bytes);
    } catch (e) {
      debugPrint('Error al imprimir ticket de venta ESC/POS: $e');
      return false;
    }
  }
}

