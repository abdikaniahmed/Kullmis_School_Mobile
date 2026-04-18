import 'package:flutter/material.dart';

import '../models/hr_models.dart';
import '../services/laravel_api.dart';

class UserEditScreen extends StatefulWidget {
  const UserEditScreen({
    super.key,
    required this.api,
    required this.token,
    required this.userId,
  });

  final LaravelApi api;
  final String token;
  final int userId;

  @override
  State<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  UserEditMeta? _meta;
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
      final meta = await widget.api.usersEditMeta(
        token: widget.token,
        userId: widget.userId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _meta = meta;
        _emailController.text = meta.user.email;
        _selectedRoles
          ..clear()
          ..addAll(meta.user.roles.map((role) => role.name));
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
        _error = 'Unable to load user.';
      });
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _error = 'Email is required.';
      });
      return;
    }

    final password = _passwordController.text.trim();
    if (password.isNotEmpty && password.length < 8) {
      setState(() {
        _error = 'Password must be at least 8 characters.';
      });
      return;
    }

    if (password.isNotEmpty && password != _confirmController.text.trim()) {
      setState(() {
        _error = 'Password confirmation does not match.';
      });
      return;
    }

    final payload = <String, dynamic>{
      'email': email,
      'roles': _selectedRoles.toList(),
    };

    if (password.isNotEmpty) {
      payload['password'] = password;
      payload['password_confirmation'] = _confirmController.text.trim();
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.updateUser(
        token: widget.token,
        userId: widget.userId,
        payload: payload,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('User updated.')),
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
        _error = 'Unable to update user.';
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
      appBar: AppBar(title: const Text('Edit User')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
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
              labelText: 'New password (optional)',
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
            child: Text(_saving ? 'Saving...' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
