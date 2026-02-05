import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';
import 'chat_screen.dart'; // REQUIRED: Import your ChatScreen
import 'api_service.dart';

class TaskScreen extends StatefulWidget {
  final int userId;
  const TaskScreen({super.key, required this.userId});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  List<dynamic> tasks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  // --- 1. API CALLS ---
  Future<void> fetchTasks() async {
    final url = Uri.parse('${ApiService.baseUrl}/tasks/${widget.userId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          tasks = jsonDecode(response.body);
          isLoading = false;
        });
        if (isLoading) checkJitaiIntervention(); 
      }
    } catch (e) {
      print("Error fetching: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> saveTask(String content, DateTime fullDate, {int? id}) async {
    final dateString = DateFormat('yyyy-MM-dd HH:mm').format(fullDate);
    
    try {
      if (id == null) {
        // --- CREATE NEW TASK ---
        final url = Uri.parse('${ApiService.baseUrl}/tasks/?user_id=${widget.userId}');
        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"content": content, "due_date": dateString}),
        );

        if (response.statusCode == 200) {
          final newTask = jsonDecode(response.body);
          
          await NotificationService().scheduleTaskReminder(
            newTask['id'], 
            content, 
            fullDate
          );
        }
      } else {
        // --- UPDATE EXISTING TASK ---
        final url = Uri.parse('${ApiService.baseUrl}/tasks/$id');
        await http.put(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"content": content, "due_date": dateString}),
        );
        
        await NotificationService().scheduleTaskReminder(id, content, fullDate);
      }
      
      fetchTasks(); 
    } catch (e) { 
      print("Error saving task: $e"); 
    }
  }

  Future<void> deleteTask(int id) async {
    final backupIndex = tasks.indexWhere((t) => t['id'] == id);
    final backupTask = tasks[backupIndex];
    
    setState(() => tasks.removeWhere((t) => t['id'] == id));

    try {
      final url = Uri.parse('${ApiService.baseUrl}/tasks/delete/$id'); 
      final response = await http.delete(url);
      
      if (response.statusCode != 200) {
        throw Exception("Failed to delete");
      }
      
      await NotificationService().flutterLocalNotificationsPlugin.cancel(id);

    } catch (e) {
      print("Delete failed: $e");
      setState(() => tasks.insert(backupIndex, backupTask));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete task")));
    }
  }

  // --- UPDATED: TOGGLE TASK + PROACTIVE CHECK-IN ---
  Future<void> toggleTask(int id, bool currentStatus, String content) async {
    final url = Uri.parse('${ApiService.baseUrl}/tasks/$id');
    
    // Optimistic Update
    setState(() {
      final index = tasks.indexWhere((t) => t['id'] == id);
      if (index != -1) tasks[index]['is_done'] = !currentStatus;
    });

    try {
      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"is_done": !currentStatus}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // --- CHECK FOR PROACTIVE FEEDBACK (NEW MESSAGE) ---
        if (data['proactive_feedback'] != null) {
          final String msg = data['proactive_feedback'];
          
          if (mounted) {
            // Hide any previous JITAI snackbars
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.deepPurple,
                content: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(child: Text(msg, maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: "REPLY",
                  textColor: Colors.amber,
                  onPressed: () {
                    // Navigate to Chat Screen
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => ChatScreen(userId: widget.userId))
                    );
                  },
                ),
              )
            );
          }
        }
      }
    } catch (e) {
      print("Error updating task: $e");
      fetchTasks(); // Revert on error
    }
  }

  // --- AI FEEDBACK LOGIC ---

  Future<void> sendFeedback(int outcome) async {
    final url = Uri.parse('${ApiService.baseUrl}/jitai/feedback');
    try {
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "outcome": outcome, 
        }),
      );
    } catch (e) {
      print("❌ Error sending feedback: $e");
    }
  }

  Future<void> checkJitaiIntervention() async {
    final url = Uri.parse('${ApiService.baseUrl}/jitai/${widget.userId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['type'] != "NONE" && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 10), 
              backgroundColor: const Color(0xFF37474F),
              behavior: SnackBarBehavior.floating,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "${data['type']} DETECTED", 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(data['message'], style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.thumb_down_off_alt, color: Colors.redAccent, size: 20),
                        onPressed: () {
                          sendFeedback(0); 
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.thumb_up_alt, color: Colors.greenAccent, size: 20),
                        onPressed: () {
                          sendFeedback(1); 
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> addToGoogleCalendar(String title, String dateString) async {
    try {
      DateTime date = DateTime.tryParse(dateString) ?? DateTime.now();
      final DateFormat formatter = DateFormat("yyyyMMdd'T'HHmmss");
      String start = formatter.format(date);
      String end = formatter.format(date.add(const Duration(hours: 1)));
      final Uri calendarUrl = Uri.parse(
        'https://www.google.com/calendar/render?action=TEMPLATE&text=$title&dates=$start/$end'
      );
      if (!await launchUrl(calendarUrl, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch calendar';
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open Calendar app")));
    }
  }

  // --- UI HELPERS ---
  
  List<dynamic> get overdueTasks {
    final now = DateTime.now();
    return tasks.where((t) {
      if (t['is_done']) return false;
      DateTime? due = DateTime.tryParse(t['due_date']);
      return due != null && due.isBefore(now);
    }).toList();
  }

  List<dynamic> get todayTasks {
    final now = DateTime.now();
    return tasks.where((t) {
      if (t['is_done']) return false;
      DateTime? due = DateTime.tryParse(t['due_date']);
      return due != null && due.year == now.year && due.month == now.month && due.day == now.day && due.isAfter(now);
    }).toList();
  }

  List<dynamic> get upcomingTasks {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tasks.where((t) {
      if (t['is_done']) return false;
      DateTime? due = DateTime.tryParse(t['due_date']);
      return due != null && due.isAfter(tomorrow);
    }).toList();
  }

  List<dynamic> get completedTasks => tasks.where((t) => t['is_done']).toList();

  List<dynamic> get _dailyWorkload {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tasks.where((t) {
      DateTime? due = DateTime.tryParse(t['due_date']);
      if (t['is_done']) {
         if (due != null && due.isAfter(tomorrow)) return false; 
         return true;
      }
      return due != null && due.isBefore(tomorrow);
    }).toList();
  }

  double get completionProgress {
    final workload = _dailyWorkload;
    if (workload.isEmpty) return 0.0;
    int done = workload.where((t) => t['is_done']).length;
    return done / workload.length;
  }

  String get motivationalMessage {
    double p = completionProgress;
    if (p == 0) return "Let's knock out the first one! 🚀";
    if (p < 0.3) return "Good start! Keep moving. 🔥";
    if (p < 0.6) return "You're on a roll! Halfway there. 🏃";
    if (p < 1.0) return "Almost done! Finish strong. 💪";
    return "All cleared! You are awesome. 🎉";
  }

  // --- ADD MODAL ---
  void _showTaskModal({Map<String, dynamic>? existingTask}) {
    final textController = TextEditingController(text: existingTask != null ? existingTask['content'] : "");
    DateTime initialDate = existingTask != null 
        ? DateTime.tryParse(existingTask['due_date']) ?? DateTime.now()
        : DateTime.now();
    DateTime selectedDate = initialDate;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(initialDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            DateTime getFullDateTime() {
              return DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
            }
            return Container(
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(existingTask != null ? "Edit Plan" : "New Plan", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF455A64))),
                  const SizedBox(height: 20),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      hintText: "What needs to be done?",
                      filled: true, fillColor: const Color(0xFFF5F7F8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("When is this due?", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030),
                               builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF607D8B))), child: child!),
                            );
                            if (picked != null) setModalState(() => selectedDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [const Icon(Icons.calendar_month, size: 18, color: Color(0xFF607D8B)), const SizedBox(width: 8), Text(DateFormat('MMM dd, yyyy').format(selectedDate))]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context, initialTime: selectedTime,
                              builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF607D8B))), child: child!),
                            );
                            if (picked != null) setModalState(() => selectedTime = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [const Icon(Icons.access_time, size: 18, color: Color(0xFF607D8B)), const SizedBox(width: 8), Text(selectedTime.format(context))]),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF546E7A), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        if (textController.text.isNotEmpty) {
                          saveTask(textController.text, getFullDateTime(), id: existingTask?['id']);
                          Navigator.pop(context);
                        }
                      },
                      child: Text(existingTask != null ? "Update Plan" : "Save Plan", style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text("My Planner", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF607D8B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskModal(),
        label: const Text("Add Task", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: const Color(0xFF546E7A),
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF607D8B))) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_dailyWorkload.isNotEmpty) 
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(24), 
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF546E7A), Color(0xFF78909C)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: const Color(0xFF546E7A).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Daily Progress", style: TextStyle(color: Colors.white70, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text("${(completionProgress * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.insights, color: Colors.white, size: 28),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: completionProgress,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(motivationalMessage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),

                if (overdueTasks.isNotEmpty) ...[
                  const Text("Overdue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  const SizedBox(height: 10),
                  ...overdueTasks.map((t) => _buildTaskTile(t)).toList(),
                  const SizedBox(height: 20),
                ],

                if (todayTasks.isNotEmpty) ...[
                  const Text("Today", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF37474F))),
                  const SizedBox(height: 10),
                  ...todayTasks.map((t) => _buildTaskTile(t)).toList(),
                  const SizedBox(height: 20),
                ],

                if (upcomingTasks.isNotEmpty) ...[
                  const Text("Upcoming", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF37474F))),
                  const SizedBox(height: 10),
                  ...upcomingTasks.map((t) => _buildTaskTile(t)).toList(),
                  const SizedBox(height: 20),
                ],
                
                 if (completedTasks.isNotEmpty) ...[
                  ExpansionTile(
                    title: const Text("Completed", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                    children: completedTasks.map((t) => _buildTaskTile(t)).toList(),
                  ),
                ],
              ],
            ),
          ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final bool isDone = task['is_done'] ?? false;
    final DateTime? due = DateTime.tryParse(task['due_date']);
    final bool isOverdue = due != null && due.isBefore(DateTime.now()) && !isDone;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: GestureDetector(
          onTap: () => toggleTask(task['id'], isDone, task['content']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: isDone ? Colors.teal : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDone ? Colors.teal : Colors.grey.shade400, width: 2),
            ),
            child: isDone ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
          ),
        ),
        title: Text(
          task['content'],
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? Colors.grey : Colors.black87,
          ),
        ),
        subtitle: due != null ? Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: isOverdue ? Colors.redAccent : Colors.grey),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM dd, hh:mm a').format(due),
                style: TextStyle(fontSize: 12, color: isOverdue ? Colors.redAccent : Colors.grey),
              ),
            ],
          ),
        ) : null,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onSelected: (value) {
            if (value == 'edit') _showTaskModal(existingTask: task);
            if (value == 'delete') deleteTask(task['id']);
            if (value == 'calendar') addToGoogleCalendar(task['content'], task['due_date']);
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 10), Text("Edit")])),
            const PopupMenuItem(value: 'calendar', child: Row(children: [Icon(Icons.calendar_month, size: 20), SizedBox(width: 10), Text("Add to Calendar")])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.redAccent, size: 20), SizedBox(width: 10), Text("Delete", style: TextStyle(color: Colors.redAccent))])),
          ],
        ),
      ),
    );
  }
}