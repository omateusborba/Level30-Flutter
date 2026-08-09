import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/model/challenge.dart';
import '../../data/model/risk_assessment.dart';
import '../../data/service/notification_service.dart';

class NotificationProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _keyEnabled = 'notif_enabled';
  static const _keyHour = 'notif_hour';
  static const _keyMinute = 'notif_minute';

  bool _enabled = true;
  int _hour = 20;
  int _minute = 0;
  int _lastSentCount = 0;
  bool _permissionGranted = true;

  bool get enabled => _enabled;
  int get hour => _hour;
  int get minute => _minute;
  int get lastSentCount => _lastSentCount;
  bool get permissionGranted => _permissionGranted;
  String get timeLabel =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyEnabled) ?? true;
    _hour = prefs.getInt(_keyHour) ?? 20;
    _minute = prefs.getInt(_keyMinute) ?? 0;

    await checkPermission();

    if (_enabled) {
      await NotificationService().scheduleDailyReminder(
        hour: _hour,
        minute: _minute,
      );
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cobre o caso do usuário ativar a permissão em Configurações e voltar ao app.
    if (state == AppLifecycleState.resumed) {
      checkPermission();
    }
  }

  /// Consulta o status real da permissão de notificação no SO — necessário
  /// porque, no iOS, o prompt de permissão só aparece uma vez (main.dart);
  /// se for negado ali, toda chamada seguinte falha em silêncio.
  Future<void> checkPermission() async {
    final status = await Permission.notification.status;
    final granted = status.isGranted;
    if (granted != _permissionGranted) {
      _permissionGranted = granted;
      notifyListeners();
    }
  }

  Future<void> openSettings() => openAppSettings();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
