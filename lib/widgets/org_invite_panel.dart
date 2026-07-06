import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apex/theme.dart';
import 'package:wisense_ui/wisense_ui.dart';

class OrgInvitePanel extends StatefulWidget {
  const OrgInvitePanel({super.key});

  @override
  State<OrgInvitePanel> createState() => _OrgInvitePanelState();
}

class _OrgInvitePanelState extends State<OrgInvitePanel> {
  final _supabase = Supabase.instance.client;
  bool _isGenerating = false;
  String? _latestCode;
  List<Map<String, dynamic>> _invites = [];

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    try {
      final data = await _supabase
          .from('organization_invites')
          .select('code, role, expires_at, used_at, created_at')
          .order('created_at', ascending: false)
          .limit(10);
      if (!mounted) return;
      setState(() {
        _invites = ((data as List?)?.cast<Map<String, dynamic>>()) ?? [];
      });
    } catch (_) {}
  }

  Future<void> _generateInvite() async {
    setState(() => _isGenerating = true);
    try {
      final code = await _supabase.rpc('apex_create_invite', params: {
        'invite_role': 'Staff',
      });
      if (!mounted) return;
      setState(() => _latestCode = code as String?);
      await _loadInvites();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite code generated. Share it with your team.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate invite: $e'), backgroundColor: UniversalTheme.alertRed),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied invite code: $code'), backgroundColor: UniversalTheme.darkSlate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: UniversalTheme.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.brown.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WiSenseSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.group_add, color: UniversalTheme.accent),
                SizedBox(width: WiSenseSpacing.sm),
                Text(
                  'TEAM INVITES',
                  style: TextStyle(fontWeight: FontWeight.bold, color: UniversalTheme.darkSlate),
                ),
              ],
            ),
            const Divider(height: WiSenseSpacing.lg),
            const Text(
              'Generate invite codes for staff to register. Codes expire in 14 days.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: WiSenseSpacing.base),
            if (_latestCode != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: UniversalTheme.bannerBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: UniversalTheme.accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _latestCode!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: UniversalTheme.darkSlate,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyCode(_latestCode!),
                      icon: const Icon(Icons.copy, color: UniversalTheme.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: WiSenseSpacing.base),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateInvite,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_link, size: 18),
                label: Text(_isGenerating ? 'Generating...' : 'Generate Staff Invite Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UniversalTheme.darkSlate,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_invites.isNotEmpty) ...[
              const SizedBox(height: WiSenseSpacing.lg),
              const Text(
                'Recent invites',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: WiSenseSpacing.sm),
              ..._invites.map((invite) {
                final used = invite['used_at'] != null;
                final code = invite['code']?.toString() ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(used ? 'Used' : 'Active • ${invite['role']}'),
                  trailing: used
                      ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                      : IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () => _copyCode(code),
                        ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
