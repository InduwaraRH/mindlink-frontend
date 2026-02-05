import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ⚠️ REPLACE THIS WITH YOUR LOCAL IP (Use ipconfig/ifconfig to find it)
  // Emulator users use: 'http://10.0.2.2:8000';
  // Physical device users use: 'http://192.168.x.x:8000';
  // static const String baseUrl = 'http://10.0.2.2:8000'; 

  static const String baseUrl = "https://mindlink-backend-r6de.onrender.com";

  // --- 1. Fetch JITAI Intervention (The Smart Logic) ---
  static Future<Map<String, dynamic>> getJitaiIntervention(int userId) async {
    final url = Uri.parse('$baseUrl/jitai/$userId');
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"type": "NONE", "message": ""};
      }
    } catch (e) {
      print("Error fetching JITAI: $e");
      return {"type": "NONE", "message": "Connection Error"};
    }
  }

  // --- 2. Log Mood (For testing the banner) ---
  static Future<void> logMood(int userId, String content, int score) async {
    final url = Uri.parse('$baseUrl/thoughts/');
    await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "content": content,
        "mood_score": score,
        "owner_id": userId // Ensure your backend expects 'owner_id' or check your schemas
      }),
    );
  }
}