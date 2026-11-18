import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Manejador de mensajes en segundo plano o con la aplicación terminada.
/// DEBE ser una función de nivel superior (top-level) con la anotación `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('NotificationService [Background]: Inicialización de Firebase omitida o simulada: $e');
  }

  debugPrint('NotificationService [Background]: Mensaje recibido: ${message.messageId}');
  debugPrint('NotificationService [Background]: Título: ${message.notification?.title}');
  debugPrint('NotificationService [Background]: Datos: ${message.data}');

  // Si el mensaje es de datos puros (data-only payload), mostrar notificación local en Android/iOS
  if (message.notification == null && message.data.isNotEmpty) {
    await NotificationService.instancia.mostrarNotificacionLocal(
      id: message.hashCode,
      titulo: message.data['titulo']?.toString() ?? '⚠️ Alerta de Inventario',
      cuerpo: message.data['cuerpo']?.toString() ?? 'El stock de un producto ha alcanzado su umbral crítico.',
      payload: jsonEncode(message.data),
    );
  }
}

/// Servicio integral para gestión de Notificaciones Push (FCM) y Notificaciones Locales (OS-level).
class NotificationService {
  static final NotificationService instancia = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _messaging;

  bool _inicializado = false;
  bool get estaInicializado => _inicializado;

  /// Nombre del canal prioritario para alertas de inventario
  static const String canalAlertasId = 'canal_alertas_stock';
  static const String canalAlertasNombre = 'Alertas de Stock Crítico';
  static const String canalAlertasDesc = 'Canal de máxima prioridad para alertas de stock crítico y reabastecimiento.';

  /// Canal Android de máxima importancia para interrumpir con sonido/vibración
  static const AndroidNotificationChannel canalAlertasStock = AndroidNotificationChannel(
    canalAlertasId,
    canalAlertasNombre,
    description: canalAlertasDesc,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  /// Callback opcional cuando el usuario toca una notificación
  void Function(Map<String, dynamic> data)? onNotificacionTocada;

  /// Inicializa los plugins nativos y configura los escuchas de FCM
  Future<void> inicializar({
    bool solicitarPermisosAutomatico = true,
    void Function(Map<String, dynamic> data)? onSelectNotification,
  }) async {
    if (_inicializado) return;

    onNotificacionTocada = onSelectNotification;

    // 1. Verificar si la plataforma actual soporta notificaciones nativas móviles
    final bool esMovil = !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
    if (!esMovil && !kIsWeb) {
      debugPrint('NotificationService: Plataforma de escritorio detectada. Modo notificaciones móviles desactivado.');
      _inicializado = true;
      return;
    }

    try {
      // 2. Inicializar Firebase si aún no ha sido inicializado en main.dart
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp();
        } catch (e) {
          debugPrint('NotificationService: Firebase.initializeApp() omitido o requiere google-services: $e');
        }
      }

      // 3. Inicializar FlutterLocalNotificationsPlugin para el sistema operativo
      const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInitSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidInitSettings,
        iOS: darwinInitSettings,
        macOS: darwinInitSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final Map<String, dynamic> data = jsonDecode(response.payload!);
              onNotificacionTocada?.call(data);
            } catch (e) {
              debugPrint('NotificationService: Error al decodificar payload de notificación: $e');
            }
          }
        },
      );

      // 4. Crear canal en Android (Requerido en Android 8.0 Oreo en adelante)
      if (!kIsWeb && Platform.isAndroid) {
        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(canalAlertasStock);
      }

      // 5. Configurar Firebase Messaging si Firebase está activo
      if (Firebase.apps.isNotEmpty) {
        _messaging = FirebaseMessaging.instance;

        // Registrar background handler
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        // Solicitar permisos en iOS y Android 13+
        if (solicitarPermisosAutomatico) {
          await solicitarPermisos();
        }

        // Configurar opciones de presentación en primer plano para iOS
        await _messaging?.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // 6. Escuchar mensajes cuando la app está en PRIMER PLANO (Foreground)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('NotificationService [Foreground]: Mensaje recibido: ${message.messageId}');
          _procesarMensajeEntrante(message);
        });

        // 7. Escuchar cuando el usuario toca la notificación y la app estaba en SEGUNDO PLANO
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('NotificationService [OpenedApp]: Notificación pulsada desde segundo plano');
          onNotificacionTocada?.call(message.data);
        });

        // 8. Verificar si la app fue abierta desde un estado TERMINADO por tocar una notificación
        final RemoteMessage? initialMessage = await _messaging?.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('NotificationService [InitialMessage]: App iniciada por notificación');
          onNotificacionTocada?.call(initialMessage.data);
        }

        // 9. Suscribirse por defecto al tema de administración para alertas de inventario
        await suscribirATema('admin_topic');
      }

      _inicializado = true;
      debugPrint('NotificationService: Inicializado con éxito.');
    } catch (e) {
      debugPrint('NotificationService: Error durante la inicialización: $e');
    }
  }

  /// Solicita permisos de notificación al usuario (iOS y Android 13+)
  Future<bool> solicitarPermisos() async {
    if (_messaging == null) return false;

    try {
      final NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      final bool concedido = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      debugPrint('NotificationService: Estado de autorización de permisos: ${settings.authorizationStatus}');
      return concedido;
    } catch (e) {
      debugPrint('NotificationService: Error al solicitar permisos: $e');
      return false;
    }
  }

  /// Suscribe el dispositivo actual a un tema de FCM (ej. 'admin_topic')
  Future<void> suscribirATema(String tema) async {
    if (_messaging == null) return;
    try {
      await _messaging!.subscribeToTopic(tema);
      debugPrint('NotificationService: Dispositivo suscrito con éxito al tema: $tema');
    } catch (e) {
      debugPrint('NotificationService: No se pudo suscribir al tema $tema: $e');
    }
  }

  /// Desuscribe el dispositivo de un tema de FCM
  Future<void> desuscribirDeTema(String tema) async {
    if (_messaging == null) return;
    try {
      await _messaging!.unsubscribeFromTopic(tema);
      debugPrint('NotificationService: Desuscrito del tema: $tema');
    } catch (e) {
      debugPrint('NotificationService: Error al desuscribir del tema $tema: $e');
    }
  }

  /// Obtiene el token FCM único de este dispositivo para pruebas o envío dirigido
  Future<String?> obtenerTokenDispositivo() async {
    if (_messaging == null) return null;
    try {
      final token = await _messaging!.getToken();
      debugPrint('NotificationService: FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('NotificationService: Error al obtener FCM Token: $e');
      return null;
    }
  }

  /// Procesa el mensaje recibido en primer plano y muestra un banner OS con alta prioridad
  Future<void> _procesarMensajeEntrante(RemoteMessage message) async {
    final notif = message.notification;
    final titulo = notif?.title ?? message.data['titulo']?.toString() ?? '⚠️ Alerta de Inventario';
    final cuerpo = notif?.body ?? message.data['cuerpo']?.toString() ?? 'Un producto requiere atención inmediata.';

    await mostrarNotificacionLocal(
      id: message.hashCode,
      titulo: titulo,
      cuerpo: cuerpo,
      payload: jsonEncode(message.data),
    );
  }

  /// Muestra una notificación en la barra de estado del sistema (OS-level)
  Future<void> mostrarNotificacionLocal({
    required int id,
    required String titulo,
    required String cuerpo,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      canalAlertasId,
      canalAlertasNombre,
      channelDescription: canalAlertasDesc,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFEF6C00), // Naranja advertencia corporativo
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _localNotifications.show(
        id: id,
        title: titulo,
        body: cuerpo,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('NotificationService: Error al presentar notificación local: $e');
    }
  }
}

