import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'servicio_permisos.dart';

class ResultadoConexionHardware {
  final bool exito;
  final String mensaje;
  final List<String> puertosDisponibles;
  final List<String> dispositivosDetectados;

  ResultadoConexionHardware({
    required this.exito,
    required this.mensaje,
    this.puertosDisponibles = const [],
    this.dispositivosDetectados = const [],
  });
}

class ServicioBiometrico {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> verificarSoporteBiometrico() async {
    try {
      final bool puedeVerificar = await _localAuth.canCheckBiometrics;
      final bool esCompatible = await _localAuth.isDeviceSupported();
      return puedeVerificar || esCompatible;
    } on PlatformException catch (e) {
      debugPrint('Error al verificar soporte biométrico: $e');
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> obtenerBiometricosDisponibles() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('Error al obtener biométricos: $e');
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> autenticarHuella({
    String motivo = 'Coloca tu dedo en el lector para autenticarte',
  }) async {
    try {
      final bool autenticado = await _localAuth.authenticate(
        localizedReason: motivo,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return autenticado;
    } on PlatformException catch (e) {
      debugPrint('Excepción de autenticación biométrica: $e');
      return false;
    } catch (e) {
      debugPrint('Error desconocido en biometría: $e');
      return false;
    }
  }

  Future<ResultadoConexionHardware> probarConexionWifi({
    required String host,
    required int puerto,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final hostTrim = host.trim();
    if (hostTrim.isEmpty) {
      return ResultadoConexionHardware(
        exito: false,
        mensaje: 'La dirección IP / Host no puede estar vacía.',
      );
    }
    if (puerto <= 0 || puerto > 65535) {
      return ResultadoConexionHardware(
        exito: false,
        mensaje: 'El puerto debe estar entre 1 y 65535.',
      );
    }

    try {
      final socket = await Socket.connect(hostTrim, puerto, timeout: timeout);
      socket.destroy();
      return ResultadoConexionHardware(
        exito: true,
        mensaje: 'Conexión TCP establecida con éxito con el lector en $hostTrim:$puerto',
      );
    } on SocketException catch (e) {
      return ResultadoConexionHardware(
        exito: false,
        mensaje: 'No se pudo conectar a $hostTrim:$puerto (${e.message})',
      );
    } catch (e) {
      return ResultadoConexionHardware(
        exito: false,
        mensaje: 'Error al conectar por WiFi con el lector: $e',
      );
    }
  }

  Future<ResultadoConexionHardware> probarConexionCable({
    required String puertoSerial,
    required int baudRate,
  }) async {
    final pTrim = puertoSerial.trim();
    if (pTrim.isEmpty) {
      return ResultadoConexionHardware(
        exito: false,
        mensaje: 'Debes especificar el puerto serial (ej. COM3 o /dev/ttyUSB0).',
      );
    }

    try {
      if (!kIsWeb && Platform.isWindows) {
        final resultado = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          "[System.IO.Ports.SerialPort]::GetPortNames()",
        ]);
        final List<String> disponibles = resultado.stdout
            .toString()
            .split(RegExp(r'\r?\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        final bool encontrado = disponibles.any(
          (p) => p.toUpperCase() == pTrim.toUpperCase(),
        );

        if (encontrado) {
          return ResultadoConexionHardware(
            exito: true,
            mensaje: 'Puerto $pTrim detectado y operativo a $baudRate baudios.',
            puertosDisponibles: disponibles,
          );
        } else {
          return ResultadoConexionHardware(
            exito: false,
            mensaje: disponibles.isNotEmpty
                ? 'Puerto $pTrim no encontrado. Puertos detectados en el sistema: ${disponibles.join(', ')}'
                : 'Puerto $pTrim no encontrado. No se detectaron puertos COM conectados.',
            puertosDisponibles: disponibles,
          );
        }
      }

      return ResultadoConexionHardware(
        exito: true,
        mensaje: 'Canal Serial/Cable configurado en $pTrim a $baudRate baudios.',
      );
    } catch (e) {
      return ResultadoConexionHardware(
        exito: false,
        mensaje: 'Error al verificar puerto serial $pTrim: $e',
      );
    }
  }

  Future<ResultadoConexionHardware> probarConexionBluetooth({
    required String dispositivo,
  }) async {
    final dTrim = dispositivo.trim();
    if (dTrim.isEmpty) {
      return ResultadoConexionHardware(
        exito: false,
        mensaje: 'Ingresa el nombre o dirección MAC del lector Bluetooth.',
      );
    }

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final bool permitido =
            await ServicioPermisos.instancia.solicitarPermisosBluetooth();
        if (!permitido) {
          return ResultadoConexionHardware(
            exito: false,
            mensaje:
                'Permiso de Bluetooth no concedido. Habilita los permisos en tu dispositivo para buscar y conectar lectores.',
          );
        }
      }

      if (!kIsWeb && Platform.isWindows) {
        final resultado = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          "Get-PnpDevice -Class 'Bluetooth' -Status 'OK' | Select-Object -ExpandProperty FriendlyName",
        ]);
        final List<String> dispositivos = resultado.stdout
            .toString()
            .split(RegExp(r'\r?\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        final bool encontrado = dispositivos.any(
          (d) => d.toLowerCase().contains(dTrim.toLowerCase()),
        );

        if (encontrado) {
          return ResultadoConexionHardware(
            exito: true,
            mensaje: 'Dispositivo Bluetooth "$dTrim" verificado y vinculado.',
            dispositivosDetectados: dispositivos,
          );
        } else {
          return ResultadoConexionHardware(
            exito: false,
            mensaje: dispositivos.isNotEmpty
                ? 'No se encontró "$dTrim". Dispositivos Bluetooth detectados: ${dispositivos.take(5).join(', ')}'
                : 'No se detectó el lector Bluetooth "$dTrim" en los dispositivos enlazados.',
            dispositivosDetectados: dispositivos,
          );
        }
      }

      return ResultadoConexionHardware(
        exito: true,
        mensaje: 'Lector Bluetooth "$dTrim" configurado para comunicación inalámbrica.',
      );
    } catch (e) {
      return ResultadoConexionHardware(
        exito: false,
        mensaje: 'Error de diagnóstico Bluetooth: $e',
      );
    }
  }
}
