import 'package:flutter/material.dart';
import 'package:apex/theme.dart';
import 'package:apex/core/profile_session.dart';
import 'package:apex/core/services/business_service.dart';
import 'package:apex/core/services/plan_service.dart';
import 'package:apex/core/models/plan_tier.dart';

/// Owner home screen with business overview and upcoming shifts.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _businessService = BusinessService();
  final _planService = PlanService();

  Map<String, dynamic>? _business;
  int _staffCount = 0;
  PlanTier _planTier = PlanTier.free;
  List<Map<String, dynamic>> _upcomingShifts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ProfileSession.loadForCurrentUser();
    final businessId = profile.businessId;
    if (businessId == null) return;

    final business = await _businessService.loadBusiness(businessId);
    final staffCount = await _businessService.countStaff(businessId);
    final tier = await _planService.refresh(businessId);
    final shifts = await _businessService.upcomingShifts(businessId);

    if (!mounted) return;
    setState(() {
      _business = business;
      _staffCount = staffCount;
      _planTier = tier;
      _upcomingShifts = shifts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: UniversalTheme.accent));
    }

    final businessName = _business?['name'] as String? ?? 'Your Business';
    final industry = _business?['industry_type'] as String? ?? 'other';

    return RefreshIndicator(
      onRefresh: _load,
      color: UniversalTheme.accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            businessName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: UniversalTheme.darkSlate,
            ),
          ),
          Text(
            _industryLabel(industry),
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _statCard('Staff', '$_staffCount', Icons.people)),
              const SizedBox(width: 12),
              Expanded(child: _planBadge()),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Upcoming Shifts',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: UniversalTheme.darkSlate),
          ),
          const SizedBox(height: 8),
          if (_upcomingShifts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No upcoming shifts scheduled.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ..._upcomingShifts.map((shift) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.event, color: UniversalTheme.accent),
                  title: Text(shift['title']?.toString() ?? 'Shift'),
                  subtitle: Text(
                    'Day ${shift['day_num']} · ${shift['staff'] ?? 'Open'}'
                    '${shift['zone'] != null ? ' · ${shift['zone']}' : ''}',
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: UniversalTheme.accent, size: 22),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _planBadge() {
    final isPro = _planTier.isPro;
    return Card(
      color: isPro ? const Color(0x1AD97706) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isPro ? Icons.workspace_premium : Icons.star_outline, color: UniversalTheme.accent),
            const SizedBox(height: 8),
            const Text('Plan', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text(
              isPro ? 'Pro' : 'Free',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  String _industryLabel(String type) {
    return switch (type) {
      'restaurant' => 'Restaurant',
      'retail' => 'Retail',
      'fitness' => 'Fitness / Gym',
      'healthcare' => 'Healthcare / Clinic',
      _ => 'Business',
    };
  }
}
