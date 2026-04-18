import 'package:flutter/material.dart';

import '../models/settings_models.dart';
import '../services/laravel_api.dart';

class SetupConfigScreen extends StatefulWidget {
  const SetupConfigScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<SetupConfigScreen> createState() => _SetupConfigScreenState();
}

class _SetupConfigScreenState extends State<SetupConfigScreen> {
  static const List<String> _dateFormats = [
    'DD/MM/YYYY',
    'DD/MM/YY',
    'D/M/YY',
    'D.M.YY',
    'YYYY-MM-DD',
  ];

  final TextEditingController _rollPrefixController = TextEditingController();
  final TextEditingController _rollNextController = TextEditingController();
  final TextEditingController _invoicePrefixController =
      TextEditingController();
  final TextEditingController _invoiceNextController = TextEditingController();

  SetupConfig? _config;
  String _selectedDateFormat = _dateFormats.first;
  bool _includeDate = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _rollPrefixController.dispose();
    _rollNextController.dispose();
    _invoicePrefixController.dispose();
    _invoiceNextController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final config = await widget.api.setupConfig(token: widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _config = config;
        _rollPrefixController.text = config.studentRollPrefix;
        _rollNextController.text = config.studentRollNextNumber.toString();
        _invoicePrefixController.text = config.invoicePrefix;
        _invoiceNextController.text = config.invoiceNextNumber.toString();
        _includeDate = config.invoiceNumberIncludeDate;
        _selectedDateFormat = _dateFormats.contains(config.dateFormat)
            ? config.dateFormat
            : _dateFormats.first;
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
        _error = 'Unable to load setup configuration.';
      });
    }
  }

  Future<void> _saveConfig() async {
    final rollNext = int.tryParse(_rollNextController.text.trim());
    final invoiceNext = int.tryParse(_invoiceNextController.text.trim());

    if (rollNext == null || rollNext < 1) {
      setState(() {
        _error = 'Student roll next number must be at least 1.';
      });
      return;
    }

    if (invoiceNext == null || invoiceNext < 1) {
      setState(() {
        _error = 'Invoice next number must be at least 1.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await widget.api.updateSetupConfig(
        token: widget.token,
        studentRollPrefix: _rollPrefixController.text.trim().isEmpty
            ? null
            : _rollPrefixController.text.trim(),
        studentRollNextNumber: rollNext,
        invoicePrefix: _invoicePrefixController.text.trim().isEmpty
            ? null
            : _invoicePrefixController.text.trim(),
        invoiceNextNumber: invoiceNext,
        invoiceNumberIncludeDate: _includeDate,
        dateFormat: _selectedDateFormat,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _config = updated;
        _saving = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Setup configuration updated.')),
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
        _error = 'Unable to update setup configuration.';
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

    final theme = Theme.of(context);
    final config = _config;

    return Scaffold(
      appBar: AppBar(title: const Text('Setup Config')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          TextField(
            controller: _rollPrefixController,
            decoration: const InputDecoration(
              labelText: 'Student roll prefix',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rollNextController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Student roll next number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _invoicePrefixController,
            decoration: const InputDecoration(
              labelText: 'Invoice prefix',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _invoiceNextController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Invoice next number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include date in invoice number'),
            value: _includeDate,
            onChanged: _saving
                ? null
                : (value) => setState(() {
                      _includeDate = value;
                    }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedDateFormat,
            items: _dateFormats
                .map(
                  (format) => DropdownMenuItem(
                    value: format,
                    child: Text(format),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Date format',
              border: OutlineInputBorder(),
            ),
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedDateFormat = value;
                    });
                  },
          ),
          if (config != null) ...[
            const SizedBox(height: 16),
            Text('Preview', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if ((config.studentRollPreview ?? '').isNotEmpty)
              Text('Student roll: ${config.studentRollPreview}'),
            if ((config.invoicePreview ?? '').isNotEmpty)
              Text('Invoice: ${config.invoicePreview}'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFB42318),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _saveConfig,
            child: Text(_saving ? 'Saving...' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
