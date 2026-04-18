import 'package:flutter/material.dart';

import '../models/hr_models.dart';
import '../services/laravel_api.dart';

class StaffEditScreen extends StatefulWidget {
  const StaffEditScreen({
    super.key,
    required this.api,
    required this.token,
    required this.staffId,
  });

  final LaravelApi api;
  final String token;
  final int staffId;

  @override
  State<StaffEditScreen> createState() => _StaffEditScreenState();
}

class _StaffEditScreenState extends State<StaffEditScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  static const List<String> _types = [
    'teacher',
    'admin',
    'registrar',
    'accountant',
    'librarian',
    'other',
  ];

  static const List<String> _genders = [
    'male',
    'female',
  ];

  StaffMember? _staff;
  String _type = _types.first;
  String? _gender;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _positionController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final staff = await widget.api.staffDetail(
        token: widget.token,
        staffId: widget.staffId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _staff = staff;
        _nameController.text = staff.name;
        _phoneController.text = staff.phone ?? '';
        _emailController.text = staff.email ?? '';
        _positionController.text = staff.position ?? '';
        _addressController.text = staff.address ?? '';
        _dobController.text = staff.dateOfBirth ?? '';
        _type = _types.contains(staff.type) ? staff.type : _types.first;
        _gender = staff.gender;
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
        _error = 'Unable to load staff.';
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _error = 'Staff name is required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.updateStaff(
        token: widget.token,
        staffId: widget.staffId,
        payload: {
          'name': name,
          'phone': _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          'email': _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          'position': _positionController.text.trim().isEmpty
              ? null
              : _positionController.text.trim(),
          'type': _type,
          'address': _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          'date_of_birth': _dobController.text.trim().isEmpty
              ? null
              : _dobController.text.trim(),
          'gender': _gender,
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Staff updated.')),
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
        _error = 'Unable to update staff.';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Staff')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _positionController,
            decoration: const InputDecoration(
              labelText: 'Position',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            items: _types
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _type = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
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
            controller: _addressController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dobController,
            decoration: const InputDecoration(
              labelText: 'Date of birth (YYYY-MM-DD)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _gender,
            items: _genders
                .map(
                  (gender) => DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _gender = value;
              });
            },
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
