import 'package:flutter/material.dart'; // <--- ADDED THIS for Colors
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
        print("Notification clicked: ${response.payload}");
      },
    );

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  // --- 1. DAILY MOOD REMINDER ---
  Future<void> scheduleDailyCheckIn(int hour, int minute) async {
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
// --- REPLACE YOUR EXISTING scheduleTaskReminder WITH THIS ---
  Future<void> scheduleTaskReminder(int taskId, String taskTitle, DateTime dueDate) async {
    // 1. Calculate the alert time (1 hour before due date)
    final scheduledTime = dueDate.subtract(const Duration(hours: 1));
    
    // 2. DEBUG PRINTS (Look at your console when you save a task)
    print("---------------- NOTIFICATION DEBUG ----------------");
    print("Current System Time: ${DateTime.now()}");
    print("User Selected Deadline: $dueDate");
    print("Calculated Alert Time (-1 hr): $scheduledTime");

    // 3. Check if time is in the past
    if (scheduledTime.isBefore(DateTime.now())) {
      print("❌ SKIPPED: Calculated time is in the past.");
      print("----------------------------------------------------");
      return;
    }

    // 4. Schedule the notification
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
    
    print("✅ SUCCESS: Notification scheduled for $scheduledTime");
    print("----------------------------------------------------");
  }

  // --- 3. INSTANT ALERT ---
  Future<void> showInstantNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'jitai_channel_id',
      'Smart Interventions',
      channelDescription: 'Real-time feedback and interventions',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF673AB7), // <--- FIXED: Wrapped in Color()
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
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
  
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}