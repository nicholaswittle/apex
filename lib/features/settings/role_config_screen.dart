import 'package:flutter/material.dart';
import 'package:apex/theme.dart';
import 'package:apex/core/profile_session.dart';
import 'package:apex/core/services/role_service.dart';

/// Lightweight screen for owners to define position/role names.
class RoleConfigScreen extends StatefulWidget {
  const RoleConfigScreen({super.key});

  @override
  State<RoleConfigScreen> createState() => _RoleConfigScreenState();
}

class _RoleConfigScreenState extends State<RoleConfigScreen> {
  final _roleService = RoleService();
  final _newRoleController = TextEditingController();

  List<String> _roles = [];
  String? _businessId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newRoleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await ProfileSession.loadForCurrentUser();
    _businessId = profile.businessId;
    if (_businessId == null) return;

    final roles = await _roleService.loadRoleNames(_businessId!);
    if (!mounted) return;
    setState(() {
      _roles = roles;
      _isLoading = false;
    });
  }

  Future<void> _addRole() async {
    final name = _newRoleController.text.trim();
    if (name.isEmpty || _businessId == null) return;

    try {
      await _roleService.addRole(_businessId!, name);
      _newRoleController.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add role: $e'), backgroundColor: UniversalTheme.alertRed),
      );
    }
  }

  Future<void> _removeRole(String name) async {
    if (_businessId == null) return;
    await _roleService.removeRole(_businessId!, name);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UniversalTheme.background,
      appBar: AppBar(
        backgroundColor: UniversalTheme.darkSlate,
        foregroundColor: Colors.white,
        title: const Text('Role Configuration'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: UniversalTheme.accent))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Define position names used when assigning shifts. Each business configures its own roles.',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newRoleController,
                          decoration: InputDecoration(
                            labelText: 'New role name',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addRole,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UniversalTheme.darkSlate,
                          foregroundColor: Colors.white,
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: _roles.length,
                    itemBuilder: (context, index) {
                      final role = _roles[index];
                      return ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(role),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: UniversalTheme.alertRed),
                          onPressed: () => _removeRole(role),
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
