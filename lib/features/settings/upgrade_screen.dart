import 'package:flutter/material.dart';
import 'package:apex/theme.dart';
import 'package:apex/core/profile_session.dart';
import 'package:apex/core/services/plan_service.dart';
import 'package:apex/core/models/plan_tier.dart';

/// Free vs Pro comparison with placeholder upgrade CTA (manual beta upgrade).
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  final _planService = PlanService();
  PlanTier _tier = PlanTier.free;
  String? _businessId;
  bool _isLoading = true;
  bool _isUpgrading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ProfileSession.loadForCurrentUser();
    _businessId = profile.businessId;
    if (_businessId != null) {
      _tier = await _planService.refresh(_businessId!);
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _manualUpgrade() async {
    if (_businessId == null) return;
    setState(() => _isUpgrading = true);
    try {
      await _planService.upgradeToProManual(_businessId!);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upgraded to Pro (beta manual activation). Stripe integration coming soon.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upgrade failed: $e'), backgroundColor: UniversalTheme.alertRed),
      );
    } finally {
      if (mounted) setState(() => _isUpgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UniversalTheme.background,
      appBar: AppBar(
        backgroundColor: UniversalTheme.darkSlate,
        foregroundColor: Colors.white,
        title: const Text('Upgrade to Pro'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: UniversalTheme.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_tier.isPro)
                    Card(
                      color: Colors.green.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.verified, color: Colors.green),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You are on the Pro plan. Thank you for supporting Apex Scheduler!',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    title: 'Free',
                    price: '\$0',
                    features: [
                      '1 location',
                      'Up to ${PlanLimits.freeStaffCap} staff',
                      'Shift scheduling & swaps',
                      'Time-off requests',
                    ],
                    isCurrent: !_tier.isPro,
                  ),
                  const SizedBox(height: 16),
                  _buildPlanCard(
                    title: 'Pro',
                    price: '\$49/mo',
                    features: [
                      'Unlimited locations',
                      'Unlimited staff',
                      'Advanced reporting',
                      'Priority support',
                    ],
                    isCurrent: _tier.isPro,
                    highlighted: true,
                  ),
                  const SizedBox(height: 24),
                  if (!_tier.isPro) ...[
                    const Text(
                      'Payment integration (Stripe / RevenueCat) is a placeholder in this beta. '
                      'Tap below to manually activate Pro for testing.',
                      style: TextStyle(color: Colors.grey, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isUpgrading ? null : _manualUpgrade,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UniversalTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isUpgrading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Activate Pro (Beta)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required List<String> features,
    required bool isCurrent,
    bool highlighted = false,
  }) {
    return Card(
      elevation: highlighted ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: highlighted ? UniversalTheme.accent : Colors.grey.shade200,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: UniversalTheme.accent)),
              ],
            ),
            if (isCurrent)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Current plan', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
              ),
            const Divider(height: 24),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
