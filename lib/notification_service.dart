import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // <--- ADDED for kIsWeb
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

  Future<void> init() async {
    // --- WEB SAFE CHECK ---
    if (kIsWeb) return; 

    tz.initializeTimeZones();

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
        debugPrint("Notification clicked: ${response.payload}");
      },
    );

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // --- WEB SAFE CHECK ---
    if (kIsWeb) return;

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    // scheduleExactAlarm is Android-only, will crash on Web/iOS without check
    if (defaultTargetPlatform == TargetPlatform.android) {
       if (await Permission.scheduleExactAlarm.isDenied) {
         await Permission.scheduleExactAlarm.request();
       }
    }
  }

  // --- 1. DAILY MOOD REMINDER ---
  Future<void> scheduleDailyCheckIn(int hour, int minute) async {
    if (kIsWeb) return;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'How are you feeling?',
      'Take a moment to log your mood today. 🌿',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_channel_id',
          'Daily Reminders',
          channelDescription: 'Reminders to check in on your mood',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // --- 2. TASK DEADLINE ALERT ---
  Future<void> scheduleTaskReminder(int taskId, String taskTitle, DateTime dueDate) async {
    if (kIsWeb) return;

    final scheduledTime = dueDate.subtract(const Duration(hours: 1));
    
    if (scheduledTime.isBefore(DateTime.now())) {
      return;
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      taskId,
      'Task Due Soon: $taskTitle',
      'This task is due in 1 hour! You got this. 🚀',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel_id',
          'Task Deadlines',
          channelDescription: 'Alerts for upcoming deadlines',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // --- 3. INSTANT ALERT ---
  Future<void> showInstantNotification(String title, String body) async {
    if (kIsWeb) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'jitai_channel_id',
      'Smart Interventions',
      channelDescription: 'Real-time feedback and interventions',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF673AB7), 
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      999,
      title,
      body,
      details,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    // This is a logic helper, but tz.local can crash if init() wasn't run
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
  
  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}