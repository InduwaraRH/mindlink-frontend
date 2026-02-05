import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'login_screen.dart'; // Import the separated login screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Notifications
  final notificationService = NotificationService();
  await notificationService.init();

  // 2. Schedule Daily Check-in (e.g., at 8:00 PM)
  await notificationService.scheduleDailyCheckIn(20, 0);

  runApp(const MindLinkApp());
}

class MindLinkApp extends StatelessWidget {
  const MindLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // --- CALM VISUAL DESIGN ---
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
        primaryColor: const Color(0xFF607D8B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF607D8B),
          primary: const Color(0xFF607D8B),
          secondary: const Color(0xFF90A4AE),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF607D8B),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF546E7A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF37474F), fontSize: 16),
          bodyMedium: TextStyle(color: Color(0xFF455A64), fontSize: 14),
          titleLarge: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold),
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}