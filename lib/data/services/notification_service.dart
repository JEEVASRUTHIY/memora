import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:memora/core/app_config.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:memora/data/repositories/user_repository.dart';
import 'package:memora/firebase_options.dart';

/// Top-level background message handler for Firebase Cloud Messaging.
/// Must be annotated with `@pragma('vm:entry-point')` so Flutter's isolate
/// entrypoint can invoke it when the app is in the background or killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
    } else {
      try {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      } catch (_) {
        await Firebase.initializeApp();
      }
    }
  } catch (_) {
    // Ignore: Firebase already initialized in this isolate.
  }

  // If the message has no notification payload (data-only message), display
  // a local notification so the user still receives the reminder/alert.
  if (message.notification == null && message.data.isNotEmpty) {
    final notifs = NotificationService();
    await notifs.init();
    await notifs.showNotificationFromData(message.data);
  }
}

/// Central service managing:
/// - Firebase Cloud Messaging (FCM) foreground and background notifications.
/// - Exact scheduled local notifications for reminders via flutter_local_notifications.
/// - Stable 31-bit notification ID hashing to prevent duplicate alerts.
/// - Token management, token refresh handling, and notification permissions.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static bool _permissionPrompted = false;

  /// Optional listener invoked when a notification is tapped by the user.
  static void Function(Map<String, dynamic> data)? onNotificationTapped;

  // ── Channels ───────────────────────────────────────────────────────────────

  static const AndroidNotificationChannel reminderChannel =
      AndroidNotificationChannel(
    'memora_reminders_v2',
    'Patient Reminders',
    description:
        'Notifications for scheduled medications and daily care reminders.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel alertChannel =
      AndroidNotificationChannel(
    'memora_alerts',
    'Care Circle Alerts',
    description:
        'Notifications for emergency SOS, link requests, and missed reminders.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    // 1. Initialize timezones
    try {
      tz.initializeTimeZones();
      final localName = DateTime.now().timeZoneName;
      if (tz.timeZoneDatabase.locations.containsKey(localName)) {
        tz.setLocalLocation(tz.getLocation(localName));
      }
    } catch (e) {
      debugPrint('[NotificationService] Timezone setup notice: $e');
    }

    // 2. Initialize FlutterLocalNotificationsPlugin
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationResponse(response);
      },
    );

    // 3. Create Android notification channels
    if (!kIsWeb) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(reminderChannel);
        await androidPlugin.createNotificationChannel(alertChannel);
      }

      // Register top-level FCM background message handler
      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);
    }

    // 4. Foreground presentation options (iOS/macOS)
    try {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    // 5. Handle FCM in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    // 6. Handle notification click when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationPayload(message.data);
    });

    // 7. Check if app was launched from a terminated-state notification
    _checkInitialNotification();

    // 8. Listen for token refreshes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && newToken.isNotEmpty) {
        try {
          await UserRepository().addFcmToken(uid, newToken);
        } catch (e) {
          debugPrint(
              '[NotificationService] Failed to update refreshed FCM token: $e');
        }
      }
    });

    // 9. Sync token if user is already signed in on startup
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      getFcmToken().then((token) {
        if (token != null && token.isNotEmpty) {
          UserRepository().addFcmToken(currentUid, token).catchError((_) {});
        }
      });
    }

    _initialized = true;
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  /// Requests notification permissions on Android (13+) and iOS/Web.
  Future<bool> requestPermissions() async {
    if (!kIsWeb) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Requests notification permissions only once across the current app session.
  Future<bool> requestPermissionsOnce() async {
    if (_permissionPrompted) return false;
    _permissionPrompted = true;
    return requestPermissions();
  }

  // ── FCM Token Retrieval ────────────────────────────────────────────────────

  /// Retrieves the device FCM registration token.
  /// Safely handles Web VAPID key requirements without throwing exceptions.
  Future<String?> getFcmToken() async {
    try {
      if (kIsWeb) {
        final vapidKey = AppConfig.fcmWebVapidKey;
        if (vapidKey == null || vapidKey.trim().isEmpty) {
          debugPrint(
            '[NotificationService] Web Push VAPID key is not configured in AppConfig.fcmWebVapidKey. '
            'Web push token generation was safely skipped.',
          );
          return null;
        }
        return await FirebaseMessaging.instance.getToken(
          vapidKey: vapidKey.trim(),
        );
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('[NotificationService] Error retrieving FCM token: $e');
      return null;
    }
  }

  // ── Notification Display & Schedulers ──────────────────────────────────────

  /// Display an immediate local notification (used for foreground FCM & alerts).
  Future<void> showNotification({
    required String title,
    required String body,
    int? id,
    String? channelId,
    String? payload,
  }) async {
    if (kIsWeb) return;

    final targetChannelId = channelId ?? reminderChannel.id;
    final targetChannel =
        targetChannelId == alertChannel.id ? alertChannel : reminderChannel;

    final androidDetails = AndroidNotificationDetails(
      targetChannel.id,
      targetChannel.name,
      channelDescription: targetChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationId =
        id ?? (DateTime.now().millisecondsSinceEpoch & 0x7fffffff);

    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: darwinDetails),
      payload: payload,
    );
  }

  /// Formats and displays an incoming FCM data payload.
  Future<void> showNotificationFromData(Map<String, dynamic> data) async {
    final type = data['type'] as String? ?? 'general';
    final occurrenceId = data['occurrenceId'] as String?;
    final notifId = occurrenceId != null
        ? _notifId(occurrenceId)
        : (DateTime.now().millisecondsSinceEpoch & 0x7fffffff);

    String title;
    String body;
    String channelId;

    switch (type) {
      case 'reminder':
        title = data['title'] as String? ?? 'Care Reminder';
        body = data['message'] as String? ??
            data['body'] as String? ??
            'Time for your scheduled care reminder.';
        channelId = reminderChannel.id;
        break;
      case 'linkRequest':
        title = 'Caregiver Link Request';
        body = data['message'] as String? ??
            'A caregiver has requested to connect to your care circle.';
        channelId = alertChannel.id;
        break;
      case 'linkApproved':
        title = 'Care Connection Approved';
        body = data['message'] as String? ??
            'Your caregiver link request has been approved.';
        channelId = alertChannel.id;
        break;
      case 'linkRejected':
        title = 'Care Connection Notice';
        body = data['message'] as String? ??
            'A caregiver link request was not approved.';
        channelId = alertChannel.id;
        break;
      case 'linkRemoved':
        title = 'Care Circle Updated';
        body = data['message'] as String? ??
            'A caregiver connection has been updated.';
        channelId = alertChannel.id;
        break;
      case 'missedReminder':
        title = 'Missed Reminder Alert';
        body = data['message'] as String? ??
            'A scheduled reminder was marked as missed.';
        channelId = alertChannel.id;
        break;
      default:
        title = data['title'] as String? ?? 'Memora Notice';
        body = data['message'] as String? ??
            data['body'] as String? ??
            'You have a new update in Memora.';
        channelId = alertChannel.id;
    }

    await showNotification(
      id: notifId,
      title: title,
      body: body,
      channelId: channelId,
      payload: jsonEncode(data),
    );
  }

  /// Schedules a future local notification for a reminder occurrence.
  Future<void> scheduleOccurrence({
    required String occurrenceId,
    required String title,
    String? body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (kIsWeb) return;

    final now = DateTime.now();
    if (scheduledTime.isBefore(now)) return;

    final notifId = _notifId(occurrenceId);
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    final androidDetails = AndroidNotificationDetails(
      reminderChannel.id,
      reminderChannel.name,
      channelDescription: reminderChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      notifId,
      title,
      body ?? 'Time for your scheduled reminder',
      tzTime,
      NotificationDetails(android: androidDetails, iOS: darwinDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  // ── Cancellation ───────────────────────────────────────────────────────────

  /// Deterministic djb2-style 31-bit hash of occurrenceId.
  int _notifId(String occurrenceId) {
    var hash = 5381;
    for (final c in occurrenceId.codeUnits) {
      hash = ((hash << 5) + hash + c) & 0x7fffffff;
    }
    return hash;
  }

  /// Cancel one notification by occurrenceId.
  Future<void> cancel(String occurrenceId) async {
    await _plugin.cancel(_notifId(occurrenceId));
  }

  /// Cancels all scheduled local notifications belonging to a reminder template.
  Future<void> cancelReminder(String reminderId) async {
    if (kIsWeb) return;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final req in pending) {
        if (req.payload != null && req.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(req.payload!) as Map<String, dynamic>;
            if (data['reminderId'] == reminderId) {
              await _plugin.cancel(req.id);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] cancelReminder failed: $e');
    }
  }

  /// Cancels all pending notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Internal Helpers ───────────────────────────────────────────────────────

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      // Show local notification for foreground alert
      showNotification(
        title: notification.title ?? 'Memora',
        body: notification.body ?? '',
        payload: jsonEncode(message.data),
      );
    } else if (message.data.isNotEmpty) {
      showNotificationFromData(message.data);
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _handleNotificationPayload(data);
      } catch (_) {}
    }
  }

  void _handleNotificationPayload(Map<String, dynamic> data) {
    if (data.isNotEmpty) {
      onNotificationTapped?.call(data);
    }
  }

  Future<void> _checkInitialNotification() async {
    try {
      // 1. Initial message from FCM
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null && initialMessage.data.isNotEmpty) {
        _handleNotificationPayload(initialMessage.data);
      }

      // 2. Initial notification from flutter_local_notifications
      final launchDetails =
          await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse?.payload != null) {
        final payload = launchDetails.notificationResponse!.payload!;
        if (payload.isNotEmpty) {
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            _handleNotificationPayload(data);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // ── Battery optimisation one-shot dialog ──────────────────────────────────

  static bool _batteryScreenShown = false;

  static Future<void> showBatteryOptimizationGuide(
      BuildContext context) async {
    if (_batteryScreenShown) return;
    _batteryScreenShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.text,
        title: const Text('Enable Reliable Reminders',
            style: TextStyle(color: AppColors.white)),
        content: const Text(
          'To ensure reminders always arrive on time, please disable battery '
          'optimization for Memora.\n\n'
          'Settings → Apps → Memora → Battery → Unrestricted',
          style: TextStyle(color: AppColors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later',
                style: TextStyle(color: AppColors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Permission.ignoreBatteryOptimizations.request();
            },
            child: const Text('Open Settings',
                style: TextStyle(color: AppColors.secondaryAccent)),
          ),
        ],
      ),
    );
  }
}
