import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class CrisisScreen extends StatefulWidget {
  const CrisisScreen({super.key});

  @override
  State<CrisisScreen> createState() => _CrisisScreenState();
}

class _CrisisScreenState extends State<CrisisScreen>
    with SingleTickerProviderStateMixin {

  // --- BREATHING ANIMATION CONTROLLERS ---
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;
  String _breathText = "Inhale...";

  // ✅ FR-05: Escalation contact constants.
  // The wellbeing officer email and Sumithrayo helpline are the two
  // escalation pathways required by FR-05 — an actual action the user
  // can take, not just a phone number displayed as text.
  static const String _wellbeingEmail = "wellbeing@iit.ac.lk";
  static const String _sumithrayoNumber = "1926";
  static const String _emergencyNumber = "1990"; // Shantha Manadhara / Psychiatric helpline

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _sizeAnimation = Tween<double>(begin: 100.0, end: 180.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _startBreathingCycle();
  }

  void _startBreathingCycle() {
    _runBreathSequence();
  }

  Future<void> _runBreathSequence() async {
    while (mounted) {
      if (!mounted) return;
      setState(() => _breathText = "Inhale (4s)");
      await _controller.forward();

      if (!mounted) return;
      setState(() => _breathText = "Hold (4s)");
      await Future.delayed(const Duration(seconds: 4));

      if (!mounted) return;
      setState(() => _breathText = "Exhale (4s)");
      await _controller.reverse();

      if (!mounted) return;
      setState(() => _breathText = "Hold (4s)");
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not launch call to $phoneNumber")),
        );
      }
    }
  }

  // ✅ FR-05: Email escalation to university wellbeing officer.
  // Composes a pre-filled email so the user does not have to type anything
  // while in distress. Subject and body are pre-populated.
  Future<void> _emailWellbeingOfficer() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _wellbeingEmail,
      queryParameters: {
        'subject': 'MindLink Crisis Alert — Student Support Needed',
        'body':
            'Hello,\n\nI am reaching out through the MindLink app because I am currently '
            'experiencing significant distress and would like to speak with a wellbeing '
            'officer as soon as possible.\n\nPlease contact me at your earliest convenience.\n\n'
            'Thank you.',
      },
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Could not open email app. Please email wellbeing@iit.ac.lk directly."),
          ),
        );
      }
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
        title: const Text("Safety Plan",
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield, color: Colors.red[800], size: 40),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "You are safe here.",
                          style: TextStyle(
                              color: Colors.red[900],
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Use these tools to ground yourself immediately.",
                          style:
                              TextStyle(color: Colors.red[700], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- 1. BREATHING TOOL ---
            const Text("1. Breathe with me",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      gradient: RadialGradient(colors: [
                        Colors.blue[200]!.withOpacity(0.6),
                        Colors.blue[400]!.withOpacity(0.8),
                      ]),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _breathText,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),

            // --- 2. GROUNDING TECHNIQUE ---
            const Text("2. Grounding (5-4-3-2-1)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildGroundingItem("5", "Things you can see"),
            _buildGroundingItem("4", "Things you can touch"),
            _buildGroundingItem("3", "Things you can hear"),
            _buildGroundingItem("2", "Things you can smell"),
            _buildGroundingItem("1", "Thing you can taste"),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 20),

            // --- 3. REACH OUT NOW ---
            const Text("3. Reach Out Now",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              "You do not have to face this alone. Contact one of the options below.",
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // ✅ FR-05 — PRIMARY ESCALATION: Email wellbeing officer
            // This is the formal institutional escalation pathway.
            // Pre-filled email removes friction during a crisis moment.
            _buildEscalationCard(
              icon: Icons.email_outlined,
              label: "Email Wellbeing Officer",
              sublabel: _wellbeingEmail,
              description:
                  "Sends a pre-written support request to your university wellbeing team.",
              color: const Color(0xFF546E7A),
              onTap: _emailWellbeingOfficer,
            ),

            const SizedBox(height: 12),

            // ✅ FR-05 — CRISIS HELPLINE: Sumithrayo (Sri Lanka, 24/7)
            _buildEscalationCard(
              icon: Icons.phone_outlined,
              label: "Call Sumithrayo Helpline",
              sublabel: "1926 — Free, 24/7, Confidential",
              description:
                  "Sri Lanka's national mental health crisis line. Trained counsellors available now.",
              color: Colors.red.shade700,
              onTap: () => _makePhoneCall(_sumithrayoNumber),
            ),

            const SizedBox(height: 12),

            // ✅ FR-05 — PSYCHIATRIC EMERGENCY
            _buildEscalationCard(
              icon: Icons.local_hospital_outlined,
              label: "Psychiatric Emergency Line",
              sublabel: "1990 — Shantha Manadhara",
              description:
                  "For immediate psychiatric emergencies. Call if you feel you may harm yourself.",
              color: Colors.red.shade900,
              onTap: () => _makePhoneCall(_emergencyNumber),
            ),

            const SizedBox(height: 12),

            // Existing: call friend
            OutlinedButton.icon(
              icon: const Icon(Icons.favorite),
              label: const Text("Call a Friend or Support Person"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.red[200]!),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _makePhoneCall("0771234567"),
            ),

            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 16),

            // ✅ NFR-03: Transparency note — explains what triggered this screen
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.grey[500]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "MindLink detected signs of distress based on your recent mood logs "
                      "and behavioural patterns. This screen was shown to ensure you have "
                      "immediate access to support. You are in control.",
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ✅ FR-05: Escalation card widget — consistent, tappable, clearly labelled.
  // Each card shows the contact name, identifier (email/number), and a one-line
  // description of what the service does — reducing cognitive load during crisis.
  Widget _buildEscalationCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: color)),
                  const SizedBox(height: 2),
                  Text(sublabel,
                      style: TextStyle(
                          fontSize: 12,
                          color: color.withOpacity(0.8),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600], height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
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
            child: Text(number,
                style: TextStyle(
                    color: Colors.teal[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Text(text,
              style: const TextStyle(fontSize: 15, color: Colors.black87)),
        ],
      ),
    );
  }
}