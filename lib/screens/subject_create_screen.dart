import 'package:flutter/material.dart';

import '../services/laravel_api.dart';

class SubjectCreateScreen extends StatefulWidget {
  const SubjectCreateScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<SubjectCreateScreen> createState() => _SubjectCreateScreenState();
}

class _SubjectCreateScreenState extends State<SubjectCreateScreen> {
  final TextEditingController _orderController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  String _type = 'essential';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _orderController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _error = 'Subject name is required.';
      });
      return;
    }

    final order = int.tryParse(_orderController.text.trim());

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.createSubject(
        token: widget.token,
        payload: {
          'order_number': order,
          'name': name,
          'type': _type,
        },
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Subject created.')),
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
        _error = 'Unable to create subject.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Subject')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          TextField(
            controller: _orderController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Order Number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Subject Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'essential', child: Text('Essential')),
              DropdownMenuItem(value: 'extra', child: Text('Extra')),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _type = value;
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
            child: Text(_saving ? 'Saving...' : 'Create'),
          ),
        ],
      ),
    );
  }
}
