import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apex/theme.dart';
import 'package:apex/core/profile_session.dart';
import 'package:apex/features/dashboard/dashboard_screen.dart';

/// First-login flow: owner creates a business or staff joins via invite.
class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({
    super.key,
    required this.userEmail,
    required this.userName,
    this.inviteCode,
  });

  final String userEmail;
  final String userName;
  final String? inviteCode;

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  final _businessNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  String _industryType = 'restaurant';
  bool _isOwnerFlow = true;
  bool _isLoading = false;

  static const _industries = {
    'restaurant': 'Restaurant',
    'retail': 'Retail',
    'fitness': 'Fitness / Gym',
    'healthcare': 'Healthcare / Clinic',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    if (widget.inviteCode != null && widget.inviteCode!.isNotEmpty) {
      _isOwnerFlow = false;
      _inviteCodeController.text = widget.inviteCode!;
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      if (_isOwnerFlow) {
        final name = _businessNameController.text.trim();
        if (name.isEmpty) {
          _showError('Enter your business name.');
          return;
        }
        await ProfileSession.createBusiness(
          userId: userId,
          name: name,
          industryType: _industryType,
        );
      } else {
        final code = _inviteCodeController.text.trim();
        if (code.isEmpty) {
          _showError('Enter an invite code from your manager.');
          return;
        }
        final invite = await Supabase.instance.client
            .from('invitations')
            .select('business_id, max_uses, use_count')
            .eq('invite_code', code.toUpperCase())
            .maybeSingle();

        if (invite == null) {
          _showError('Invalid invite code.');
          return;
        }

        final maxUses = invite['max_uses'] as int?;
        final useCount = invite['use_count'] as int? ?? 0;
        if (maxUses != null && useCount >= maxUses) {
          _showError('This invite code has reached its use limit.');
          return;
        }

        final businessId = invite['business_id'] as String;
        await Supabase.instance.client.from('profiles').update({
          'business_id': businessId,
          'role': 'Staff',
        }).eq('id', userId);

        await Supabase.instance.client.from('invitations').update({
          'use_count': useCount + 1,
        }).eq('invite_code', code.toUpperCase());
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(userEmail: widget.userEmail),
        ),
      );
    } catch (e) {
      _showError('Setup failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: UniversalTheme.alertRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0),
      appBar: AppBar(
        backgroundColor: UniversalTheme.darkSlate,
        title: const Text(
          'Apex Scheduler',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome, ${widget.userName}!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: UniversalTheme.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Set up your workspace to start scheduling shifts.',
                      style: TextStyle(color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Create Business')),
                        ButtonSegment(value: false, label: Text('Join with Code')),
                      ],
                      selected: {_isOwnerFlow},
                      onSelectionChanged: (s) => setState(() => _isOwnerFlow = s.first),
                    ),
                    const SizedBox(height: 24),
                    if (_isOwnerFlow) ...[
                      TextField(
                        controller: _businessNameController,
                        decoration: const InputDecoration(
                          labelText: 'Business Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _industryType,
                        decoration: const InputDecoration(
                          labelText: 'Industry',
                          border: OutlineInputBorder(),
                        ),
                        items: _industries.entries
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) => setState(() => _industryType = v ?? 'other'),
                      ),
                    ] else ...[
                      TextField(
                        controller: _inviteCodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Invite Code',
                          hintText: 'e.g. ABC123',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ask your manager for an invite code or link.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UniversalTheme.darkSlate,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _isOwnerFlow ? 'Create Business' : 'Join Business',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
