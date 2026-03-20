import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mindlink_app/login_screen.dart';
import 'dart:convert';
import 'mood_chart.dart';
import 'chat_screen.dart';
import 'task_screen.dart';
import 'api_service.dart';
import 'mood_history_screen.dart';
import 'notification_service.dart';

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

  // ✅ FR-08: Task list for ProductivityChart
  List<dynamic> tasks = [];

  // --- VARIABLES FOR SMART BANNER ---
  String jitaiMessage = "";
  String jitaiType = "NONE";
  bool isLoadingJitai = true;
  int? _jitaiEventId;

  // Live context vector + expandable debug panel visibility
  List<dynamic> _contextVector = [];
  bool _showContextDebug = false;

  @override
  void initState() {
    super.initState();
    fetchThoughts();
    fetchTasks();
    _fetchSmartIntervention();
  }

  @override
  void dispose() {
    thoughtController.dispose();
    super.dispose();
  }

  Future<void> fetchThoughts() async {
    final url = Uri.parse('${ApiService.baseUrl}/thoughts/${widget.userId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          thoughts = jsonDecode(response.body);
          thoughts = thoughts.reversed.toList();
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> fetchTasks() async {
    final url = Uri.parse('${ApiService.baseUrl}/tasks/${widget.userId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() => tasks = jsonDecode(response.body));
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _fetchSmartIntervention() async {
    final result = await ApiService.getJitaiIntervention(widget.userId);
    if (!mounted) return;
    setState(() {
      jitaiType = result['type'] ?? "NONE";
      jitaiMessage = result['message'] ?? "";
      _jitaiEventId = result['event_id'];
      _contextVector = result['context_vector'] ?? [];
      isLoadingJitai = false;

      if (jitaiType == "NONE" && result['state'] != null) {
        jitaiType = result['state'];
      }
    });

    if (result['event_id'] != null &&
        jitaiType != "NONE" &&
        jitaiType != "NEUTRAL") {
      await NotificationService().showJitaiNotification(jitaiType);
    }
  }

  Future<void> _refreshAll() async {
    await fetchThoughts();
    await fetchTasks();
    await _fetchSmartIntervention();
  }

  Future<void> sendFeedback(int outcome) async {
    if (_jitaiEventId == null) return;
    try {
      await ApiService.sendJitaiFeedback(_jitaiEventId!, outcome);
      if (!mounted) return;
      setState(() => _jitaiEventId = null);
    } catch (e) {
      // ignore
    }
  }

  Future<void> createThought() async {
    if (thoughtController.text.isEmpty) return;

    final url =
        Uri.parse('${ApiService.baseUrl}/thoughts/?user_id=${widget.userId}');

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
        if (!mounted) return;
        setState(() => _currentMood = 5.0);
        await _refreshAll();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wellbeing check-in saved!')),
        );
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> deleteThought(int thoughtId) async {
    final url = Uri.parse('${ApiService.baseUrl}/thoughts/$thoughtId');
    try {
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        await _refreshAll();
      }
    } catch (e) {
      // ignore
    }
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

  String _buildExplanation(String state, List<dynamic> vector) {
    if (vector.isEmpty) return "";

    double mood = (vector[0] as num).toDouble();
    int pending = (vector[1] as num).toInt();
    int hour = (vector[2] as num).toInt();
    double completion = (vector[3] as num).toDouble();

    List<String> reasons = [];

    switch (state) {
      case "CRISIS":
        if (mood <= 3) reasons.add("mood ${mood.toInt()}/10");
        if (hour >= 22 || hour <= 4) reasons.add("late-night check-in (${hour}:00)");
        if (pending >= 4) reasons.add("$pending pending tasks");
        if (reasons.isEmpty) reasons.add("low mood detected");
        break;
      case "ACADEMIC":
        if (pending >= 4) reasons.add("$pending pending tasks");
        if (hour >= 9 && hour <= 18) reasons.add("daytime hours (${hour}:00)");
        if (mood >= 4 && mood <= 7) reasons.add("moderate mood (${mood.toInt()}/10)");
        if (reasons.isEmpty) reasons.add("high task load detected");
        break;
      case "MOTIVATION":
        if (mood >= 7) reasons.add("high mood (${mood.toInt()}/10)");
        if (completion >= 0.75) reasons.add("${(completion * 100).toInt()}% tasks complete");
        if (pending <= 2) reasons.add("only $pending tasks remaining");
        if (reasons.isEmpty) reasons.add("strong progress detected");
        break;
      case "NONE":
      case "NEUTRAL":
      default:
        if (pending == 0) reasons.add("no pending tasks");
        if (mood >= 4 && mood <= 7) reasons.add("stable mood (${mood.toInt()}/10)");
        if (reasons.isEmpty) reasons.add("no acute signals detected");
        break;
    }

    return "Why: ${reasons.join(' + ')}";
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RC2: Maps internal state labels to user-friendly display labels.
  // "JITAI" and raw state names are academic terms not meaningful to users.
  // ─────────────────────────────────────────────────────────────────────────
  String _getBannerTitle(String type) {
    switch (type) {
      case 'CRISIS':
        return '⚠️ Wellbeing Support';
      case 'ACADEMIC':
        return '📚 Focus Reminder';
      case 'MOTIVATION':
        return '🎉 You\'re on a roll!';
      default:
        return '💡 MindLink Tip';
    }
  }

  Widget _buildStateIndicator() {
    if (isLoadingJitai) return const SizedBox.shrink();

    final Map<String, Map<String, dynamic>> stateConfig = {
      "CRISIS": {
        "color": const Color(0xFFB71C1C),
        "bg": const Color(0xFFFFEBEE),
        "icon": Icons.favorite_outline,
        "label": "Wellbeing Support",
        "desc": "Low mood detected. Take it easy.",
      },
      "ACADEMIC": {
        "color": const Color(0xFF37474F),
        "bg": const Color(0xFFECEFF1),
        "icon": Icons.lightbulb_outline,
        "label": "Focus Reminder",
        "desc": "High task load. Stay focused.",
      },
      "MOTIVATION": {
        "color": const Color(0xFF1B5E20),
        "bg": const Color(0xFFE8F5E9),
        "icon": Icons.celebration_outlined,
        "label": "Great Progress!",
        "desc": "Strong momentum. Keep going!",
      },
      "NONE": {
        "color": const Color(0xFF546E7A),
        "bg": const Color(0xFFECEFF1),
        "icon": Icons.radio_button_checked,
        "label": "Baseline",
        "desc": "No active intervention needed.",
      },
    };

    final config = stateConfig[jitaiType] ?? stateConfig["NONE"]!;
    final Color stateColor = config["color"] as Color;
    final Color stateBg = config["bg"] as Color;
    final IconData stateIcon = config["icon"] as IconData;
    final String stateLabel = config["label"] as String;
    final String stateDesc = config["desc"] as String;

    double mood =
        _contextVector.isNotEmpty ? (_contextVector[0] as num).toDouble() : 5.0;
    int pending =
        _contextVector.length > 1 ? (_contextVector[1] as num).toInt() : 0;
    int hour =
        _contextVector.length > 2 ? (_contextVector[2] as num).toInt() : 0;
    double completion = _contextVector.length > 3
        ? (_contextVector[3] as num).toDouble()
        : 0.5;

    return GestureDetector(
      onTap: () => setState(() => _showContextDebug = !_showContextDebug),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        decoration: BoxDecoration(
          color: stateBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stateColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: stateColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(stateIcon, color: stateColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "MindLink State: ",
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                            Text(
                              stateLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: stateColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stateDesc,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (_contextVector.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _buildExplanation(jitaiType, _contextVector),
                            style: TextStyle(
                              fontSize: 11,
                              color: stateColor.withOpacity(0.85),
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _showContextDebug
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ),
            if (_showContextDebug) ...[
              Divider(height: 1, color: stateColor.withOpacity(0.2)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "4D Context Vector  →  Predicted State",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildVectorChip(
                            "😊 Mood", "${mood.toInt()}/10", stateColor),
                        const SizedBox(width: 8),
                        _buildVectorChip(
                            "📋 Tasks", "$pending pending", stateColor),
                        const SizedBox(width: 8),
                        _buildVectorChip("🕐 Hour", "${hour}:00", stateColor),
                        const SizedBox(width: 8),
                        _buildVectorChip(
                          "✅ Done",
                          "${(completion * 100).toInt()}%",
                          stateColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: stateColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "RandomForestClassifier → ${jitaiType == 'NONE' ? 'Class 3 (NEUTRAL)' : 'Class: $jitaiType'}  "
                        "[${mood.toInt()}, $pending, $hour, ${completion.toStringAsFixed(2)}]",
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: stateColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVectorChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartBanner() {
    if (isLoadingJitai ||
        jitaiType == "NONE" ||
        jitaiType == "BASELINE" ||
        jitaiType == "NEUTRAL") {
      return const SizedBox.shrink();
    }

    Color cardColor;
    Color borderColor;
    IconData cardIcon;
    VoidCallback onTapAction;

    switch (jitaiType) {
      case "CRISIS":
        cardColor = Colors.red.shade50;
        borderColor = Colors.red.shade200;
        cardIcon = Icons.favorite_outline;
        onTapAction = () {};
        break;
      case "ACADEMIC":
        cardColor = const Color(0xFFECEFF1);
        borderColor = const Color(0xFF90A4AE);
        cardIcon = Icons.lightbulb_outline;
        onTapAction = () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (c) => TaskScreen(userId: widget.userId)),
          ).then((_) => _refreshAll());
        };
        break;
      case "MOTIVATION":
        cardColor = Colors.green.shade50;
        borderColor = Colors.green.shade200;
        cardIcon = Icons.celebration_outlined;
        onTapAction = () {};
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20, top: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(cardIcon, size: 22, color: Colors.black87),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  // ✅ FIX: Use friendly banner title instead of raw type
                  _getBannerTitle(jitaiType),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(jitaiMessage,
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (jitaiType == "ACADEMIC")
                TextButton.icon(
                  icon: const Icon(Icons.checklist, size: 16),
                  label: const Text("Open Planner",
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF546E7A),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                  ),
                  onPressed: () async {
                    await sendFeedback(1);
                    onTapAction();
                    if (mounted) {
                      setState(() {
                        jitaiType = "NONE";
                        _jitaiEventId = null;
                      });
                    }
                  },
                )
              else
                const SizedBox.shrink(),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.thumb_down_off_alt,
                        size: 16, color: Colors.black45),
                    label: const Text("Not helpful",
                        style: TextStyle(fontSize: 11, color: Colors.black45)),
                    onPressed: () async {
                      await sendFeedback(0);
                      if (mounted) {
                        setState(() {
                          jitaiType = "NONE";
                          _jitaiEventId = null;
                        });
                      }
                    },
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.thumb_up_alt,
                        size: 16, color: borderColor),
                    label: Text("Helpful",
                        style: TextStyle(
                            fontSize: 11,
                            color: borderColor,
                            fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      await sendFeedback(1);
                      onTapAction();
                      if (mounted) {
                        setState(() {
                          jitaiType = "NONE";
                          _jitaiEventId = null;
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text('MindLink Wellbeing'),
        backgroundColor: const Color(0xFF607D8B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
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
            backgroundColor: const Color(0xFF78909C),
            foregroundColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => TaskScreen(userId: widget.userId)),
              ).then((_) => _refreshAll());
            },
            child: const Icon(Icons.check_circle_outline),
          ),
          const SizedBox(width: 15),
          FloatingActionButton(
            heroTag: "chat",
            backgroundColor: const Color(0xFF546E7A),
            foregroundColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ChatScreen(userId: widget.userId)),
              ).then((_) => _refreshAll());
            },
            child: const Icon(Icons.chat_bubble),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildStateIndicator(),
              _buildSmartBanner(),
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 10)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "How are you feeling?",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(getMoodEmoji(_currentMood.toInt()),
                            style: const TextStyle(fontSize: 30)),
                        Expanded(
                          child: Slider(
                            value: _currentMood,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            activeColor: getMoodColor(_currentMood.toInt()),
                            label: _currentMood.toInt().toString(),
                            onChanged: (val) =>
                                setState(() => _currentMood = val),
                          ),
                        ),
                        Text(
                          "${_currentMood.toInt()}/10",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: getMoodColor(_currentMood.toInt()),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: thoughtController,
                      decoration: InputDecoration(
                        hintText: 'Describe your feelings...',
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: createThought,
                        icon: const Icon(Icons.check),
                        label: const Text("Log Check-in"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF607D8B),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              MoodChart(thoughts: thoughts),
              ProductivityChart(tasks: tasks),

              Padding(
                padding:
                    const EdgeInsets.only(left: 20, right: 20, top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Recent History",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MoodHistoryScreen(userId: widget.userId),
                          ),
                        ).then((_) => _refreshAll());
                      },
                      child: const Text("View All"),
                    )
                  ],
                ),
              ),
              thoughts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text("No logs yet."),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount:
                          thoughts.length > 5 ? 5 : thoughts.length,
                      itemBuilder: (context, index) {
                        final item = thoughts[index];
                        final mood = item['mood_score'] ?? 5;
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  getMoodColor(mood).withOpacity(0.2),
                              child: Text(getMoodEmoji(mood)),
                            ),
                            title: Text(
                              item['content'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              "Mood Score: $mood/10",
                              style: TextStyle(color: getMoodColor(mood)),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.grey),
                              onPressed: () => deleteThought(item['id']),
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}