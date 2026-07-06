import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apex/theme.dart';
import 'package:apex/core/profile_session.dart';
import 'package:apex/core/services/plan_service.dart';
import 'package:wisense_ui/wisense_ui.dart';

/// Free vs Pro comparison with a placeholder payment CTA.
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  final _planService = PlanService(Supabase.instance.client);
  PlanSnapshot? _plan;
  bool _isLoading = true;
  bool _isUpgrading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ProfileSession.loadForCurrentUser();
    if (profile.businessId == null) return;
    final plan = await _planService.loadForBusiness(profile.businessId!);
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _isLoading = false;
    });
  }

  Future<void> _manualUpgrade() async {
    if (_plan == null) return;
    setState(() => _isUpgrading = true);
    try {
      await _planService.upgradeToPro(_plan!.businessId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upgraded to Pro! (Beta — no payment charged)'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
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
      appBar: AppBar(
        backgroundColor: UniversalTheme.darkSlate,
        title: const Text('Upgrade Plan', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: WiSenseLoadingIndicator())
          : ListView(
              padding: const EdgeInsets.all(WiSenseSpacing.base),
              children: [
                if (_plan?.isPro == true)
                  const Card(
                    color: Color(0xFFE8F5E9),
                    child: ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text('You are on the Pro plan'),
                      subtitle: Text('Thank you for supporting Apex Scheduler!'),
                    ),
                  )
                else ...[
                  _planCard(
                    title: 'Free',
                    price: '\$0',
                    features: [
                      '1 location',
                      'Up to ${PlanService.freeStaffCap} staff',
                      'Basic scheduling',
                      'Shift swaps & time off',
                    ],
                    highlighted: false,
                  ),
                  const SizedBox(height: WiSenseSpacing.base),
                  _planCard(
                    title: 'Pro',
                    price: '\$29/mo',
                    features: const [
                      'Unlimited locations',
                      'Unlimited staff',
                      'Advanced reporting',
                      'Priority support',
                    ],
                    highlighted: true,
                  ),
                  const SizedBox(height: WiSenseSpacing.lg),
                  ElevatedButton(
                    onPressed: _isUpgrading ? null : _manualUpgrade,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UniversalTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isUpgrading
                        ? const WiSenseLoadingIndicator(size: 20, color: Colors.white)
                        : const Text(
                            'Upgrade to Pro (Beta)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                  const SizedBox(height: WiSenseSpacing.sm),
                  const Text(
                    'Stripe / RevenueCat integration coming soon. '
                    'During beta, upgrades are applied instantly with no charge.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _planCard({
    required String title,
    required String price,
    required List<String> features,
    required bool highlighted,
  }) {
    return Card(
      elevation: highlighted ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: highlighted ? UniversalTheme.accent : Colors.grey.shade300,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WiSenseSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(price, style: TextStyle(fontSize: 18, color: Colors.grey.shade700)),
              ],
            ),
            const Divider(height: WiSenseSpacing.lg),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: WiSenseSpacing.sm),
                child: Row(
                  children: [
                    Icon(Icons.check, size: 18, color: highlighted ? UniversalTheme.accent : Colors.grey),
                    const SizedBox(width: WiSenseSpacing.sm),
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
