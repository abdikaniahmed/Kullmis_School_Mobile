import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/hr_models.dart';
import '../services/laravel_api.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final TextEditingController _roleNameController = TextEditingController();

  RoleIndexPayload? _payload;
  int? _selectedRoleId;
  final Set<String> _selectedPermissions = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _canCreate => widget.session.hasPermission('roles.create');
  bool get _canEdit => widget.session.hasPermission('roles.edit');

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _roleNameController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final payload = await widget.api.rolesIndex(token: widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _payload = payload;
        _loading = false;
        if (payload.roles.isNotEmpty && _selectedRoleId == null) {
          _selectRole(payload.roles.first);
        }
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Unable to load roles.';
      });
    }
  }

  void _selectRole(RoleSummary role) {
    setState(() {
      _selectedRoleId = role.id;
      _selectedPermissions
        ..clear()
        ..addAll(role.permissions.map((permission) => permission.name));
    });
  }

  Future<void> _saveRolePermissions() async {
    final roleId = _selectedRoleId;
    if (!_canEdit || roleId == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.updateRolePermissions(
        token: widget.token,
        roleId: roleId,
        permissions: _selectedPermissions.toList(),
      );

      if (!mounted) {
        return;
      }

      await _loadRoles();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Role permissions updated.')),
        );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = 'Unable to update role permissions.';
      });
    }
  }

  Future<void> _createRole() async {
    if (!_canCreate) {
      return;
    }

    final name = _roleNameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Role name is required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.createRole(
        token: widget.token,
        name: name,
        permissions: _selectedPermissions.toList(),
      );

      if (!mounted) {
        return;
      }

      _roleNameController.clear();
      await _loadRoles();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Role created.')),
        );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _error = 'Unable to create role.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final payload = _payload;

    if (payload == null) {
      return const Scaffold(
        body: Center(child: Text('No roles available.')),
      );
    }

    final selectedRole = payload.roles
        .where((role) => role.id == _selectedRoleId)
        .cast<RoleSummary?>()
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Roles')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          DropdownButtonFormField<int>(
            value: _selectedRoleId,
            items: payload.roles
                .map(
                  (role) => DropdownMenuItem(
                    value: role.id,
                    child: Text(role.name),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Select role',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              final role = payload.roles.firstWhere(
                (entry) => entry.id == value,
                orElse: () => payload.roles.first,
              );
              _selectRole(role);
            },
          ),
          if (_canCreate) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _roleNameController,
              decoration: const InputDecoration(
                labelText: 'New role name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _createRole,
              child: Text(_saving ? 'Saving...' : 'Create role'),
            ),
          ],
          const SizedBox(height: 16),
          Text('Permissions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...payload.permissionGroups.map(
            (group) => ExpansionTile(
              title: Text(group.name),
              children: group.permissions
                  .map(
                    (permission) => CheckboxListTile(
                      value: _selectedPermissions.contains(permission.name),
                      title: Text(permission.name),
                      onChanged: !_canEdit || _saving
                          ? null
                          : (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedPermissions.add(permission.name);
                                } else {
                                  _selectedPermissions.remove(permission.name);
                                }
                              });
                            },
                    ),
                  )
                  .toList(),
            ),
          ),
          if (selectedRole != null && _canEdit) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _saveRolePermissions,
              child: Text(_saving ? 'Saving...' : 'Save permissions'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB42318),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
