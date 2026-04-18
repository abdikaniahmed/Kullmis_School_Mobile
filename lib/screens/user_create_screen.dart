import 'package:flutter/material.dart';

import '../models/hr_models.dart';
import '../services/laravel_api.dart';

class UserCreateScreen extends StatefulWidget {
  const UserCreateScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<UserCreateScreen> createState() => _UserCreateScreenState();
}

class _UserCreateScreenState extends State<UserCreateScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  UserCreateMeta? _meta;
  int? _selectedStaffId;
  final Set<String> _selectedRoles = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final meta = await widget.api.usersCreateMeta(token: widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _meta = meta;
        _loading = false;
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
        _error = 'Unable to load user setup.';
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedStaffId == null) {
      setState(() {
        _error = 'Select a staff member.';
      });
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = 'Email is required.';
      });
      return;
    }

    final password = _passwordController.text.trim();
    if (password.length < 8) {
      setState(() {
        _error = 'Password must be at least 8 characters.';
      });
      return;
    }

    if (password != _confirmController.text.trim()) {
      setState(() {
        _error = 'Password confirmation does not match.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.createUser(
        token: widget.token,
        payload: {
          'staff_id': _selectedStaffId,
          'email': email,
          'password': password,
          'password_confirmation': _confirmController.text.trim(),
          'roles': _selectedRoles.toList(),
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('User created.')),
        );

      Navigator.of(context).pop(true);
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
        _error = 'Unable to create user.';
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

    final meta = _meta;

    if (meta == null) {
      return const Scaffold(
        body: Center(child: Text('No data available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add User')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          DropdownButtonFormField<int>(
            value: _selectedStaffId,
            items: meta.staffs
                .map(
                  (staff) => DropdownMenuItem(
                    value: staff.id,
                    child: Text(
                      staff.position == null
                          ? staff.name
                          : '${staff.name} - ${staff.position}',
                    ),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Staff member',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _selectedStaffId = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text('Roles', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...meta.roles.map(
            (role) => CheckboxListTile(
              value: _selectedRoles.contains(role.name),
              title: Text(role.name),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedRoles.add(role.name);
                  } else {
                    _selectedRoles.remove(role.name);
                  }
                });
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB42318),
                  ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Saving...' : 'Create'),
          ),
        ],
      ),
    );
  }
}
