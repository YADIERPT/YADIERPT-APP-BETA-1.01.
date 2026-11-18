/// Configuración central de Supabase para Planteapp.
///
/// Las credenciales se inyectan en tiempo de compilación con `--dart-define`:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
///
/// Si no se proporcionan, la aplicación corre de forma 100% local (modo local puro)
/// sin lanzar errores ni intentar llamadas a red.
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pwzptdoexpkdhzlzftso.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_DdA9AgS1eD6ym-iIQy-alQ_xqnasPWn',
  );

  /// Indica si la nube de Supabase está habilitada por entorno.
  static bool get estaConfigurado =>
      url.trim().isNotEmpty && anonKey.trim().isNotEmpty;
}
