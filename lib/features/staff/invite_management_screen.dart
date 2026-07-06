import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apex/theme.dart';
import 'package:apex/core/profile_session.dart';
import 'package:apex/core/services/invitation_service.dart';
import 'package:apex/core/services/plan_service.dart';
import 'package:apex/features/settings/upgrade_screen.dart';
import 'package:wisense_ui/wisense_ui.dart';

class InviteManagementScreen extends StatefulWidget {
  const InviteManagementScreen({super.key});

  @override
  State<InviteManagementScreen> createState() => _InviteManagementScreenState();
}

class _InviteManagementScreenState extends State<InviteManagementScreen> {
  final _service = InvitationService(Supabase.instance.client);
  final _planService = PlanService(Supabase.instance.client);

  List<Map<String, dynamic>> _invites = [];
  PlanSnapshot? _plan;
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final profile = await ProfileSession.loadForCurrentUser();
      if (profile.businessId == null) return;
      final plan = await _planService.loadForBusiness(profile.businessId!);
      final invites = await _service.listInvites(profile.businessId!);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _invites = invites;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Failed to load invites: $e');
    }
  }

  Future<void> _createInvite() async {
    final profile = await ProfileSession.loadForCurrentUser();
    if (profile.businessId == null) return;

    if (_plan != null && !_plan!.canAddStaff) {
      _showUpgradePrompt();
      return;
    }

    setState(() => _isCreating = true);
    try {
      await _service.createInvite(businessId: profile.businessId!);
      await _load();
    } catch (e) {
      _showSnack('Could not create invite: $e');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showUpgradePrompt() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Staff limit reached'),
        content: UpgradePromptWidget(
          title: 'Free plan: ${PlanService.freeStaffCap} staff max',
          message:
              'Upgrade to Pro for unlimited staff members and advanced reporting.',
          onUpgrade: () {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UpgradeScreen()),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: UniversalTheme.alertRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: UniversalTheme.darkSlate,
        title: const Text('Staff Invites', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreating ? null : _createInvite,
        backgroundColor: UniversalTheme.darkSlate,
        icon: _isCreating
            ? const WiSenseLoadingIndicator(size: 18, color: Colors.white)
            : const Icon(Icons.add_link, color: Colors.white),
        label: const Text('New Invite Code', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: WiSenseLoadingIndicator())
          : ListView(
              padding: const EdgeInsets.all(WiSenseSpacing.base),
              children: [
                if (_plan != null)
                  Text(
                    '${_plan!.staffCount} staff · ${_plan!.tierLabel} plan',
                    style: const TextStyle(color: Colors.grey),
                  ),
                const SizedBox(height: WiSenseSpacing.base),
                if (_invites.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No invite codes yet. Create one to onboard staff.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ..._invites.map(_inviteTile),
              ],
            ),
    );
  }

  Widget _inviteTile(Map<String, dynamic> invite) {
    final code = invite['invite_code'] as String;
    final uses = invite['use_count'] as int? ?? 0;
    final maxUses = invite['max_uses'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: WiSenseSpacing.sm),
      child: ListTile(
        title: Text(code, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        subtitle: Text(
          maxUses != null ? '$uses / $maxUses uses' : '$uses uses',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invite code copied')),
            );
          },
        ),
      ),
    );
  }
}
