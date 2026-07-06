import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:apex/theme.dart';
import 'package:apex/core/profile_session.dart';
import 'package:apex/core/services/business_service.dart';
import 'package:apex/core/services/invite_service.dart';
import 'package:apex/core/services/plan_service.dart';
import 'package:apex/core/models/plan_tier.dart';
import 'package:apex/widgets/upgrade_prompt_widget.dart';

/// Owner screen to generate and manage staff invite codes.
class InviteManagementScreen extends StatefulWidget {
  const InviteManagementScreen({super.key});

  @override
  State<InviteManagementScreen> createState() => _InviteManagementScreenState();
}

class _InviteManagementScreenState extends State<InviteManagementScreen> {
  final _inviteService = InviteService();
  final _planService = PlanService();
  final _businessService = BusinessService();

  List<Map<String, dynamic>> _invites = [];
  PlanTier _planTier = PlanTier.free;
  int _staffCount = 0;
  bool _isLoading = true;
  bool _isCreating = false;
  String? _businessId;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ProfileSession.loadForCurrentUser();
    _businessId = profile.businessId;
    _userId = profile.id;
    if (_businessId == null) return;

    final invites = await _inviteService.listInvites(_businessId!);
    final tier = await _planService.refresh(_businessId!);
    final staffCount = await _businessService.countStaff(_businessId!);

    if (!mounted) return;
    setState(() {
      _invites = invites;
      _planTier = tier;
      _staffCount = staffCount;
      _isLoading = false;
    });
  }

  Future<void> _createInvite() async {
    if (_businessId == null || _userId == null) return;

    if (!_planService.canAddStaff(currentStaffCount: _staffCount, tier: _planTier)) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => const UpgradePromptWidget(
          title: 'Staff limit reached',
          message: 'Free tier allows up to 10 staff members. Upgrade to Pro for unlimited staff.',
        ),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      await _inviteService.createInvite(businessId: _businessId!, createdBy: _userId!);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create invite: $e'), backgroundColor: UniversalTheme.alertRed),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied to clipboard')),
    );
  }

  Future<void> _revoke(String id) async {
    await _inviteService.revokeInvite(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UniversalTheme.background,
      appBar: AppBar(
        backgroundColor: UniversalTheme.darkSlate,
        foregroundColor: Colors.white,
        title: const Text('Staff Invites'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: UniversalTheme.accent))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Share an invite code or link with new staff. They enter the code during signup to join your business.',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isCreating ? null : _createInvite,
                      icon: _isCreating
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add_link),
                      label: const Text('Generate Invite Code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UniversalTheme.darkSlate,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _invites.isEmpty
                      ? const Center(child: Text('No invite codes yet.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _invites.length,
                          itemBuilder: (context, index) {
                            final invite = _invites[index];
                            final code = invite['code'] as String;
                            final uses = invite['use_count'] as int? ?? 0;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: ListTile(
                                title: Text(code, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                                subtitle: Text('Used $uses time${uses == 1 ? '' : 's'}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy),
                                      onPressed: () => _copyCode(code),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: UniversalTheme.alertRed),
                                      onPressed: () => _revoke(invite['id'] as String),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
