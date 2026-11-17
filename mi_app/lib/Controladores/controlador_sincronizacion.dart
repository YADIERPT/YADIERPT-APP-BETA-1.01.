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
  bool _syncHabilitada = true;
  String _dispositivoId = '';
  List<Map<String, dynamic>> _registroErrores = [];
  bool? _mockModoLocalPuro;
  bool _usarMocks = false;
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
  bool get syncHabilitada => _syncHabilitada;
  String get dispositivoId => _dispositivoId;
  List<Map<String, dynamic>> get registroErrores => List.unmodifiable(_registroErrores);
  bool get modoLocalPuro => _mockModoLocalPuro ?? _servicioSupabase.modoLocalPuro;

  EstadoSincronizacionUI get estadoUI {
    if (modoLocalPuro) {
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
      cargarDetallesCompletos();
      if (_enLinea && !_servicioSupabase.modoLocalPuro && _syncHabilitada) {
        sincronizarEnSegundoPlano();
      }
    });

    _conectividadSub = _servicioConectividad.enLineaStream.listen((conectado) {
      final antesOffline = !_enLinea && conectado;
      _enLinea = conectado;
      notifyListeners();

      // Disparador reactivo: al reconectar tras caída de red, sincronizar automáticamente
      if (antesOffline && !_servicioSupabase.modoLocalPuro && _syncHabilitada) {
        sincronizarEnSegundoPlano();
      }
    });

    // Monitoreo periódico ligero de la cola (cada 30 segundos)
    _timerMonitoreo = Timer.periodic(const Duration(seconds: 30), (_) {
      actualizarContadorPendientes();
    });
  }

  /// Carga la configuración completa de sincronización, dispositivo, estado y registros de error
  Future<void> cargarDetallesCompletos() async {
    if (_usarMocks) return;
    try {
      final db = await BaseDeDatos.instancia.database;
      final config = await db.query('config_sync', where: 'id = 1');
      if (config.isNotEmpty) {
        _dispositivoId = config.first['dispositivo_id']?.toString() ?? '';
        _syncHabilitada = (config.first['sync_habilitada'] as num?)?.toInt() == 1;
        if (config.first['ultima_sync_exitosa'] != null) {
          _ultimaSyncExitosa = DateTime.tryParse(config.first['ultima_sync_exitosa'].toString());
        }
      }

      final res = await db.rawQuery('SELECT COUNT(*) as total FROM cola_sincronizacion');
      _cambiosPendientes = (res.first['total'] as num?)?.toInt() ?? 0;

      final erroresRes = await db.query(
        'cola_sincronizacion',
        where: 'ultimo_error IS NOT NULL OR intentos > 0',
        orderBy: 'created_at DESC',
        limit: 15,
      );
      _registroErrores = List<Map<String, dynamic>>.from(erroresRes);
      notifyListeners();
    } catch (_) {}
  }

  /// Activa o pausa la sincronización automática con la nube
  Future<void> alternarSyncHabilitada(bool habilitar) async {
    _syncHabilitada = habilitar;
    notifyListeners();
    if (_usarMocks) return;
    try {
      final db = await BaseDeDatos.instancia.database;
      await db.update(
        'config_sync',
        {'sync_habilitada': habilitar ? 1 : 0},
        where: 'id = 1',
      );
      if (habilitar) {
        sincronizarEnSegundoPlano();
      }
    } catch (_) {}
  }

  /// Consulta el número de mutaciones en cola pendientes de subir a la nube
  Future<void> actualizarContadorPendientes() async {
    if (_usarMocks) return;
    try {
      final db = await BaseDeDatos.instancia.database;
      final res = await db.rawQuery('SELECT COUNT(*) as total FROM cola_sincronizacion');
      _cambiosPendientes = (res.first['total'] as num?)?.toInt() ?? 0;

      final config = await db.query('config_sync', where: 'id = 1');
      if (config.isNotEmpty) {
        _syncHabilitada = (config.first['sync_habilitada'] as num?)?.toInt() == 1;
        if (config.first['ultima_sync_exitosa'] != null) {
          _ultimaSyncExitosa = DateTime.tryParse(config.first['ultima_sync_exitosa'].toString());
        }
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

    if (_usarMocks) {
      _sincronizando = false;
      _cambiosPendientes = 0;
      _ultimaSyncExitosa = DateTime.now();
      notifyListeners();
      return ResultadoSincronizacion(
        exitoso: true,
        registrosSubidos: 1,
        registrosDescargados: 0,
      );
    }

    try {
      final res = await _servicioSync.sincronizar();
      if (!res.exitoso && res.error != null) {
        _ultimoError = res.error;
      }
      await cargarDetallesCompletos();
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
    if (_sincronizando || _servicioSupabase.modoLocalPuro || !_syncHabilitada) return;
    sincronizarManual().ignore();
  }

  /// Reinicia el contador de reintentos para los elementos con error en la cola y ejecuta una sincronización
  Future<ResultadoSincronizacion> reintentarErrores() async {
    if (_usarMocks) {
      _registroErrores = [];
      _ultimoError = null;
      notifyListeners();
      return await sincronizarManual();
    }
    try {
      final db = await BaseDeDatos.instancia.database;
      await db.update(
        'cola_sincronizacion',
        {'intentos': 0, 'ultimo_error': null},
        where: 'ultimo_error IS NOT NULL OR intentos > 0',
      );
      _ultimoError = null;
      return await sincronizarManual();
    } catch (e) {
      _ultimoError = e.toString();
      notifyListeners();
      return ResultadoSincronizacion(exitoso: false, error: e.toString());
    }
  }

  /// Utilidad de pruebas automatizadas para inyectar estados sin requerir persistencia SQLite física
  @visibleForTesting
  void setMockValores({
    bool? enLinea,
    bool? sincronizando,
    int? cambiosPendientes,
    DateTime? ultimaSyncExitosa,
    String? ultimoError,
    bool? syncHabilitada,
    String? dispositivoId,
    List<Map<String, dynamic>>? registroErrores,
    bool? modoLocalPuro,
  }) {
    _usarMocks = true;
    if (enLinea != null) _enLinea = enLinea;
    if (sincronizando != null) _sincronizando = sincronizando;
    if (cambiosPendientes != null) _cambiosPendientes = cambiosPendientes;
    if (ultimaSyncExitosa != null) _ultimaSyncExitosa = ultimaSyncExitosa;
    if (ultimoError != null) _ultimoError = ultimoError;
    if (syncHabilitada != null) _syncHabilitada = syncHabilitada;
    if (dispositivoId != null) _dispositivoId = dispositivoId;
    if (registroErrores != null) _registroErrores = List.from(registroErrores);
    if (modoLocalPuro != null) _mockModoLocalPuro = modoLocalPuro;
    notifyListeners();
  }

  @override
  void dispose() {
    _conectividadSub?.cancel();
    _timerMonitoreo?.cancel();
    super.dispose();
  }
}
