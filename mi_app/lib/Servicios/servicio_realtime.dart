import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'servicio_supabase.dart';
import 'servicio_conectividad.dart';
import 'servicio_sincronizacion.dart';
import 'servicio_autenticacion_supabase.dart';

/// Servicio singleton que gestiona las suscripciones reactivas multi-dispositivo vía Supabase Realtime (Fase 4b).
///
/// Principio de Arquitectura (Regla Crítica del Plan):
/// - **Realtime solo funciona como AVISO, no como fuente de verdad.**
/// - Al recibir un evento de cambio remoto (INSERT, UPDATE o DELETE), este servicio
///   consolida los avisos (debouncing) y dispara un **PULL incremental normal**.
/// - De este modo se preserva una sola ruta de escritura local (ACID en SQLite),
///   se evitan condiciones de carrera, duplicados y desórdenes relacionales.
/// - Si Realtime se desconecta o no está disponible, la app continúa operando
///   sin afectaciones mediante sincronización periódica y manual.
class ServicioRealtime with WidgetsBindingObserver {
  static final ServicioRealtime instancia = ServicioRealtime._();
  ServicioRealtime._();

  RealtimeChannel? _canal;
  bool _escuchando = false;
  Timer? _debounceTimer;
  StreamSubscription<bool>? _conectividadSub;
  SupabaseClient? _mockClient;

  /// Callback opcional invocado cada vez que llega un aviso y se dispara un ciclo de sincronización.
  VoidCallback? onAvisoRecibido;

  /// Tablas del negocio monitoreadas para avisos reactivos
  static const List<String> tablasMonitoreadas = [
    'productos',
    'ventas',
    'articulos_venta',
    'deudores',
    'abonos_venta',
    'movimientos_inventario',
    'colaboradores',
  ];

  bool get estaEscuchando => _escuchando;
  bool get tieneCanalActivo => _canal != null;

  @visibleForTesting
  void setMockClient(SupabaseClient? client) {
    _mockClient = client;
  }

  SupabaseClient? get _client => _mockClient ?? ServicioSupabase.instancia.client;

  /// Inicializa el servicio de Realtime registrando escuchas de ciclo de vida y conectividad.
  void inicializar() {
    WidgetsBinding.instance.addObserver(this);

    _conectividadSub?.cancel();
    _conectividadSub = ServicioConectividad.instancia.enLineaStream.listen((enLinea) {
      if (enLinea && _escuchando) {
        debugPrint('ServicioRealtime: Conexión recuperada. Re-suscribiendo y forzando PULL.');
        _reconectarYSincronizar();
      }
    });
  }

  /// Inicia la suscripción reactiva a las tablas de Supabase Realtime.
  /// Se ejecuta automáticamente cuando hay sesión activa y conexión.
  Future<void> iniciarEscucha({
    SupabaseClient? clientOverride,
    VoidCallback? onAviso,
  }) async {
    if (onAviso != null) onAvisoRecibido = onAviso;

    final client = clientOverride ?? _client;
    if (client == null) {
      debugPrint('ServicioRealtime: Modo local puro. Suscripción omitida.');
      return;
    }

    if (_escuchando && _canal != null) {
      debugPrint('ServicioRealtime: La escucha ya se encuentra activa.');
      return;
    }

    try {
      final canal = client.channel('public:planteapp_realtime');

      for (final tabla in tablasMonitoreadas) {
        canal.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: tabla,
          callback: (payload) {
            _procesarAvisoRemoto(tabla, payload);
          },
        );
      }

      canal.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          debugPrint('ServicioRealtime: Conectado y escuchando eventos multi-dispositivo.');
          _escuchando = true;
        } else if (status == RealtimeSubscribeStatus.closed ||
            status == RealtimeSubscribeStatus.channelError) {
          debugPrint('ServicioRealtime: Canal cerrado o en error ($status): $error');
          _escuchando = false;
        }
      });

      _canal = canal;
    } catch (e) {
      debugPrint('ServicioRealtime: Aviso al iniciar suscripción Realtime: $e');
      _escuchando = false;
      _canal = null;
    }
  }

  /// Procesa un aviso de cambio entrante. Aplica un Debounce de 600ms para evitar ráfagas
  /// múltiples si una sola venta genera avisos simultáneos en venta, detalle y movimientos.
  void _procesarAvisoRemoto(String tabla, PostgresChangePayload payload) {
    debugPrint(
      'ServicioRealtime: Aviso recibido en "$tabla" (${payload.eventType.name}). Encolando PULL incremental.',
    );

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _dispararPullIncremental();
    });
  }

  /// Dispara el PULL incremental sin bloquear la UI
  Future<void> _dispararPullIncremental() async {
    try {
      onAvisoRecibido?.call();
      await ServicioSincronizacion.instancia.sincronizar();
    } catch (e) {
      debugPrint('ServicioRealtime: Error al procesar PULL disparado por Realtime: $e');
    }
  }

  /// Tras caída y retorno de red, vuelve a suscribir y sincroniza desde el último cursor.
  Future<void> _reconectarYSincronizar() async {
    await detenerEscucha();
    await iniciarEscucha();
    await _dispararPullIncremental();
  }

  /// Cancela la suscripción a Realtime y libera los recursos del socket.
  Future<void> detenerEscucha({SupabaseClient? clientOverride}) async {
    _debounceTimer?.cancel();
    _escuchando = false;

    final client = clientOverride ?? _client;
    if (client != null && _canal != null) {
      try {
        await client.removeChannel(_canal!);
      } catch (e) {
        debugPrint('ServicioRealtime: Aviso al remover canal: $e');
      }
    }
    _canal = null;
    debugPrint('ServicioRealtime: Suscripción detenida.');
  }

  // ===========================================================================
  // Gestión de Ciclo de Vida de la App (Ahorro de batería y recursos)
  // ===========================================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Al volver al primer plano, reanudar Realtime y poner al día los datos locales
        if (ServicioAutenticacionSupabase.instancia.tieneSesionActiva ||
            ServicioSupabase.instancia.estaInicializado) {
          debugPrint('ServicioRealtime: App en primer plano. Reanudando Realtime y PULL.');
          iniciarEscucha().then((_) => _dispararPullIncremental());
        }
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Al pasar a segundo plano, pausar la conexión WebSocket para ahorrar datos y batería
        debugPrint('ServicioRealtime: App en segundo plano. Pausando canal.');
        detenerEscucha();
        break;

      default:
        break;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _conectividadSub?.cancel();
    _debounceTimer?.cancel();
    detenerEscucha();
  }
}
