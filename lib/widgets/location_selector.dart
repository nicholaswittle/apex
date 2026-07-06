import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apex/core/profile_session.dart';
import 'package:apex/core/services/plan_service.dart';
import 'package:apex/features/settings/upgrade_screen.dart';
import 'package:wisense_ui/wisense_ui.dart';

class LocationService {
  LocationService(this._client);

  final SupabaseClient _client;
  final _planService = PlanService(_client);

  Future<List<Map<String, dynamic>>> listLocations(String businessId) async {
    final rows = await _client
        .from('locations')
        .select()
        .eq('business_id', businessId)
        .order('created_at');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> addLocation({
    required String businessId,
    required String name,
    String? address,
    required VoidCallback onUpgradeRequired,
  }) async {
    final plan = await _planService.loadForBusiness(businessId);
    if (!plan.canAddLocation) {
      onUpgradeRequired();
      return null;
    }

    final row = await _client.from('locations').insert({
      'business_id': businessId,
      'name': name.trim(),
      'address': address?.trim(),
    }).select().single();

    return row;
  }
}

/// Location selector widget for the schedule view.
class LocationSelector extends StatefulWidget {
  const LocationSelector({
    super.key,
    required this.businessId,
    required this.selectedLocationId,
    required this.onLocationChanged,
    this.isOwner = false,
  });

  final String businessId;
  final String? selectedLocationId;
  final ValueChanged<String?> onLocationChanged;
  final bool isOwner;

  @override
  State<LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends State<LocationSelector> {
  final _service = LocationService(Supabase.instance.client);
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final locations = await _service.listLocations(widget.businessId);
    if (!mounted) return;
    setState(() {
      _locations = locations;
      _isLoading = false;
    });
    if (_locations.isNotEmpty && widget.selectedLocationId == null) {
      widget.onLocationChanged(_locations.first['id'] as String);
    }
  }

  Future<void> _addLocation() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Location name'),
            ),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Address (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );

    if (confirmed != true || nameController.text.trim().isEmpty) return;

    await _service.addLocation(
      businessId: widget.businessId,
      name: nameController.text,
      address: addressController.text,
      onUpgradeRequired: () {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Location limit reached'),
            content: UpgradePromptWidget(
              title: 'Free plan: 1 location',
              message: 'Upgrade to Pro to manage multiple business locations.',
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
      },
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: WiSenseLoadingIndicator(size: 18),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.place, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: widget.selectedLocationId,
                isExpanded: true,
                hint: const Text('Select location'),
                items: _locations
                    .map(
                      (l) => DropdownMenuItem<String?>(
                        value: l['id'] as String,
                        child: Text(l['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: widget.onLocationChanged,
              ),
            ),
          ),
          if (widget.isOwner)
            IconButton(
              icon: const Icon(Icons.add_location_alt),
              tooltip: 'Add location',
              onPressed: _addLocation,
            ),
        ],
      ),
    );
  }
}
