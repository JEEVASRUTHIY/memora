import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/widgets.dart';
import '../models/reminder_log_model.dart';

class NotificationActionEvent {
  final String actionId;
  final String logId;
  NotificationActionEvent(this.actionId, this.logId);
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  
  final _actionController = StreamController<NotificationActionEvent>.broadcast();
  Stream<NotificationActionEvent> get actionStream => _actionController.stream;

  NotificationService({
    FirebaseMessaging? firebaseMessaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance,
        _localNotifications = localNotifications ?? FlutterLocalNotificationsPlugin();

  /// Initializes notification permissions and sets up listeners.
  Future<void> initialize() async {
    try {
      // 1. Request notification permissions (required for iOS and Android 13+)
      await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // 2. Initialize timezone database
      tz.initializeTimeZones();

      // 3. Initialize Flutter Local Notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final actionId = response.actionId;
          final logId = response.payload;
          if (actionId != null && logId != null) {
            _actionController.add(NotificationActionEvent(actionId, logId));
          }
        },
      );

      // Create Android custom notification channel with custom sound for background pushes
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        // Request exact alarm permission for Android 12+
        try {
          await androidImplementation.requestExactAlarmsPermission();
        } catch (_) {}

        // Request notification permission for Android 13+
        try {
          await androidImplementation.requestNotificationsPermission();
        } catch (_) {}

        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'reminder_channel_v3', // channel id
          'Reminders', // channel name
          description: 'Channel for reminder notifications',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('gentle_reminder'),
          playSound: true,
        );
        await androidImplementation.createNotificationChannel(channel);
      }

      // 4. Setup foreground message handler (triggered when app is active)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Handling a foreground message: ${message.messageId}');
        }
        final data = message.data;
        final notification = message.notification;
        if (data.isNotEmpty) {
          final logId = data['logId'];
          if (logId != null) {
            final tempLog = ReminderLogModel(
              logId: logId,
              reminderId: data['reminderId'] ?? '',
              patientId: data['patientId'] ?? '',
              description: data['description'] ?? notification?.body ?? '',
              instructions: data['instructions'],
              reminderType: data['reminderType'] ?? 'Reminder',
              scheduledTime: DateTime.now(),
              status: 'Triggered',
              actionTime: DateTime.now(),
              imageUrl: data['imageUrl'],
            );
            showInstantNotification(tempLog);
          }
        }
      });

      // 5. Setup message handler when app is opened from a notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('App opened from notification: ${message.messageId}');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing NotificationService: $e');
      }
    }
  }

  /// Schedules a zoned local notification for a reminder log.
  Future<void> scheduleReminderNotification(ReminderLogModel log) async {
    try {
      final now = DateTime.now();
      if (log.scheduledTime.isBefore(now)) {
        return; // Don't schedule in the past
      }

      final int notificationId = log.logId.hashCode;
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'reminder_channel_v3',
        'Reminders',
        channelDescription: 'Channel for reminder notifications',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('gentle_reminder'),
        playSound: true,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('completed', 'Mark Completed', showsUserInterface: true),
          AndroidNotificationAction('snooze', 'Snooze', showsUserInterface: true),
        ],
      );

      const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        sound: 'gentle_reminder.wav',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );
      
      final tzScheduledTime = tz.TZDateTime.from(log.scheduledTime.toUtc(), tz.UTC);
      
      try {
        await _localNotifications.zonedSchedule(
          notificationId,
          log.description,
          log.instructions ?? 'Time for your reminder.',
          tzScheduledTime,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: log.logId,
        );
      } on PlatformException catch (pe) {
        if (pe.code == 'exact_alarms_not_permitted') {
          if (kDebugMode) {
            print('Exact alarms not permitted, falling back to inexact scheduling.');
          }
          await _localNotifications.zonedSchedule(
            notificationId,
            log.description,
            log.instructions ?? 'Time for your reminder.',
            tzScheduledTime,
            platformDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: log.logId,
          );
        } else {
          rethrow;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling notification: $e');
      }
    }
  }

  /// Cancels a scheduled notification.
  Future<void> cancelReminderNotification(String logId) async {
    try {
      await _localNotifications.cancel(logId.hashCode);
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelling notification: $e');
      }
    }
  }

  /// Shows an instant local notification for a reminder log.
  Future<void> showInstantNotification(ReminderLogModel log) async {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    try {
      final int notificationId = log.logId.hashCode;
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'reminder_channel_v3',
        'Reminders',
        channelDescription: 'Channel for reminder notifications',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('gentle_reminder'),
        playSound: true,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('completed', 'Mark Completed', showsUserInterface: true),
          AndroidNotificationAction('snooze', 'Snooze', showsUserInterface: true),
        ],
      );

      const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        sound: 'gentle_reminder.wav',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );
      
      await _localNotifications.show(
        notificationId,
        log.description,
        log.instructions ?? 'Time for your reminder.',
        platformDetails,
        payload: log.logId,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error showing instant notification: $e');
      }
    }
  }

  /// Fetches the FCM registration token for the device.
  Future<String?> getToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      return token;
    } catch (e) {
      return null;
    }
  }

  /// Listens to token refreshes.
  Stream<String> get onTokenRefresh => _firebaseMessaging.onTokenRefresh;
}
