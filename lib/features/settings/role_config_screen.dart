import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apex/theme.dart';
import 'package:apex/core/profile_session.dart';
import 'package:wisense_ui/wisense_ui.dart';

class RoleConfigScreen extends StatefulWidget {
  const RoleConfigScreen({super.key});

  @override
  State<RoleConfigScreen> createState() => _RoleConfigScreenState();
}

class _RoleConfigScreenState extends State<RoleConfigScreen> {
  final _newRoleController = TextEditingController();
  List<Map<String, dynamic>> _roles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _newRoleController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    setState(() => _isLoading = true);
    try {
      final profile = await ProfileSession.loadForCurrentUser();
      if (profile.businessId == null) return;

      final rows = await Supabase.instance.client
          .from('roles')
          .select()
          .eq('business_id', profile.businessId!)
          .order('sort_order');

      if (!mounted) return;
      setState(() {
        _roles = (rows as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addRole() async {
    final name = _newRoleController.text.trim();
    if (name.isEmpty) return;

    final profile = await ProfileSession.loadForCurrentUser();
    if (profile.businessId == null) return;

    await Supabase.instance.client.from('roles').insert({
      'business_id': profile.businessId,
      'name': name,
      'sort_order': _roles.length,
    });

    _newRoleController.clear();
    await _loadRoles();
  }

  Future<void> _deleteRole(String id) async {
    await Supabase.instance.client.from('roles').delete().eq('id', id);
    await _loadRoles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: UniversalTheme.darkSlate,
        title: const Text('Shift Roles', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: WiSenseLoadingIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(WiSenseSpacing.base),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newRoleController,
                          decoration: const InputDecoration(
                            labelText: 'New role name',
                            hintText: 'e.g. Cashier, Trainer, Nurse',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: WiSenseSpacing.sm),
                      ElevatedButton(
                        onPressed: _addRole,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UniversalTheme.darkSlate,
                        ),
                        child: const Text('Add', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _roles.isEmpty
                      ? const Center(child: Text('No roles configured yet.'))
                      : ListView.builder(
                          itemCount: _roles.length,
                          itemBuilder: (context, index) {
                            final role = _roles[index];
                            return ListTile(
                              title: Text(role['name'] as String),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteRole(role['id'] as String),
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
