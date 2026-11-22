import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();
  static const _channelId = 'klubb_updates';
  static const _webVapidKey =
      'BBZ7uspbC4JmZPLhsdd26_9E2LRjxchdlDvHaMpCE8Cm6oSx9r6JdJjejqEs3RX_Z2EBLbLrWaPtajcU9xqniyY';
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<String>? _installationSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  String? _installationId;
  bool _initialized = false;

  bool get _supported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> initialize() async {
    if (!_supported || _initialized) return;
    if (!kIsWeb) {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _local.initialize(settings: settings);
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              'Club updates',
              description: 'Announcements, events, and club chat messages',
              importance: Importance.high,
            ),
          );
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
    }
    _messageSubscription = FirebaseMessaging.onMessage.listen(_showForeground);
    _installationSubscription = _messaging.onRegistered.listen((
      installationId,
    ) {
      _installationId = installationId;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) unawaited(_saveToken(installationId, userId));
    });
    _initialized = true;
  }

  Future<void> registerForUser(String userId) async {
    if (!_supported || !_initialized) return;
    if (kIsWeb && _webVapidKey.isEmpty) {
      debugPrint('Klubb web push needs FIREBASE_WEB_VAPID_KEY at build time.');
      return;
    }
    try {
      final permission = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Klubb push permission was denied.');
        return;
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken;
        for (var attempt = 0; attempt < 10 && apnsToken == null; attempt++) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken == null) {
            await Future<void>.delayed(const Duration(seconds: 1));
          }
        }
        if (apnsToken == null) {
          debugPrint(
            'APNs token is not available yet; will register on next launch.',
          );
          return;
        }
      }
      if (kIsWeb) {
        // The FlutterFire web implementation registers the default
        // firebase-messaging-sw.js under its dedicated push scope.
        await _messaging.register(vapidKey: _webVapidKey);
      } else {
        await _messaging.register();
      }
    } catch (error, stackTrace) {
      debugPrint('Could not register Klubb push token: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _saveToken(String installationId, String userId) async {
    try {
      if (Supabase.instance.client.auth.currentUser?.id != userId) return;
      await Supabase.instance.client.rpc(
        'register_device_push_token',
        params: {
          'p_token': installationId,
          'p_platform': kIsWeb
              ? 'web'
              : defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        },
      );
      debugPrint('Registered push token for Klubb user $userId.');
    } catch (error) {
      debugPrint('Could not save Klubb push token: $error');
    }
  }

  Future<void> unregisterCurrentToken() async {
    if (!_supported ||
        !_initialized ||
        Supabase.instance.client.auth.currentUser == null) {
      return;
    }
    try {
      final installationId = _installationId;
      if (installationId == null || installationId.isEmpty) return;
      await Supabase.instance.client.rpc(
        'unregister_device_push_token',
        params: {'p_token': installationId},
      );
    } catch (error) {
      debugPrint('Could not unregister Klubb push token: $error');
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }
    if (kIsWeb) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('${title ?? 'Klubb'}\n${body ?? ''}'),
        ),
      );
      return;
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Club updates',
        channelDescription: 'Announcements, events, and club chat messages',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );
    await _local.show(
      id: message.hashCode,
      title: title ?? 'Klubb',
      body: body ?? '',
      notificationDetails: details,
    );
  }

  Future<void> dispose() async {
    await _installationSubscription?.cancel();
    await _messageSubscription?.cancel();
  }
}
