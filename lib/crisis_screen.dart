import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'dart:async';

class CrisisScreen extends StatefulWidget {
  const CrisisScreen({super.key});

  @override
  State<CrisisScreen> createState() => _CrisisScreenState();
}

class _CrisisScreenState extends State<CrisisScreen> with SingleTickerProviderStateMixin {
  
  // --- BREATHING ANIMATION CONTROLLERS ---
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;
  String _breathText = "Inhale...";
  
  @override
  void initState() {
    super.initState();
    // 4-second breath cycle setup
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _sizeAnimation = Tween<double>(begin: 100.0, end: 180.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
    );

    _startBreathingCycle();
  }

  void _startBreathingCycle() {
    // A simple 4-4-4-4 box breathing emulation loop
    _runBreathSequence();
  }

  Future<void> _runBreathSequence() async {
    while (mounted) {
      if (!mounted) return;
      
      // Inhale
      setState(() => _breathText = "Inhale (4s)");
      await _controller.forward();
      
      if (!mounted) return;
      // Hold
      setState(() => _breathText = "Hold (4s)");
      await Future.delayed(const Duration(seconds: 4));

      if (!mounted) return;
      // Exhale
      setState(() => _breathText = "Exhale (4s)");
      await _controller.reverse();

      if (!mounted) return;
      // Hold Empty
      setState(() => _breathText = "Hold (4s)");
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Safety Plan", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red[50],
        foregroundColor: Colors.red[800],
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3))
              ),
              child: Row(
                children: [
                   Icon(Icons.shield, color: Colors.red[800], size: 40),
                   const SizedBox(width: 15),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text("You are safe here.", style: TextStyle(color: Colors.red[900], fontWeight: FontWeight.bold, fontSize: 18)),
                         const SizedBox(height: 4),
                         Text("Use these tools to ground yourself immediately.", style: TextStyle(color: Colors.red[700], fontSize: 13)),
                       ],
                     ),
                   )
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // --- 1. BREATHING TOOL ---
            const Text("1. Breathe with me", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Container(
                    width: _sizeAnimation.value,
                    height: _sizeAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.blue[200]!.withOpacity(0.6),
                          Colors.blue[400]!.withOpacity(0.8),
                        ]
                      ),
                      boxShadow: [
                         BoxShadow(
                           color: Colors.blue.withOpacity(0.3),
                           blurRadius: 20,
                           spreadRadius: 5
                         )
                      ]
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _breathText,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),

            // --- 2. GROUNDING TECHNIQUE ---
            const Text("2. Grounding (5-4-3-2-1)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildGroundingItem("5", "Things you can see"),
            _buildGroundingItem("4", "Things you can touch"),
            _buildGroundingItem("3", "Things you can hear"),
            _buildGroundingItem("2", "Things you can smell"),
            _buildGroundingItem("1", "Thing you can taste"),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),

            // --- 3. EMERGENCY CONTACTS ---
            const Text("3. Reach Out Now", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            ElevatedButton.icon(
              icon: const Icon(Icons.phone),
              label: const Text("Call National Suicide Helpline (112)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              onPressed: () => _makePhoneCall("112"),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              icon: const Icon(Icons.favorite),
              label: const Text("Call Friend / Support System"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.red[200]!),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              onPressed: () => _makePhoneCall("0771234567"), // Replace with variable
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroundingItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.teal[100],
            child: Text(number, style: TextStyle(color: Colors.teal[900], fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 15, color: Colors.black87)),
        ],
      ),
    );
  }
}