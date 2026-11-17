import 'dart:async';
import 'package:flutter/foundation.dart';
import '../BaseDatos/base_datos.dart';
import '../Servicios/servicio_conectividad.dart';
import '../Servicios/servicio_sincronizacion.dart';
import '../Servicios/servicio_supabase.dart';

/// Estado visible para la interfaz de usuario respecto a la sincronización.
enum EstadoSincronizacionUI {
  sincronizado,
  pendiente,
  sincronizando,
  sinConexion,
  error,
  modoLocalPuro,
}

/// Controlador reactivo (ChangeNotifier) que expone el estado de sincronización a la UI de Planteapp.
class ControladorSincronizacion extends ChangeNotifier {
  final ServicioSincronizacion _servicioSync;
  final ServicioConectividad _servicioConectividad;
  final ServicioSupabase _servicioSupabase;

  bool _sincronizando = false;
  bool _enLinea = true;
  int _cambiosPendientes = 0;
  DateTime? _ultimaSyncExitosa;
  String? _ultimoError;
  StreamSubscription<bool>? _conectividadSub;
  Timer? _timerMonitoreo;

  ControladorSincronizacion({
    ServicioSincronizacion? servicioSync,
    ServicioConectividad? servicioConectividad,
    ServicioSupabase? servicioSupabase,
  })  : _servicioSync = servicioSync ?? ServicioSincronizacion.instancia,
        _servicioConectividad =
            servicioConectividad ?? ServicioConectividad.instancia,
        _servicioSupabase = servicioSupabase ?? ServicioSupabase.instancia {
    _iniciarEscuchas();
  }

  bool get sincronizando => _sincronizando;
  bool get enLinea => _enLinea;
  int get cambiosPendientes => _cambiosPendientes;
  DateTime? get ultimaSyncExitosa => _ultimaSyncExitosa;
  String? get ultimoError => _ultimoError;

  EstadoSincronizacionUI get estadoUI {
    if (_servicioSupabase.modoLocalPuro) {
      return EstadoSincronizacionUI.modoLocalPuro;
    }
    if (_sincronizando) {
      return EstadoSincronizacionUI.sincronizando;
    }
    if (!_enLinea) {
      return EstadoSincronizacionUI.sinConexion;
    }
    if (_ultimoError != null && _ultimoError!.isNotEmpty) {
      return EstadoSincronizacionUI.error;
    }
    if (_cambiosPendientes > 0) {
      return EstadoSincronizacionUI.pendiente;
    }
    return EstadoSincronizacionUI.sincronizado;
  }

  void _iniciarEscuchas() {
    _servicioConectividad.tieneConexion().then((conectado) {
      _enLinea = conectado;
      actualizarContadorPendientes();
      if (_enLinea && !_servicioSupabase.modoLocalPuro) {
        sincronizarEnSegundoPlano();
      }
    });

    _conectividadSub = _servicioConectividad.enLineaStream.listen((conectado) {
      final antesOffline = !_enLinea && conectado;
      _enLinea = conectado;
      notifyListeners();

      // Disparador reactivo: al reconectar tras caída de red, sincronizar automáticamente
      if (antesOffline && !_servicioSupabase.modoLocalPuro) {
        sincronizarEnSegundoPlano();
      }
    });

    // Monitoreo periódico ligero de la cola (cada 30 segundos)
    _timerMonitoreo = Timer.periodic(const Duration(seconds: 30), (_) {
      actualizarContadorPendientes();
    });
  }

  /// Consulta el número de mutaciones en cola pendientes de subir a la nube
  Future<void> actualizarContadorPendientes() async {
    try {
      final db = await BaseDeDatos.instancia.database;
      final res = await db.rawQuery('SELECT COUNT(*) as total FROM cola_sincronizacion');
      _cambiosPendientes = (res.first['total'] as num?)?.toInt() ?? 0;

      final config = await db.query('config_sync', where: 'id = 1');
      if (config.isNotEmpty && config.first['ultima_sync_exitosa'] != null) {
        _ultimaSyncExitosa = DateTime.tryParse(config.first['ultima_sync_exitosa'].toString());
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Dispara una sincronización manual solicitada explícitamente por el usuario
  Future<ResultadoSincronizacion> sincronizarManual() async {
    if (_sincronizando) {
      return ResultadoSincronizacion(exitoso: false, error: 'Sincronización en curso.');
    }

    _sincronizando = true;
    _ultimoError = null;
    notifyListeners();

    try {
      final res = await _servicioSync.sincronizar();
      if (!res.exitoso && res.error != null) {
        _ultimoError = res.error;
      }
      await actualizarContadorPendientes();
      return res;
    } catch (e) {
      _ultimoError = e.toString();
      return ResultadoSincronizacion(exitoso: false, error: e.toString());
    } finally {
      _sincronizando = false;
      notifyListeners();
    }
  }

  /// Sincronización silenciosa en segundo plano sin interrumpir ni bloquear la navegación
  void sincronizarEnSegundoPlano() {
    if (_sincronizando || _servicioSupabase.modoLocalPuro) return;
    sincronizarManual().ignore();
  }

  @override
  void dispose() {
    _conectividadSub?.cancel();
    _timerMonitoreo?.cancel();
    super.dispose();
  }
}
