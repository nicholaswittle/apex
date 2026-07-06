import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apex/theme.dart';
import 'package:apex/auth_page.dart';
import 'package:apex/calendar_page.dart';
import 'package:apex/core/profile_session.dart';
import 'package:apex/core/services/plan_service.dart';
import 'package:apex/features/onboarding/business_setup_screen.dart';
import 'package:apex/features/settings/role_config_screen.dart';
import 'package:apex/features/settings/upgrade_screen.dart';
import 'package:apex/features/staff/invite_management_screen.dart';
import 'package:wisense_ui/wisense_ui.dart';

/// Owner home — business overview with live metrics scoped to business_id.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.userEmail});

  final String userEmail;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _planService = PlanService(Supabase.instance.client);

  UserProfile? _profile;
  PlanSnapshot? _plan;
  int _upcomingShifts = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final profile = await ProfileSession.loadForCurrentUser();
      if (!profile.hasBusiness) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BusinessSetupScreen(
              userEmail: widget.userEmail,
              userName: profile.name,
            ),
          ),
        );
        return;
      }

      final plan = await _planService.loadForBusiness(profile.businessId!);
      final today = DateTime.now().day;
      final shifts = await Supabase.instance.client
          .from('shifts')
          .select('id')
          .eq('business_id', profile.businessId!)
          .gte('day_num', today)
          .lte('day_num', today + 7);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _plan = plan;
        _upcomingShifts = (shifts as List).length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: WiSenseLoadingIndicator()));
    }

    final profile = _profile!;
    final plan = _plan!;

    return Scaffold(
      backgroundColor: UniversalTheme.background,
      appBar: AppBar(
        backgroundColor: UniversalTheme.darkSlate,
        title: const Text(
          'Apex Scheduler',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(WiSenseSpacing.base),
        children: [
          _headerCard(plan),
          const SizedBox(height: WiSenseSpacing.base),
          _metricRow(plan),
          const SizedBox(height: WiSenseSpacing.lg),
          const Text(
            'Quick Actions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: WiSenseSpacing.sm),
          _actionTile(
            icon: Icons.calendar_month,
            title: 'Open Schedule',
            subtitle: 'View and manage shifts',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CalendarPage(
                  userEmail: widget.userEmail,
                  userName: profile.name,
                  userRole: profile.role,
                  businessId: profile.businessId!,
                ),
              ),
            ),
          ),
          if (profile.isOwner) ...[
            _actionTile(
              icon: Icons.person_add,
              title: 'Invite Staff',
              subtitle: 'Generate invite codes',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InviteManagementScreen()),
              ),
            ),
            _actionTile(
              icon: Icons.badge_outlined,
              title: 'Configure Roles',
              subtitle: 'Define shift position names',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoleConfigScreen()),
              ),
            ),
            _actionTile(
              icon: Icons.workspace_premium,
              title: 'Upgrade Plan',
              subtitle: plan.isPro ? 'Pro plan active' : 'Unlock multiple locations',
              onTap: () async {
                final upgraded = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                );
                if (upgraded == true) _load();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerCard(PlanSnapshot plan) {
    return Card(
      color: UniversalTheme.darkSlate,
      child: Padding(
        padding: const EdgeInsets.all(WiSenseSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.businessName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: WiSenseSpacing.sm),
            Row(
              children: [
                _badge(plan.tierLabel, plan.isPro ? Colors.green : Colors.grey),
                const SizedBox(width: WiSenseSpacing.sm),
                if (_profile?.industryType != null)
                  _badge(_profile!.industryType!, UniversalTheme.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _metricRow(PlanSnapshot plan) {
    return Row(
      children: [
        Expanded(
          child: _metricCard('Active Staff', '${plan.staffCount}', Icons.people),
        ),
        const SizedBox(width: WiSenseSpacing.sm),
        Expanded(
          child: _metricCard('Locations', '${plan.locationCount}', Icons.place),
        ),
        const SizedBox(width: WiSenseSpacing.sm),
        Expanded(
          child: _metricCard('Upcoming', '$_upcomingShifts', Icons.event),
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(WiSenseSpacing.md),
        child: Column(
          children: [
            Icon(icon, color: UniversalTheme.accent),
            const SizedBox(height: WiSenseSpacing.xs),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: WiSenseSpacing.sm),
      child: ListTile(
        leading: Icon(icon, color: UniversalTheme.darkSlate),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
