import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coordinates OneSignal notification events for sighting alerts across the app.
class NotificationService {
  static final ValueNotifier<Map<String, dynamic>?> pendingSightingTap =
      ValueNotifier<Map<String, dynamic>?>(null);

  static final ValueNotifier<int> sightingRefreshTick = ValueNotifier<int>(0);

  static bool _listenersInitialized = false;

  /// Register OneSignal foreground and click listeners once at app startup.
  static void initListeners() {
    if (_listenersInitialized) return;
    _listenersInitialized = true;

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final data = event.notification.additionalData;
      if (data != null && data['type'] == 'NEW_SIGHTING') {
        sightingRefreshTick.value++;
      }
    });

    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data != null && data['type'] == 'NEW_SIGHTING') {
        pendingSightingTap.value = Map<String, dynamic>.from(data);
      }
    });
  }

  /// Re-bind the logged-in driver's user ID to OneSignal on cold app launch.
  static Future<void> syncUserIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId != null && userId.isNotEmpty) {
      OneSignal.login(userId);
    }
  }

  static void clearPendingSightingTap() {
    pendingSightingTap.value = null;
  }
}
