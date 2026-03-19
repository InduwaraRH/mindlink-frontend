import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Android Emulator -> your PC localhost
  static const String baseUrl = "https://mindlink-backend-r6de.onrender.com";

  static Future<Map<String, dynamic>> getJitaiIntervention(int userId) async {
    final url = Uri.parse('$baseUrl/jitai/$userId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {"type": "NONE", "message": ""};
    } catch (_) {
      return {"type": "NONE", "message": "Connection Error"};
    }
  }

  static Future<void> sendJitaiFeedback(int eventId, int outcome) async {
    final url = Uri.parse('$baseUrl/jitai/feedback');
    await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"event_id": eventId, "outcome": outcome}),
    );
  }
}