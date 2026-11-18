import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../BaseDatos/base_datos.dart';
import '../Modelos/colaborador.dart';
import 'secure_storage_service.dart';
import 'servicio_supabase.dart';
import 'servicio_conectividad.dart';

/// Servicio singleton que gestiona la autenticación silenciosa con Supabase Auth (Fase 4).
///
/// Principio rector Offline-First:
/// - El login local (PBKDF2-HMAC-SHA256) siempre tiene prioridad y opera 100% offline.
/// - Cuando hay conexión y Supabase está configurado, este servicio inicia sesión
///   silenciosamente en Supabase Auth usando el email y la contraseña plana del colaborador.
/// - Esto genera un JWT válido con `auth.uid()`, necesario para que las políticas
///   Row Level Security (RLS) en Postgres verifiquen el rol del usuario (`rol_actual()`).
/// - Los tokens de sesión se respaldan en [SecureStorageService] (Android Keystore / iOS Keychain).
class ServicioAutenticacionSupabase {
  static final ServicioAutenticacionSupabase instancia =
      ServicioAutenticacionSupabase._();
  ServicioAutenticacionSupabase._();

  SupabaseClient? _mockClient;

  @visibleForTesting
  void setMockClient(SupabaseClient? client) {
    _mockClient = client;
  }

  SupabaseClient? get _client =>
      _mockClient ?? ServicioSupabase.instancia.client;

  bool get estaInicializado =>
      _mockClient != null || ServicioSupabase.instancia.estaInicializado;

  /// Retorna el usuario actual autenticado en Supabase Auth, si existe sesión activa.
  User? get usuarioNube => _client?.auth.currentUser;

  /// Retorna la sesión actual de Supabase Auth.
  Session? get sesionActual => _client?.auth.currentSession;

  /// Indica si hay una sesión activa y autenticada en Supabase.
  bool get tieneSesionActiva => _client?.auth.currentSession != null;

  /// Inicia sesión silenciosamente en Supabase Auth tras un login local exitoso.
  ///
  /// No bloquea la interfaz de usuario ni arroja excepciones en caso de fallo
  /// de red o si el usuario aún no existe en Supabase Auth.
  Future<bool> iniciarSesionSilenciosa({
    required Colaborador colaborador,
    required String clavePlana,
    SupabaseClient? clientOverride,
  }) async {
    final client = clientOverride ?? _client;
    if (client == null) {
      debugPrint(
        'ServicioAutenticacionSupabase: Modo local puro activo (sin cliente Supabase).',
      );
      return false;
    }

    // Verificar conexión a internet si no es un mock directo
    if (clientOverride == null && _mockClient == null) {
      final hayRed = await ServicioConectividad.instancia.tieneConexion();
      if (!hayRed) {
        debugPrint(
          'ServicioAutenticacionSupabase: Sin conexión a internet. Se opera con login local.',
        );
        return false;
      }
    }

    final email = colaborador.emailAutenticacion;

    try {
      final AuthResponse res = await client.auth.signInWithPassword(
        email: email,
        password: clavePlana,
      );

      final session = res.session;
      final user = res.user ?? session?.user;

      if (session != null && user != null) {
        final authUserId = user.id;

        // 1. Guardar tokens de sesión en SecureStorage (Keystore/Keychain)
        await _guardarTokensSesion(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken ?? '',
          authUserId: authUserId,
        );

        // 2. Vincular auth_user_id en la base de datos local SQLite si no estaba asignado
        if (colaborador.authUserId == null || colaborador.authUserId != authUserId) {
          await _actualizarAuthUserIdLocal(colaborador.id, authUserId, email);
        }

        // 3. Vincular auth_user_id en la tabla colaboradores de Supabase si corresponde
        await _vincularAuthUserIdRemoto(client, colaborador.uuid, authUserId);

        debugPrint(
          'ServicioAutenticacionSupabase: Sesión silenciosa iniciada exitosamente para ${colaborador.id} (auth_user_id: $authUserId).',
        );
        return true;
      }
    } on AuthException catch (e) {
      debugPrint(
        'ServicioAutenticacionSupabase: Aviso AuthException al autenticar en nube ($email): ${e.message}',
      );
    } catch (e) {
      debugPrint(
        'ServicioAutenticacionSupabase: Advertencia en login silencioso ($email): $e',
      );
    }

    return false;
  }

  /// Restaura la sesión remota existente a partir de los tokens guardados en SecureStorage.
  Future<bool> restaurarSesion({SupabaseClient? clientOverride}) async {
    final client = clientOverride ?? _client;
    if (client == null) return false;

    // Si ya hay sesión activa en memoria
    if (client.auth.currentSession != null) return true;

    try {
      final secureStorage = SecureStorageService.instancia;
      final refreshToken =
          await secureStorage.leer('planteapp_supabase_refresh_token');

      if (refreshToken != null && refreshToken.trim().isNotEmpty) {
        final res = await client.auth.recoverSession(refreshToken.trim());
        if (res.session != null) {
          debugPrint(
            'ServicioAutenticacionSupabase: Sesión remota restaurada exitosamente desde Keystore.',
          );
          return true;
        }
      }
    } catch (e) {
      debugPrint(
        'ServicioAutenticacionSupabase: No se pudo restaurar la sesión remota: $e',
      );
    }

    return false;
  }

  /// Cierra la sesión en Supabase Auth y elimina los tokens persistidos en SecureStorage.
  Future<void> cerrarSesion({SupabaseClient? clientOverride}) async {
    final client = clientOverride ?? _client;

    try {
      if (client != null && client.auth.currentSession != null) {
        await client.auth.signOut();
      }
    } catch (e) {
      debugPrint(
        'ServicioAutenticacionSupabase: Aviso al cerrar sesión remota: $e',
      );
    }

    try {
      final secureStorage = SecureStorageService.instancia;
      await secureStorage.eliminar('planteapp_supabase_access_token');
      await secureStorage.eliminar('planteapp_supabase_refresh_token');
      await secureStorage.eliminar('planteapp_supabase_user_id');
    } catch (e) {
      debugPrint(
        'ServicioAutenticacionSupabase: Aviso al limpiar tokens de SecureStorage: $e',
      );
    }
  }

  /// Actualiza la contraseña en Supabase Auth si hay una sesión activa.
  Future<bool> cambiarClave({
    required String nuevaClave,
    SupabaseClient? clientOverride,
  }) async {
    final client = clientOverride ?? _client;
    if (client == null || client.auth.currentSession == null) return false;

    try {
      await client.auth.updateUser(
        UserAttributes(password: nuevaClave.trim()),
      );
      debugPrint(
        'ServicioAutenticacionSupabase: Clave actualizada exitosamente en Supabase Auth.',
      );
      return true;
    } catch (e) {
      debugPrint(
        'ServicioAutenticacionSupabase: Error al actualizar clave en Supabase Auth: $e',
      );
      return false;
    }
  }

  /// Permite crear o registrar un nuevo colaborador en Supabase Auth desde el rol Dueño.
  Future<String?> registrarUsuarioEnNube({
    required String email,
    required String clave,
    required String rol,
    required String nombre,
    required String colaboradorUuid,
    String? codigoLocal,
    SupabaseClient? clientOverride,
  }) async {
    final client = clientOverride ?? _client;
    if (client == null) return null;

    try {
      final res = await client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: clave.trim(),
        data: {
          'nombre': nombre.trim(),
          'rol': rol,
          'colaborador_uuid': colaboradorUuid,
          'codigo_local': codigoLocal,
        },
      );

      final newAuthUserId = res.user?.id;
      if (newAuthUserId != null) {
        // Vincular en Supabase
        await _vincularAuthUserIdRemoto(client, colaboradorUuid, newAuthUserId);
      }
      return newAuthUserId;
    } catch (e) {
      debugPrint(
        'ServicioAutenticacionSupabase: Aviso al registrar usuario en Supabase Auth ($email): $e',
      );
      return null;
    }
  }

  // ===========================================================================
  // Métodos auxiliares de persistencia y enlace
  // ===========================================================================

  Future<void> _guardarTokensSesion({
    required String accessToken,
    required String refreshToken,
    required String authUserId,
  }) async {
    try {
      final secureStorage = SecureStorageService.instancia;
      await secureStorage.guardar(
        'planteapp_supabase_access_token',
        accessToken,
      );
      if (refreshToken.isNotEmpty) {
        await secureStorage.guardar(
          'planteapp_supabase_refresh_token',
          refreshToken,
        );
      }
      await secureStorage.guardar(
        'planteapp_supabase_user_id',
        authUserId,
      );
    } catch (e) {
      debugPrint('Aviso al guardar tokens de Supabase en SecureStorage: $e');
    }
  }

  Future<void> _actualizarAuthUserIdLocal(
    String codigoLocal,
    String authUserId,
    String email,
  ) async {
    try {
      final db = await BaseDeDatos.instancia.database;
      await db.update(
        'colaboradores',
        {
          'auth_user_id': authUserId,
          'email': email,
        },
        where: 'id = ? COLLATE NOCASE',
        whereArgs: [codigoLocal],
      );
    } catch (e) {
      debugPrint('Aviso al actualizar auth_user_id local: $e');
    }
  }

  Future<void> _vincularAuthUserIdRemoto(
    SupabaseClient client,
    String colaboradorUuid,
    String authUserId,
  ) async {
    try {
      await client
          .from('colaboradores')
          .update({'auth_user_id': authUserId})
          .eq('uuid', colaboradorUuid);
    } catch (e) {
      debugPrint('Aviso al vincular auth_user_id en tabla remota: $e');
    }
  }
}
