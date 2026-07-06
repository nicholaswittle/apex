import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:apex/theme.dart';
import 'package:wisense_ui/wisense_ui.dart';
import 'core/profile_session.dart';
import 'core/services/plan_service.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final _supabase = Supabase.instance.client;
  final _planService = PlanService(Supabase.instance.client);

  int _staffCount = 0;
  String _subscriptionStatus = 'inactive';
  String _planTier = 'free';
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadBillingData();
  }

  Future<void> _loadBillingData() async {
    try {
      final profile = await ProfileSession.loadForCurrentUser();
      if (profile.businessId == null) return;

      final plan = await _planService.loadForBusiness(profile.businessId!);

      final ownerData = await _supabase
          .from('profiles')
          .select('subscription_status')
          .eq('id', profile.userId)
          .single();

      if (!mounted) return;
      setState(() {
        _staffCount = plan.staffCount;
        _planTier = plan.planTier;
        _subscriptionStatus = ownerData['subscription_status'] as String? ?? 'inactive';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showBanner('Failed to load billing data: $e', UniversalTheme.alertRed);
    }
  }

  String get _tierName {
    if (_planTier == 'pro') return 'Pro';
    if (_staffCount <= 5) return 'Tier 1';
    if (_staffCount <= 15) return 'Tier 2';
    return 'Tier 3';
  }

  int get _monthlyRate {
    if (_planTier == 'pro') return 29;
    if (_staffCount <= 5) return 29;
    if (_staffCount <= 15) return 59;
    return 99;
  }

  Future<void> _simulatePayment() async {
    setState(() => _isProcessing = true);
    try {
      final response = await _supabase.functions.invoke(
        'create-payment-intent',
        body: {
          'amount': _monthlyRate * 100,
          'currency': 'usd',
        },
      );

      if (response.status != 200) {
        throw 'Failed to generate Stripe payment intent from cloud backend.';
      }

      final data = response.data as Map<String, dynamic>;
      final paymentIntentSecret = data['paymentIntent'] as String?;
      final paymentIntentId = data['paymentIntentId'] as String?;
      final ephemeralKeySecret = data['ephemeralKey'] as String?;
      final customerId = data['customer'] as String?;

      if (paymentIntentSecret == null ||
          paymentIntentId == null ||
          ephemeralKeySecret == null ||
          customerId == null) {
        throw 'Stripe client secrets are missing from the function response.';
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentSecret,
          merchantDisplayName: 'Apex Scheduler',
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKeySecret,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      await _supabase.functions.invoke(
        'create-payment-intent',
        body: {'action': 'activate_subscription'},
      );

      _showBanner('Subscription activated!', Colors.green);
      await _loadBillingData();
    } catch (e) {
      _showBanner('Payment failed: $e', UniversalTheme.alertRed);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _cancelSubscription() async {
    setState(() => _isProcessing = true);
    try {
      await _supabase.functions.invoke(
        'create-payment-intent',
        body: {'action': 'cancel_subscription'},
      );
      _showBanner('Subscription cancelled.', UniversalTheme.darkSlate);
      await _loadBillingData();
    } catch (e) {
      _showBanner('Cancellation failed: $e', UniversalTheme.alertRed);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showBanner(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: UniversalTheme.darkSlate,
        title: const Text('Billing', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: WiSenseLoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(WiSenseSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: WiSenseSpacing.base),
                  _buildPricingCard(),
                  const SizedBox(height: WiSenseSpacing.base),
                  if (_subscriptionStatus == 'active')
                    OutlinedButton(
                      onPressed: _isProcessing ? null : _cancelSubscription,
                      child: const Text('Cancel Subscription'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _simulatePayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UniversalTheme.darkSlate,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isProcessing
                          ? const WiSenseLoadingIndicator(size: 20, color: Colors.white)
                          : const Text('Subscribe Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(WiSenseSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _subscriptionStatus == 'active' ? Icons.check_circle : Icons.info_outline,
                  color: _subscriptionStatus == 'active' ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: WiSenseSpacing.md),
                Text(
                  _subscriptionStatus == 'active' ? 'Active Subscription' : 'No Active Subscription',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: WiSenseSpacing.lg),
            Text('Plan: $_tierName'),
            Text('Staff count: $_staffCount'),
            Text('Business tier: ${_planTier == 'pro' ? 'Pro' : 'Free'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(WiSenseSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Current Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: WiSenseSpacing.lg),
            Text('\$${_monthlyRate}/month', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: WiSenseSpacing.sm),
            const Text('Based on staff count and plan tier.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
