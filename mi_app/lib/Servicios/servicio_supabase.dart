import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Configuracion/supabase_config.dart';

/// Servicio singleton que administra el ciclo de vida del cliente Supabase.
///
/// Cumple la regla de arquitectura Offline-First: si no hay credenciales configuradas
/// o si ocurre un fallo durante la inicialización, la app opera sin interrupciones
/// en modo local puro.
class ServicioSupabase {
  static final ServicioSupabase instancia = ServicioSupabase._();
  ServicioSupabase._();

  bool _inicializado = false;
  SupabaseClient? _client;

  bool get estaInicializado => _inicializado && _client != null;
  bool get modoLocalPuro => !estaInicializado;
  SupabaseClient? get client => _client;

  /// Inicializa la conexión a Supabase.
  ///
  /// Soporta inyección de dependencias para pruebas (`clientOverride`) y parámetros
  /// de entorno `--dart-define` para producción.
  Future<void> inicializar({
    String? urlOverride,
    String? anonKeyOverride,
    SupabaseClient? clientOverride,
  }) async {
    if (clientOverride != null) {
      _client = clientOverride;
      _inicializado = true;
      debugPrint('ServicioSupabase: Cliente mock/inyectado inicializado.');
      return;
    }

    final url = (urlOverride ?? SupabaseConfig.url).trim();
    final anonKey = (anonKeyOverride ?? SupabaseConfig.anonKey).trim();

    if (url.isEmpty || anonKey.isEmpty) {
      debugPrint('ServicioSupabase: Modo local puro activo (sin llaves configuradas).');
      _inicializado = false;
      _client = null;
      return;
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        debug: kDebugMode,
      );
      _client = Supabase.instance.client;
      _inicializado = true;
      debugPrint('ServicioSupabase: Conectado a $url.');
    } catch (e) {
      debugPrint('ServicioSupabase: Advertencia en inicialización: $e. Operando en modo local.');
      _inicializado = false;
      _client = null;
    }
  }

  /// Limpia la instancia (utilizado para pruebas)
  @visibleForTesting
  void resetParaPruebas() {
    _inicializado = false;
    _client = null;
  }
}
