import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apex/theme.dart';
import 'core/push_notification_service.dart';
import 'core/profile_service.dart';
import 'core/app_config.dart';
import 'calendar_page.dart';
import 'setup_page.dart';

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
  bool _needsOwnerSetup = false;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    if (AppConfig.hasSupabase) {
      _checkOwnerSetup();
    }
  }

  Future<void> _checkOwnerSetup() async {
    if (!mounted) return;
    try {
      final hasOwner = await ProfileService.hasOwnerAccount();
      if (!mounted) return;
      setState(() => _needsOwnerSetup = !hasOwner);
    } catch (_) {
      if (!mounted) return;
      setState(() => _needsOwnerSetup = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _showBanner(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
    );
  }

  Future<void> _navigateToCalendar() async {
    final profile = await ProfileService.loadCurrentProfile();
    if (profile == null || !mounted) {
      _showBanner('Profile not found. Contact your manager.', UniversalTheme.alertRed);
      return;
    }

    await PushNotificationService.syncTokenForCurrentUser();
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
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final inviteCode = _inviteCodeController.text.trim();

    if (email.isEmpty || password.isEmpty || (_isSignUp && name.isEmpty)) {
      _showBanner('Please fill out all visible input options.', UniversalTheme.alertRed);
      return;
    }

    if (_isSignUp && !_needsOwnerSetup && inviteCode.isEmpty) {
      _showBanner('Enter your organization invite code to register.', UniversalTheme.alertRed);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        final metadata = <String, dynamic>{
          'name': name,
          if (_needsOwnerSetup) 'bootstrap_owner': true,
          if (inviteCode.isNotEmpty) 'invite_code': inviteCode,
        };

        await _supabase.auth.signUp(
          email: email,
          password: password,
          data: metadata,
        );

        _showBanner('Registration successful! Logging you in...', Colors.green);
      }

      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      await _navigateToCalendar();
    } catch (e) {
      _showBanner('Authentication failed. Check your credentials and try again.', UniversalTheme.alertRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showBanner('Enter your email address first.', UniversalTheme.alertRed);
      return;
    }

    try {
      await _supabase.auth.resetPasswordForEmail(email);
      _showBanner('Password reset email sent.', Colors.green);
    } catch (_) {
      _showBanner('Could not send reset email. Try again later.', UniversalTheme.alertRed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_needsOwnerSetup) {
      return SetupPage(
        onOwnerCreated: () {
          setState(() => _needsOwnerSetup = false);
        },
      );
    }

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
                    'APEX',
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
                      decoration: const InputDecoration(
                        labelText: 'Your Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _inviteCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Organization Invite Code',
                        hintText: 'Required for staff registration',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
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
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _isSignUp ? 'Create Account' : 'Sign In',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  if (!_isSignUp)
                    TextButton(
                      onPressed: _handlePasswordReset,
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.w600),
                      ),
                    ),
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
