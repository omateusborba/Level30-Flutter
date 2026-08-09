import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../data/model/challenge.dart';
import '../../data/model/risk_assessment.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'level30_channel';
  static const _channelName = 'Level30 Notificações';
  static const _channelDesc = 'Alertas inteligentes do Level30';
  static const _accentColor = Color(0xFF00FF9C);

  static const _idDailyReminder = 1;
  static const _idRiskBase = 100;
  static const _idMilestoneBase = 200;
  static const _idTest = 999;

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // Sem isso, o iOS não exibe banner/som quando o app está em primeiro
      // plano — a notificação "dispara" mas fica invisível (ex.: botão de
      // teste na própria tela de Notificações).
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    ));
  }

  // ─── canal de detalhes Android ───────────────────────────────────────────

  AndroidNotificationDetails get _androidDetails =>
      const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        color: _accentColor,
        icon: '@mipmap/ic_launcher',
      );

  NotificationDetails get _details => NotificationDetails(
        android: _androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  // ─── envio imediato ───────────────────────────────────────────────────────

  Future<void> sendLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) =>
      _local.show(id, title, body, _details, payload: payload);

  Future<void> sendTest() => sendLocalNotification(
        id: _idTest,
        title: '🧪 Notificação de teste',
        body: 'O sistema de alertas do Level30 está funcionando!',
      );

  Future<void> sendStreakRiskAlert(Challenge c) => sendLocalNotification(
        id: _idRiskBase,
        title: '⚠️ Sequência em risco!',
        body: '"${c.title}" corre risco. Não perca sua sequência!',
        payload: c.id,
      );

  Future<void> sendMilestoneAlert(Challenge c) => sendLocalNotification(
        id: _idMilestoneBase,
        title: '🎉 Marco atingido!',
        body: 'Você completou ${c.currentDay} dias em "${c.title}"! Incrível!',
        payload: c.id,
      );

  Future<void> sendMotivationAlert(String quote) => sendLocalNotification(
        id: 0,
        title: '💡 Citação motivacional',
        body: quote,
      );

  // ─── notificação agendada diária ─────────────────────────────────────────

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await _local.cancel(_idDailyReminder);

    final location = _safeLocation();
    final now = tz.TZDateTime.now(location);
    var scheduled =
        tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _local.zonedSchedule(
      _idDailyReminder,
      '⏰ Hora dos seus hábitos!',
      'Complete seus desafios de hoje e mantenha sua sequência! 🔥',
      scheduled,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() => _local.cancel(_idDailyReminder);

  Future<void> cancelAll() => _local.cancelAll();

  Future<List<PendingNotificationRequest>> getPending() =>
      _local.pendingNotificationRequests();

  // ─── checagem de risco (disparo em lote) ─────────────────────────────────

  Future<int> checkAndNotify({
    required List<Challenge> challenges,
    required List<RiskAssessment> risks,
  }) async {
    int sent = 0;
    for (var i = 0; i < challenges.length; i++) {
      final c = challenges[i];
      final risk = risks.firstWhere(
        (r) => r.challengeId == c.id,
        orElse: () => risks.first,
      );

      switch (risk.suggestedAction) {
        case SuggestedAction.celebrateMilestone:
          await sendLocalNotification(
            id: _idMilestoneBase + i,
            title: '🎉 Marco atingido!',
            body: 'Parabéns! Você completou ${c.currentDay} dias em "${c.title}"!',
            payload: c.id,
          );
          sent++;
        case SuggestedAction.suggestReplan:
          await sendLocalNotification(
            id: _idRiskBase + i,
            title: '🚨 "${c.title}" em risco crítico',
            body: 'Você está a ${c.totalDays - c.currentDay} dias do fim. Retome hoje!',
            payload: c.id,
          );
          sent++;
        case SuggestedAction.sendMotivation:
          await sendLocalNotification(
            id: _idRiskBase + i,
            title: '💪 Não desista agora!',
            body: '"${c.title}" precisa de você. Você chegou até aqui!',
            payload: c.id,
          );
          sent++;
        case SuggestedAction.sendReminder:
          await sendLocalNotification(
            id: _idRiskBase + i,
            title: '🔔 Lembrete: "${c.title}"',
            body: 'Dia ${c.currentDay + 1} de ${c.totalDays} esperando por você!',
            payload: c.id,
          );
          sent++;
        case SuggestedAction.none:
          break;
      }
    }
    return sent;
  }

  // ─── helpers ─────────────────────────────────────────────────────────────

  tz.Location _safeLocation() {
    try {
      return tz.getLocation('America/Sao_Paulo');
    } catch (_) {
      return tz.UTC;
    }
  }
}
