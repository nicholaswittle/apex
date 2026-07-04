import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apex/theme.dart';
import 'calendar_page.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); 
  
  bool _isLoading = false;
  bool _showForm = false; 

  final _supabase = Supabase.instance.client;

  Future<void> _handleAuthentication() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      _showSnackBar('Please fill out all fields.', UniversalTheme.alertRed);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user != null) {
        await _supabase.from('profiles').update({'name': name}).eq('email', email);
        _showSnackBar('Account created successfully! Logging in...', Colors.green);
      }

      final userData = await _supabase
          .from('profiles')
          .select('name, role')
          .eq('email', email)
          .maybeSingle();

      if (userData == null) {
        throw 'User profile missing from database infrastructure.';
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CalendarPage(
            userEmail: email,
            userName: userData['name'] ?? 'Staff Member',
            userRole: userData['role'] ?? 'Staff',
          ),
        ),
      );
    } catch (e) {
      _showSnackBar('Authentication Error: ${e.toString()}', UniversalTheme.alertRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bgColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UniversalTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            color: UniversalTheme.lightCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.brown.shade100)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.coffee, size: 48, color: UniversalTheme.accent),
                  const SizedBox(height: 12),
                  const Text(
                    'APEX',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: UniversalTheme.darkSlate, letterSpacing: 1.5),
                  ),
                  const Text(
                    'Create Owner Account',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Divider(height: 32),
                  
                  if (!_showForm) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: UniversalTheme.accent),
                      onPressed: () {
                        setState(() {
                          _showForm = true; 
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('Open Registration Form', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Your Name',
                        prefixIcon: const Icon(Icons.person, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleAuthentication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UniversalTheme.darkSlate,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Register Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}