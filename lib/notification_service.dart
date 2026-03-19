import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // ✅ Notification IDs — centralised so there are no collisions
  static const int _dailyEmaId = 0;
  static const int _jitaiInstantId = 999;
  // Task reminders use taskId directly as notification ID

  // ✅ Colombo timezone — set explicitly so daily EMA fires at the
  // correct local time regardless of emulator/device timezone setting.
  // This fixes the silent failure where tz.local defaults to UTC on emulators,
  // causing the 8pm notification to fire at a completely wrong time.
  static const String _localTimezone = 'Asia/Colombo';

  Future<void> init() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();

    // ✅ Set timezone explicitly to Colombo (UTC+5:30)
    tz.setLocalLocation(tz.getLocation(_localTimezone));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification tapped: payload=${response.payload}");
        // Future work: navigate to relevant screen based on payload
      },
    );

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FR-03: DAILY EMA MOOD CHECK-IN NOTIFICATION
  //
  // Proactively prompts the user to log their mood once per day at the
  // specified time. This operationalises the EMA (Ecological Momentary
  // Assessment) requirement — the system initiates mood capture rather
  // than waiting for the user to open the app.
  //
  // Scheduled with matchDateTimeComponents: DateTimeComponents.time so it
  // repeats daily at the same time automatically without rescheduling.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> scheduleDailyCheckIn(int hour, int minute) async {
    if (kIsWeb) return;

    // Cancel any existing daily notification before rescheduling
    // to prevent duplicate notifications if init() is called multiple times
    await flutterLocalNotificationsPlugin.cancel(_dailyEmaId);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      _dailyEmaId,
      '🌿 MindLink Check-in',
      'How are you feeling today? Take 30 seconds to log your mood.',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_ema_channel',
          'Daily Mood Check-in',
          channelDescription:
              'Daily reminder to log your mood and wellbeing — part of the EMA tracking system',
          importance: Importance.high,
          priority: Priority.high,
          // ✅ Updated to thesis palette colour #607D8B
          color: Color(0xFF607D8B),
          enableVibration: true,
          playSound: true,
          // ✅ Show notification even if app is in foreground
          visibility: NotificationVisibility.public,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // ✅ Repeats daily at the same time without rescheduling
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_ema', // Used for navigation in future work
    );

    debugPrint(
        "✅ EMA daily check-in scheduled at $hour:${minute.toString().padLeft(2, '0')} (${'Asia/Colombo'})");
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FR-01: TASK DEADLINE REMINDER
  //
  // Fires 1 hour before a task's due date to remind the user.
  // Uses the taskId as the notification ID so each task has its own
  // notification that can be cancelled independently when the task is completed.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> scheduleTaskReminder(
      int taskId, String taskTitle, DateTime dueDate) async {
    if (kIsWeb) return;

    final scheduledTime = dueDate.subtract(const Duration(hours: 1));

    if (scheduledTime.isBefore(DateTime.now())) {
      debugPrint("⚠️ Task reminder skipped — due time already passed for: $taskTitle");
      return;
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      taskId,
      '⏰ Task Due Soon',
      '"$taskTitle" is due in 1 hour. You got this! 🚀',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_deadline_channel',
          'Task Deadlines',
          channelDescription: 'Alerts for tasks due within the next hour',
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFF607D8B),
          enableVibration: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'task_reminder_$taskId',
    );

    debugPrint("✅ Task reminder scheduled for: $taskTitle at $scheduledTime");
  }

  // Cancel a task reminder when the task is marked as done
  Future<void> cancelTaskReminder(int taskId) async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancel(taskId);
    debugPrint("🗑️ Cancelled reminder for task ID: $taskId");
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RC2 / FR-06: JITAI INSTANT NOTIFICATION
  //
  // Fires immediately when the JITAI system detects a state change.
  // This is the push-based delivery mechanism for RC2 — the system
  // proactively delivers an intervention rather than waiting for the
  // user to open the app and see the banner.
  //
  // State-specific messaging ensures the notification content is
  // contextually appropriate — CRISIS uses calming language,
  // ACADEMIC uses task-oriented language, MOTIVATION is celebratory.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> showJitaiNotification(String jitaiType) async {
    if (kIsWeb) return;

    String title;
    String body;
    Color notifColor;

    switch (jitaiType) {
      case "CRISIS":
        title = "🌿 MindLink — You're not alone";
        body = "We noticed you might be struggling. Open the app for support.";
        notifColor = const Color(0xFFB71C1C);
        break;
      case "ACADEMIC":
        title = "📚 Time to focus";
        body = "You have pending tasks. Open MindLink to get started.";
        notifColor = const Color(0xFF607D8B);
        break;
      case "MOTIVATION":
        title = "🎉 You're on a roll!";
        body = "Great momentum today. Keep it going!";
        notifColor = const Color(0xFF1B5E20);
        break;
      default:
        return; // Don't fire a notification for NEUTRAL/NONE
    }

    await flutterLocalNotificationsPlugin.show(
      _jitaiInstantId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'jitai_channel',
          'Smart Interventions',
          channelDescription:
              'Context-aware JITAI notifications delivered based on your current state',
          importance: Importance.high,
          priority: Priority.high,
          color: notifColor,
          enableVibration: true,
          playSound: true,
          visibility: NotificationVisibility.public,
        ),
      ),
      payload: 'jitai_$jitaiType',
    );

    debugPrint("✅ JITAI notification fired for state: $jitaiType");
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Legacy method — kept for backwards compatibility with any existing calls.
  // Routes to showJitaiNotification internally.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> showInstantNotification(String title, String body) async {
    if (kIsWeb) return;

    await flutterLocalNotificationsPlugin.show(
      _jitaiInstantId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'jitai_channel',
          'Smart Interventions',
          channelDescription: 'Context-aware JITAI notifications',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF607D8B),
        ),
      ),
    );
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancelAll();
    debugPrint("🗑️ All notifications cancelled.");
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helper: computes the next occurrence of a given hour:minute in local time.
  // If the time has already passed today, schedules for tomorrow.
  // ─────────────────────────────────────────────────────────────────────────
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}