import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:memora/core/theme/app_colors.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

/// Manages local notifications and FCM permission for reminders.
///
/// Notification ID = stable 31-bit hash of occurrenceId, so re-scheduling
/// the same occurrence never creates a duplicate (fixes the re-login bug).
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Initialise ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (notifResponse) {},
    );
    _initialized = true;
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  Future<void> requestPermissions() async {
    await Permission.notification.request();
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ── Stable notification ID ─────────────────────────────────────────────────

  /// Deterministic djb2-style 31-bit hash of occurrenceId.
  int _notifId(String occurrenceId) {
    var hash = 5381;
    for (final c in occurrenceId.codeUnits) {
      hash = ((hash << 5) + hash + c) & 0x7fffffff;
    }
    return hash;
  }

  /// Cancel one notification after confirmation.
  Future<void> cancel(String occurrenceId) async {
    await _plugin.cancel(_notifId(occurrenceId));
  }

  // ── Battery optimisation one-shot dialog ──────────────────────────────────

  static bool _batteryScreenShown = false;

  static Future<void> showBatteryOptimizationGuide(BuildContext context) async {
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

