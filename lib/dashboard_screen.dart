import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mindlink_app/login_screen.dart';
import 'dart:convert';
import 'mood_chart.dart'; 
import 'chat_screen.dart'; 
import 'task_screen.dart'; 
import 'api_service.dart';
import 'mood_history_screen.dart'; // <--- IMPORT NEW SCREEN

class DashboardScreen extends StatefulWidget {
  final int userId;

  const DashboardScreen({super.key, required this.userId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController thoughtController = TextEditingController();
  List<dynamic> thoughts = [];
  double _currentMood = 5.0; 

  // --- VARIABLES FOR SMART BANNER ---
  String jitaiMessage = "";
  String jitaiType = "NONE"; 
  bool isLoadingJitai = true;

  @override
  void initState() {
    super.initState();
    fetchThoughts();
    _fetchSmartIntervention(); 
  }

  // --- 1. FETCH THOUGHTS ---
  Future<void> fetchThoughts() async {
    final url = Uri.parse('http://10.0.2.2:8000/thoughts/${widget.userId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          thoughts = jsonDecode(response.body);
          thoughts = thoughts.reversed.toList();
        });
      }
    } catch (e) {
      print("Error fetching: $e");
    }
  }

  // --- 2. FETCH SMART INTERVENTION ---
  Future<void> _fetchSmartIntervention() async {
    final result = await ApiService.getJitaiIntervention(widget.userId);
    if (mounted) {
      setState(() {
        jitaiType = result['type'];
        jitaiMessage = result['message'];
        isLoadingJitai = false;
      });
    }
  }

  // --- 3. SEND FEEDBACK (REWARD SIGNAL) ---
  Future<void> sendFeedback(int outcome) async {
    try {
      final url = Uri.parse('http://10.0.2.2:8000/jitai/feedback');
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": widget.userId, "outcome": outcome}),
      );
      print("Sent Reward Signal: $outcome");
    } catch (e) {
      print("Feedback Error: $e");
    }
  }

  // --- 4. CREATE ENTRY ---
  Future<void> createThought() async {
    if (thoughtController.text.isEmpty) return;

    final url = Uri.parse('http://10.0.2.2:8000/thoughts/?user_id=${widget.userId}');
    
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "content": thoughtController.text,
          "mood_score": _currentMood.toInt(), 
        }),
      );

      if (response.statusCode == 200) {
        thoughtController.clear();
        setState(() { _currentMood = 5.0; });
        
        // REFRESH DATA
        fetchThoughts(); 
        _fetchSmartIntervention(); 
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wellbeing check-in saved!')),
        );
      }
    } catch (e) { print("Error creating: $e"); }
  }

  Future<void> deleteThought(int thoughtId) async {
    final url = Uri.parse('http://10.0.2.2:8000/thoughts/$thoughtId');
    try {
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        fetchThoughts();
      }
    } catch (e) { print(e); }
  }

  Color getMoodColor(int score) {
    if (score <= 3) return Colors.redAccent;
    if (score <= 7) return Colors.orangeAccent;
    return Colors.green;
  }

  String getMoodEmoji(int score) {
    if (score <= 3) return "😫";
    if (score <= 7) return "😐";
    return "🤩";
  }

  // --- 5. BUILD SMART BANNER ---
  Widget _buildSmartBanner() {
    if (isLoadingJitai || jitaiType == "NONE") {
      return const SizedBox.shrink(); 
    }

    Color cardColor;
    IconData cardIcon;
    String titleText;
    VoidCallback onTapAction;

    switch (jitaiType) {
      case "CRISIS":
        cardColor = Colors.red.shade100;
        cardIcon = Icons.warning_amber_rounded;
        titleText = "⚠️ Crisis Alert";
        onTapAction = () { /* Navigate to Crisis Screen */ };
        break;
      case "ACADEMIC":
        cardColor = Colors.purple.shade100;
        cardIcon = Icons.assignment_late_outlined;
        titleText = "📚 Academic Focus";
        onTapAction = () {
           Navigator.push(context, MaterialPageRoute(builder: (c) => TaskScreen(userId: widget.userId)));
        };
        break;
      case "MOTIVATION":
        cardColor = Colors.green.shade100;
        cardIcon = Icons.sentiment_very_satisfied;
        titleText = "🎉 Keep it up!";
        onTapAction = () {};
        break;
      default:
        return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        sendFeedback(1);
        onTapAction();
        setState(() => jitaiType = "NONE");
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20, top: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(cardIcon, size: 28, color: Colors.black87),
                    const SizedBox(width: 10),
                    Text(titleText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () {
                    sendFeedback(0); 
                    setState(() => jitaiType = "NONE"); 
                  },
                )
              ],
            ),
            const SizedBox(height: 8),
            Text(jitaiMessage, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('MindLink Wellbeing'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (context) => const LoginScreen())
              );
            },
          ),
        ],
      ),
      

      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "tasks",
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => TaskScreen(userId: widget.userId)));
            },
            child: const Icon(Icons.check_circle_outline),
          ),
          const SizedBox(width: 15),
          FloatingActionButton(
            heroTag: "chat",
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(userId: widget.userId)));
            },
            child: const Icon(Icons.chat_bubble),
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            
            // --- INSERT SMART BANNER ---
            _buildSmartBanner(),

            // Check-in Card
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("How are you feeling?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(getMoodEmoji(_currentMood.toInt()), style: const TextStyle(fontSize: 30)),
                      Expanded(
                        child: Slider(
                          value: _currentMood,
                          min: 1, max: 10, divisions: 9,
                          activeColor: getMoodColor(_currentMood.toInt()),
                          label: _currentMood.toInt().toString(),
                          onChanged: (val) { setState(() { _currentMood = val; }); },
                        ),
                      ),
                      Text("${_currentMood.toInt()}/10", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: getMoodColor(_currentMood.toInt()))),
                    ],
                  ),
                  TextField(
                    controller: thoughtController,
                    decoration: InputDecoration(
                      hintText: 'Describe your feelings...',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: createThought,
                      icon: const Icon(Icons.check),
                      label: const Text("Log Check-in"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
      ),
    ],
  ),
),

// Mood Chart
MoodChart(thoughts: thoughts),

            // --- RECENT HISTORY HEADER ---
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Recent History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      // Navigate to History Screen
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => MoodHistoryScreen(userId: widget.userId))
                      ).then((_) {
                        // Refresh dashboard when coming back (in case user deleted something)
                        fetchThoughts();
                      });
                    },
                    child: const Text("View All"),
                  )
                ],
              ),
            ),

            // --- LIMITED TIMELINE (MAX 5) ---
            thoughts.isEmpty
                ? const Padding(padding: EdgeInsets.all(20), child: Text("No logs yet."))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shrinkWrap: true, 
                    physics: const NeverScrollableScrollPhysics(),
                    // LIMIT TO 5 ITEMS
                    itemCount: thoughts.length > 5 ? 5 : thoughts.length,
                    itemBuilder: (context, index) {
                      final item = thoughts[index];
                      final mood = item['mood_score'] ?? 5; 
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: getMoodColor(mood).withOpacity(0.2), child: Text(getMoodEmoji(mood))),
                          title: Text(item['content'], style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text("Mood Score: $mood/10", style: TextStyle(color: getMoodColor(mood))),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey), onPressed: () => deleteThought(item['id'])),
                        ),
                      );
                    },
                  ),
            
            const SizedBox(height: 60), // Extra space at bottom
          ],
        ),
      ),
    );
  }
}