import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dashboard_screen.dart';
import 'register_screen.dart'; // Import the new register screen
import 'api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> loginUser() async {
    setState(() => isLoading = true);
    // ⚠️ Use 10.0.2.2 for Android Emulator, 127.0.0.1 for iOS Simulator/Web
    final url = Uri.parse('${ApiService.baseUrl}/login/'); 
    
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text,
          "password": passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final userId = responseData['user_id'];
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login Successful!'), backgroundColor: Color(0xFF81C784)),
          );
          // Navigate to Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardScreen(userId: userId)),
          );
        }
      } else {
        if (mounted) {
          final errorMsg = jsonDecode(response.body)['detail'] ?? "Login Failed";
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(errorMsg), backgroundColor: const Color(0xFFE57373)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection Error. Is Backend Running?'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology, size: 80, color: primaryColor),
              const SizedBox(height: 20),
              Text(
                'MindLink',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),

              isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                onPressed: loginUser,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text('LOGIN'),
              ),

              const SizedBox(height: 10),
              
              // --- NAVIGATION LOGIC ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      // Navigate to Register Screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: const Text('Create Account'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}