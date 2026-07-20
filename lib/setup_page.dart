import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apex/theme.dart';
import 'core/push_notification_service.dart';
import 'core/profile_service.dart';
import 'calendar_page.dart';

class SetupPage extends StatefulWidget {
  final VoidCallback? onOwnerCreated;

  const SetupPage({super.key, this.onOwnerCreated});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

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
      try {
        await _supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            'name': name,
            'bootstrap_owner': true,
          },
        );
      } on AuthException catch (error) {
        if (error.code != 'user_already_exists' &&
            !error.message.toLowerCase().contains('already registered')) {
          rethrow;
        }
      }

      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final profile = await ProfileService.loadCurrentProfile();
      if (profile == null || profile.role != 'Owner') {
        throw 'Owner account could not be created. Try again or contact support.';
      }

      await PushNotificationService.syncTokenForCurrentUser();
      widget.onOwnerCreated?.call();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CalendarPage(
            userEmail: profile.email,
            userName: profile.name,
            userRole: profile.role,
          ),
        ),
      );
    } catch (e) {
      final message = e is AuthException
          ? 'Setup failed: ${e.message}'
          : 'Setup failed. Please try again.';
      _showSnackBar(message, UniversalTheme.alertRed);
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.brown.shade100),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.coffee, size: 48, color: UniversalTheme.accent),
                  const SizedBox(height: 12),
                  const Text(
                    'APEX',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: UniversalTheme.darkSlate,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Text(
                    'Create your owner account to get started',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const Divider(height: 32),
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
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Create Owner Account',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
