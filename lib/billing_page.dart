import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:apex/theme.dart';
import 'package:wisense_ui/wisense_ui.dart';
import 'core/profile_session.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final _supabase = Supabase.instance.client;

  int _staffCount = 0;
  String _subscriptionStatus = 'inactive';
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadBillingData();
  }

  Future<void> _loadBillingData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final ownerData = await _supabase
          .from('profiles')
          .select('subscription_status, organization_id')
          .eq('id', userId!)
          .single();

      final organizationId =
          ownerData['organization_id'] as String? ?? defaultOrganizationId;

      // Scoped to this venue only — unscoped, this would sum staff across
      // every venue on the platform once a second one signs up.
      final staffData = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'Staff')
          .eq('organization_id', organizationId);

      if (!mounted) return;
      setState(() {
        _staffCount = (staffData as List).length;
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
    if (_staffCount <= 5) return 'Tier 1';
    if (_staffCount <= 15) return 'Tier 2';
    return 'Tier 3';
  }

  int get _monthlyRate {
    if (_staffCount <= 5) return 29;
    if (_staffCount <= 15) return 59;
    return 99;
  }

  Future<void> _simulatePayment() async {
    setState(() => _isProcessing = true);
    try {
      // 1. Invoke the Supabase Edge Function to create Stripe PaymentIntent
      final response = await _supabase.functions.invoke(
        'create-payment-intent',
        body: {
          'amount': _monthlyRate * 100, // Cents
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

      // 2. Initialize the Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentSecret,
          customerEphemeralKeySecret: ephemeralKeySecret,
          customerId: customerId,
          merchantDisplayName: 'Apex Scheduler',
          style: ThemeMode.light,
        ),
      );

      // 3. Present the Payment Sheet
      await Stripe.instance.presentPaymentSheet();

      // 4. Ask the backend to verify payment and activate subscription.
      final activation = await _supabase.functions.invoke(
        'create-payment-intent',
        body: {
          'action': 'activate_subscription',
          'paymentIntentId': paymentIntentId,
        },
      );

      if (activation.status != 200) {
        throw 'Payment succeeded but subscription activation is pending server verification.';
      }

      await _loadBillingData();
      if (!mounted) return;
      _showBanner('Subscription activated successfully!', Colors.green);
    } catch (e) {
      if (!mounted) return;
      if (e is StripeException) {
        _showBanner('Payment cancelled: ${e.error.localizedMessage}', UniversalTheme.alertRed);
      } else {
        _showBanner('Payment failed: ${e.toString()}', UniversalTheme.alertRed);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _cancelSubscription() async {
    setState(() => _isProcessing = true);
    try {
      final response = await _supabase.functions.invoke(
        'create-payment-intent',
        body: {'action': 'cancel_subscription'},
      );

      if (response.status != 200) {
        throw 'Subscription cancellation must be confirmed by the billing backend.';
      }

      await _loadBillingData();
      if (!mounted) return;
      _showBanner('Subscription cancelled.', UniversalTheme.alertRed);
    } catch (e) {
      if (!mounted) return;
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
      backgroundColor: UniversalTheme.background,
      appBar: AppBar(
        backgroundColor: UniversalTheme.darkSlate,
        foregroundColor: Colors.white,
        title: const Text(
          'Billing & Subscription',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: UniversalTheme.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(WiSenseSpacing.base),
              child: Column(
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: WiSenseSpacing.base),
                  _buildTierCard(),
                  const SizedBox(height: WiSenseSpacing.base),
                  _buildActionCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final isActive = _subscriptionStatus == 'active';
    return Card(
      color: UniversalTheme.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isActive ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WiSenseSpacing.base),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.check_circle : Icons.cancel,
              color: isActive ? Colors.green : UniversalTheme.alertRed,
              size: 32,
            ),
            const SizedBox(width: WiSenseSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SUBSCRIPTION STATUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.green : UniversalTheme.alertRed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard() {
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
                Icon(Icons.people, color: UniversalTheme.accent),
                SizedBox(width: WiSenseSpacing.sm),
                Text(
                  'PLAN DETAILS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: UniversalTheme.darkSlate,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const Divider(height: WiSenseSpacing.lg),
            _buildDetailRow(
              'Employee Count',
              '$_staffCount staff member${_staffCount == 1 ? '' : 's'}',
            ),
            const SizedBox(height: WiSenseSpacing.md),
            _buildDetailRow('Current Tier', _tierName),
            const SizedBox(height: WiSenseSpacing.md),
            _buildDetailRow('Monthly Rate', '\$$_monthlyRate / month (Flat Rate)'),
            const Divider(height: WiSenseSpacing.lg),
            const Text(
              'PRICING TIERS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: WiSenseSpacing.sm),
            _buildTierRow('Tier 1', '1–5 staff', '\$29/month', _staffCount <= 5),
            _buildTierRow('Tier 2', '6–15 staff', '\$59/month', _staffCount > 5 && _staffCount <= 15),
            _buildTierRow('Tier 3', '16+ staff', '\$99/month', _staffCount > 15),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: UniversalTheme.darkSlate,
          ),
        ),
      ],
    );
  }

  Widget _buildTierRow(String tier, String range, String price, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(bottom: WiSenseSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: WiSenseSpacing.md,
        vertical: WiSenseSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0x1AD97706) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCurrent ? UniversalTheme.accent : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.arrow_right,
            size: 18,
            color: isCurrent ? UniversalTheme.accent : Colors.transparent,
          ),
          const SizedBox(width: WiSenseSpacing.xs),
          Expanded(
            child: Text(
              '$tier ($range)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? UniversalTheme.darkSlate : Colors.grey,
              ),
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isCurrent ? UniversalTheme.accent : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    final isActive = _subscriptionStatus == 'active';
    return Card(
      color: UniversalTheme.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.brown.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WiSenseSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.payment, color: UniversalTheme.accent),
                SizedBox(width: WiSenseSpacing.sm),
                Text(
                  'PAYMENT GATEWAY',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: UniversalTheme.darkSlate,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const Divider(height: WiSenseSpacing.lg),
            if (!isActive) ...[
              Text(
                'Activate your subscription for \$$_monthlyRate/month ($_tierName) to unlock all Apex Scheduler features.',
                style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: WiSenseSpacing.base),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _simulatePayment,
                icon: _isProcessing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.credit_card, size: 18),
                label: Text(
                  _isProcessing
                      ? 'Processing...'
                      : 'Simulate Payment (\$$_monthlyRate/mo)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UniversalTheme.darkSlate,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ] else ...[
              Text(
                'Your $_tierName subscription at \$$_monthlyRate/month is active. You may cancel at any time.',
                style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: WiSenseSpacing.base),
              OutlinedButton.icon(
                onPressed: _isProcessing ? null : _cancelSubscription,
                icon: _isProcessing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: UniversalTheme.alertRed,
                        ),
                      )
                    : const Icon(Icons.cancel_outlined, size: 18),
                label: Text(_isProcessing ? 'Processing...' : 'Cancel Subscription'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: UniversalTheme.alertRed,
                  side: const BorderSide(color: UniversalTheme.alertRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
