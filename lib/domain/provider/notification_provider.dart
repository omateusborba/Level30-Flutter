import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/model/challenge.dart';
import '../../data/model/risk_assessment.dart';
import '../../data/service/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  static const _keyEnabled = 'notif_enabled';
  static const _keyHour = 'notif_hour';
  static const _keyMinute = 'notif_minute';

  bool _enabled = true;
  int _hour = 20;
  int _minute = 0;
  int _lastSentCount = 0;

  bool get enabled => _enabled;
  int get hour => _hour;
  int get minute => _minute;
  int get lastSentCount => _lastSentCount;
  String get timeLabel =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyEnabled) ?? true;
    _hour = prefs.getInt(_keyHour) ?? 20;
    _minute = prefs.getInt(_keyMinute) ?? 0;

    if (_enabled) {
      await NotificationService().scheduleDailyReminder(
        hour: _hour,
        minute: _minute,
      );
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);

    if (value) {
      await NotificationService()
          .scheduleDailyReminder(hour: _hour, minute: _minute);
    } else {
      await NotificationService().cancelAll();
    }
    notifyListeners();
  }

  Future<void> setReminderTime(int hour, int minute) async {
    _hour = hour;
    _minute = minute;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHour, hour);
    await prefs.setInt(_keyMinute, minute);

    if (_enabled) {
      await NotificationService()
          .scheduleDailyReminder(hour: hour, minute: minute);
    }
    notifyListeners();
  }

  Future<void> sendTest() => NotificationService().sendTest();

  Future<int> checkAndNotify({
    required List<Challenge> challenges,
    required List<RiskAssessment> risks,
  }) async {
    if (!_enabled) return 0;
    _lastSentCount = await NotificationService()
        .checkAndNotify(challenges: challenges, risks: risks);
    notifyListeners();
    return _lastSentCount;
  }

  Future<List<PendingNotificationRequest>> getPending() =>
      NotificationService().getPending();
}
