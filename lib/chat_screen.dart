import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'api_service.dart';

import 'crisis_screen.dart';
import 'task_screen.dart';

class ChatScreen extends StatefulWidget {
  final int userId;
  const ChatScreen({super.key, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ✅ Added 'state' field to each message so we can show a small
  // state badge on AI replies — makes the adaptive persona visible.
  final List<Map<String, dynamic>> _messages = [
    {
      "text": "Hello! I am Sage, your MindLink companion. How are you feeling right now?",
      "isUser": false,
      "isAlert": false,
      "state": null,
    }
  ];

  bool _isLoading = false;

  // Thesis palette constants — replaces all Colors.deepPurple references
  static const Color _primary   = Color(0xFF607D8B); // Sage & Slate
  static const Color _dark      = Color(0xFF546E7A);
  static const Color _light     = Color(0xFF90A4AE);
  static const Color _bgScreen  = Color(0xFFF5F7F8);

  Future<void> sendMessage() async {
    if (_controller.text.isEmpty) return;

    final text = _controller.text;
    setState(() {
      _messages.add({"text": text, "isUser": true, "isAlert": false, "state": null});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final url = Uri.parse('${ApiService.baseUrl}/chat/');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": widget.userId, "message": text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final botReply    = data['response'];
        final isAlert     = data['alert'] ?? false;
        final intervention = data['intervention'];
        // ✅ Capture the predicted state returned by the enriched /chat/ endpoint
        final String? state = data['state'];

        setState(() {
          _messages.add({
            "text": botReply,
            "isUser": false,
            "isAlert": isAlert,
            "state": state,   // ✅ stored per-message for the state badge
          });
          _isLoading = false;
        });

        _scrollToBottom();

        // RC3: Safety bypass — auto-navigate to CrisisScreen after delay
        if (intervention == "CRITICAL_SELF_HARM") {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const CrisisScreen()));
            }
          });
        }

        // RC2: Academic state — suggest task planner
        else if (intervention == "ACADEMIC") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: _dark,
              content: const Text("Would you like to manage your tasks now?"),
              action: SnackBarAction(
                label: "Open Planner",
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              TaskScreen(userId: widget.userId)));
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _messages.add({
          "text": "Error connecting to AI.",
          "isUser": false,
          "isAlert": false,
          "state": null,
        });
        _isLoading = false;
      });
      debugPrint("Chat error: $e");
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

  // ✅ Small badge shown beneath each AI reply indicating the JITAI state
  // that shaped the response. Makes the adaptive persona contribution
  // visible and screenshottable for evaluation evidence.
  Widget _buildStateBadge(String? state) {
    if (state == null || state == "NEUTRAL" || state == "GROQ_LLAMA3") {
      return const SizedBox.shrink();
    }

    final Map<String, Map<String, dynamic>> badgeConfig = {
      "CRISIS": {
        "color": Colors.red.shade700,
        "bg": Colors.red.shade50,
        "icon": Icons.warning_amber_rounded,
        "label": "Crisis Mode",
      },
      "ACADEMIC": {
        "color": _dark,
        "bg": const Color(0xFFECEFF1),
        "icon": Icons.school_outlined,
        "label": "Academic Mode",
      },
      "MOTIVATION": {
        "color": Colors.green.shade700,
        "bg": Colors.green.shade50,
        "icon": Icons.bolt,
        "label": "Motivation Mode",
      },
    };

    final cfg = badgeConfig[state];
    if (cfg == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(cfg["icon"] as IconData,
              size: 11, color: cfg["color"] as Color),
          const SizedBox(width: 4),
          Text(
            cfg["label"] as String,
            style: TextStyle(
              fontSize: 10,
              color: cfg["color"] as Color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgScreen,
      appBar: AppBar(
        // ✅ Replaced deepPurple gradient with thesis Sage & Slate palette
        title: const Text("Sage — AI Companion",
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 18)),
        centerTitle: true,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ✅ Thin state-of-mind banner at top of chat — updates per response
          if (_messages.length > 1 && _messages.last['state'] != null)
            _buildChatContextBar(_messages.last['state'] as String?),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;
                final isAlert = msg['isAlert'] as bool;
                final String? state = msg['state'] as String?;

                // Crisis alert card — unchanged, red is semantically correct
                if (isAlert) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 15),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.red.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.red, size: 30),
                            SizedBox(width: 10),
                            Text("SAFETY PROTOCOL",
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          msg['text'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const CrisisScreen()));
                            },
                            icon: const Icon(Icons.shield),
                            label: const Text("Open Safety Plan Now"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                }

                // Standard chat bubbles
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bot avatar
                      if (!isUser)
                        CircleAvatar(
                          backgroundColor: _primary,
                          radius: 16,
                          child: const Icon(Icons.psychology,
                              color: Colors.white, size: 18),
                        ),

                      const SizedBox(width: 8),

                      // Message bubble + optional state badge
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                // ✅ User bubble: _dark (#546E7A) instead of deepPurple
                                color: isUser ? _dark : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isUser
                                      ? const Radius.circular(16)
                                      : Radius.zero,
                                  bottomRight: isUser
                                      ? Radius.zero
                                      : const Radius.circular(16),
                                ),
                                boxShadow: isUser
                                    ? []
                                    : [
                                        BoxShadow(
                                            color: Colors.black
                                                .withOpacity(0.05),
                                            blurRadius: 5)
                                      ],
                              ),
                              child: Text(
                                msg['text'] as String,
                                style: TextStyle(
                                  color: isUser
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            // ✅ State badge beneath AI replies only
                            if (!isUser) _buildStateBadge(state),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // User avatar
                      if (isUser)
                        CircleAvatar(
                          backgroundColor: _light,
                          radius: 16,
                          child: const Icon(Icons.person,
                              color: Colors.white, size: 18),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Typing indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: _primary.withOpacity(0.15),
                    radius: 12,
                    child: Icon(Icons.psychology, size: 14, color: _primary),
                  ),
                  const SizedBox(width: 8),
                  Text("Sage is thinking...",
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),

          // Input area
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5))
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Talk to Sage...",
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                // ✅ Send button: _dark instead of deepPurple
                FloatingActionButton(
                  onPressed: sendMessage,
                  backgroundColor: _dark,
                  elevation: 2,
                  mini: true,
                  child:
                      const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Thin banner at the top of the chat showing the current active
  // JITAI state — updates in real time with each AI response.
  // Provides continuous visual evidence of context-aware adaptation.
  Widget _buildChatContextBar(String? state) {
    if (state == null || state == "NEUTRAL" || state == "GROQ_LLAMA3") {
      return const SizedBox.shrink();
    }

    final Map<String, Map<String, dynamic>> barConfig = {
      "CRISIS": {
        "color": Colors.red.shade700,
        "bg": Colors.red.shade50,
        "label": "Crisis support mode active",
        "icon": Icons.favorite,
      },
      "ACADEMIC": {
        "color": _dark,
        "bg": const Color(0xFFECEFF1),
        "label": "Academic focus mode active",
        "icon": Icons.school_outlined,
      },
      "MOTIVATION": {
        "color": Colors.green.shade700,
        "bg": Colors.green.shade50,
        "label": "Motivation mode active",
        "icon": Icons.bolt,
      },
    };

    final cfg = barConfig[state];
    if (cfg == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: cfg["bg"] as Color,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(cfg["icon"] as IconData,
              size: 13, color: cfg["color"] as Color),
          const SizedBox(width: 6),
          Text(
            cfg["label"] as String,
            style: TextStyle(
              fontSize: 11,
              color: cfg["color"] as Color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}