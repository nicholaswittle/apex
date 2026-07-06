import 'package:flutter/material.dart';
import 'package:apex/theme.dart';
import 'package:apex/core/services/business_service.dart';
import 'package:apex/core/services/invite_service.dart';
import 'package:apex/features/dashboard/app_shell.dart';

/// First-login flow: create a business (owner) or join via invite code (staff).
class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({
    super.key,
    required this.userId,
    this.initialInviteCode,
  });

  final String userId;
  final String? initialInviteCode;

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  final _businessNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  String _industryType = 'restaurant';
  bool _isJoinMode = false;
  bool _isLoading = false;

  final _businessService = BusinessService();
  final _inviteService = InviteService();

  @override
  void initState() {
    super.initState();
    if (widget.initialInviteCode != null && widget.initialInviteCode!.isNotEmpty) {
      _inviteCodeController.text = widget.initialInviteCode!;
      _isJoinMode = true;
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _createBusiness() async {
    final name = _businessNameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Enter your business name.', UniversalTheme.alertRed);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _businessService.createBusiness(
        ownerId: widget.userId,
        name: name,
        industryType: _industryType,
      );
      if (!mounted) return;
      _goHome();
    } catch (e) {
      _showMessage('Could not create business: $e', UniversalTheme.alertRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinWithCode() async {
    final code = _inviteCodeController.text.trim();
    if (code.isEmpty) {
      _showMessage('Enter an invite code.', UniversalTheme.alertRed);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _inviteService.joinBusinessWithCode(userId: widget.userId, code: code);
      if (!mounted) return;
      _goHome();
    } catch (e) {
      _showMessage('$e', UniversalTheme.alertRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  void _showMessage(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UniversalTheme.background,
      appBar: AppBar(
        backgroundColor: UniversalTheme.darkSlate,
        foregroundColor: Colors.white,
        title: const Text('Apex Scheduler Setup'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              color: UniversalTheme.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.brown.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Welcome to Apex Scheduler',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: UniversalTheme.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isJoinMode
                          ? 'Join your team with an invite code from your manager.'
                          : 'Set up your business to start scheduling shifts.',
                      style: const TextStyle(color: Colors.grey, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Create Business')),
                        ButtonSegment(value: true, label: Text('Join with Code')),
                      ],
                      selected: {_isJoinMode},
                      onSelectionChanged: (s) => setState(() => _isJoinMode = s.first),
                    ),
                    const SizedBox(height: 24),
                    if (_isJoinMode) ...[
                      TextField(
                        controller: _inviteCodeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Invite Code',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _joinWithCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UniversalTheme.darkSlate,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Join Business'),
                      ),
                    ] else ...[
                      TextField(
                        controller: _businessNameController,
                        decoration: InputDecoration(
                          labelText: 'Business Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _industryType,
                        decoration: InputDecoration(
                          labelText: 'Industry',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: BusinessService.industryTypes
                            .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                            .toList(),
                        onChanged: (v) => setState(() => _industryType = v ?? 'other'),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _createBusiness,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UniversalTheme.darkSlate,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Create Business'),
                      ),
                    ],
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
