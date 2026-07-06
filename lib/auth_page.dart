import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apex/theme.dart';
import 'core/push_notification_service.dart';
import 'core/profile_session.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/onboarding/business_setup_screen.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  
  bool _isSignUp = false;
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _showBanner(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  Future<void> _navigateAfterAuth(String email, UserProfile profile) async {
    if (!mounted) return;

    if (!profile.hasBusiness) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BusinessSetupScreen(
            userEmail: email,
            userName: profile.name,
            inviteCode: _isSignUp ? _inviteCodeController.text.trim() : null,
          ),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(userEmail: email),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (_isSignUp && name.isEmpty)) {
      _showBanner('Please fill out all visible input options.', UniversalTheme.alertRed);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        final response = await _supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            'name': name,
            'role': 'Staff',
          },
        );

        if (response.user != null) {
          await _supabase.from('profiles').insert({
            'id': response.user!.id,
            'email': email,
            'name': name,
            'role': 'Staff',
            'first_time_login': true,
          });

          _showBanner('Registration successful! Logging you in...', Colors.green);
        }
      }

      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.session != null && mounted) {
        final profile = await ProfileSession.loadForUserId(authResponse.user!.id);

        await PushNotificationService.syncTokenForCurrentUser();

        await _navigateAfterAuth(email, profile);
      }
    } catch (e) {
      _showBanner('Authentication Error: $e', UniversalTheme.alertRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            color: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFEFEBE4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Apex Scheduler',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: UniversalTheme.darkSlate,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp ? 'Create a New Account' : 'Sign In to Your Account',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const Divider(height: 32, thickness: 1.2),
                  
                  if (_isSignUp) ...[
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Color(0xFF2D2D2D), fontSize: 15, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: 'Your Name',
                        labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                        hintText: 'Enter your first name...',
                        hintStyle: const TextStyle(color: Colors.black38),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400, width: 1.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _inviteCodeController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: Color(0xFF2D2D2D), fontSize: 15, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        labelText: 'Invite Code (optional)',
                        labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                        hintText: 'Join an existing business',
                        hintStyle: const TextStyle(color: Colors.black38),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400, width: 1.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Color(0xFF2D2D2D), fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                      hintText: 'username@example.com',
                      hintStyle: const TextStyle(color: Colors.black38),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade400, width: 1.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Color(0xFF2D2D2D), fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                      hintText: 'Enter your password...',
                      hintStyle: const TextStyle(color: Colors.black38),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade400, width: 1.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UniversalTheme.darkSlate,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _isSignUp ? 'Create Account' : 'Sign In',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp ? 'Already have an account? Sign In Here' : 'Need an account? Register Here',
                      style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.w600, fontSize: 13),
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
