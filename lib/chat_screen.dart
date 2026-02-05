import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Required for Timer/Future delays

// --- IMPORTS FOR NAVIGATION ---
import 'crisis_screen.dart'; // Ensure this file exists in your project
import 'task_screen.dart';   // Ensure this file exists in your project

class ChatScreen extends StatefulWidget {
  final int userId;
  const ChatScreen({super.key, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, dynamic>> _messages = [
    {
      "text": "Hello! I am your MindLink Assistant. How are you feeling right now?",
      "isUser": false,
      "isAlert": false
    }
  ];
  
  bool _isLoading = false;

  Future<void> sendMessage() async {
    if (_controller.text.isEmpty) return;

    final text = _controller.text;
    setState(() {
      _messages.add({"text": text, "isUser": true, "isAlert": false});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Call Python Backend
    // Use 10.0.2.2 for Android Emulator, localhost for iOS Simulator
    final url = Uri.parse('http://10.0.2.2:8000/chat/');
    
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": widget.userId, "message": text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final botReply = data['response'];
        final isAlert = data['alert'] ?? false;
        final intervention = data['intervention']; 

        setState(() {
          _messages.add({
            "text": botReply,
            "isUser": false,
            "isAlert": isAlert 
          });
          _isLoading = false;
        });

        _scrollToBottom();

        // --- 🚀 REAL-TIME INTERVENTION LOGIC ---
        
        // 1. Safety Protocol: Auto-Navigate to Crisis Screen
        if (intervention == "CRITICAL_SELF_HARM") {
          // Brief delay so user sees the red alert box first
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const CrisisScreen())
              );
            }
          });
        } 
        
        // 2. Academic Support: Suggest Task Planner
        else if (intervention == "ACADEMIC") {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               backgroundColor: Colors.deepPurple,
               content: const Text("Would you like to manage your tasks now?"),
               action: SnackBarAction(
                 label: "Open Planner",
                 textColor: Colors.white,
                 onPressed: () {
                   Navigator.push(
                     context, 
                     MaterialPageRoute(builder: (context) => TaskScreen(userId: widget.userId))
                   );
                 },
               ),
               duration: const Duration(seconds: 5),
             )
           );
        }

      }
    } catch (e) {
      setState(() {
        _messages.add({"text": "Error connecting to AI.", "isUser": false, "isAlert": false});
        _isLoading = false;
      });
      print("Error: $e");
    } 
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("AI Counselor", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'];
                final isAlert = msg['isAlert'];

                // --- 🚨 RED ALERT CARD (CRISIS MODE) ---
                if (isAlert) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 15),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.red.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                            SizedBox(width: 10),
                            Text("SAFETY PROTOCOL", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          msg['text'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                               Navigator.push(context, MaterialPageRoute(builder: (context) => const CrisisScreen()));
                            }, 
                            icon: const Icon(Icons.shield),
                            label: const Text("Open Safety Plan Now"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red, 
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12)
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                }

                // --- STANDARD CHAT BUBBLES ---
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bot Avatar
                      if (!isUser) 
                        const CircleAvatar(
                          backgroundColor: Colors.deepPurple,
                          radius: 16,
                          child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
                        ),
                      
                      const SizedBox(width: 8),

                      // Message Bubble
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.deepPurple : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                            ),
                            boxShadow: isUser ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                          ),
                          child: Text(
                            msg['text'],
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // User Avatar
                      if (isUser)
                          CircleAvatar(
                           backgroundColor: Colors.grey[300],
                           radius: 16,
                           child: const Icon(Icons.person, color: Colors.grey, size: 18),
                          ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          if (_isLoading) 
             const Padding(
               padding: EdgeInsets.all(8.0),
               child: Center(
                 child: Text("MindLink AI is thinking...", style: TextStyle(color: Colors.grey, fontSize: 12))
               ),
             ),

          // --- INPUT AREA ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: sendMessage,
                  backgroundColor: Colors.deepPurple,
                  elevation: 2,
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white, size: 18),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}