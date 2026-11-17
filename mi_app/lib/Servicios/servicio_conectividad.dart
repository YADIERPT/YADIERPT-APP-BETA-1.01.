import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Servicio de detección reactiva del estado de red.
class ServicioConectividad {
  static final ServicioConectividad instancia = ServicioConectividad._();
  ServicioConectividad._();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _controller;
  StreamSubscription? _subscription;
  bool? _conexionMock;

  /// Stream reactivo que emite `true` cuando se detecta conexión o `false` en caso de modo offline.
  Stream<bool> get enLineaStream {
    _controller ??= StreamController<bool>.broadcast(
      onListen: () {
        _subscription = _connectivity.onConnectivityChanged.listen((results) {
          final conectado = _interpretarResultados(results);
          _controller?.add(_conexionMock ?? conectado);
        });
      },
      onCancel: () {
        _subscription?.cancel();
        _subscription = null;
      },
    );
    return _controller!.stream;
  }

  /// Verifica si el dispositivo cuenta con interfaz de red activa en este momento.
  Future<bool> tieneConexion() async {
    if (_conexionMock != null) return _conexionMock!;
    try {
      final results = await _connectivity.checkConnectivity();
      return _interpretarResultados(results);
    } catch (_) {
      return false;
    }
  }

  bool _interpretarResultados(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Simula el estado de red en entornos de prueba automatizados
  void setMockConexion(bool? enLinea) {
    _conexionMock = enLinea;
    if (enLinea != null) {
      _controller?.add(enLinea);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller?.close();
    _controller = null;
  }
}
