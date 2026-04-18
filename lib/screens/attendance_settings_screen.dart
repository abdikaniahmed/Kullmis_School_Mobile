import 'package:flutter/material.dart';

import '../models/settings_models.dart';
import '../services/laravel_api.dart';

class AttendanceSettingsScreen extends StatefulWidget {
  const AttendanceSettingsScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<AttendanceSettingsScreen> createState() =>
      _AttendanceSettingsScreenState();
}

class _AttendanceSettingsScreenState extends State<AttendanceSettingsScreen> {
  final TextEditingController _lockAfterController = TextEditingController();
  final TextEditingController _periodsController = TextEditingController();

  AttendanceSetting? _setting;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _lockAfterController.dispose();
    _periodsController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final setting = await widget.api.attendanceSettings(token: widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _setting = setting;
        _lockAfterController.text = setting.lockAfterDays.toString();
        _periodsController.text = setting.periodsPerDay.toString();
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
        _error = 'Unable to load attendance settings.';
      });
    }
  }

  Future<void> _saveSettings() async {
    final lockAfter = int.tryParse(_lockAfterController.text.trim());
    final periods = int.tryParse(_periodsController.text.trim());

    if (lockAfter == null || lockAfter < 0 || lockAfter > 30) {
      setState(() {
        _error = 'Lock after days must be between 0 and 30.';
      });
      return;
    }

    if (periods == null || periods < 1 || periods > 12) {
      setState(() {
        _error = 'Periods per day must be between 1 and 12.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.api.updateAttendanceSettings(
        token: widget.token,
        lockAfterDays: lockAfter,
        periodsPerDay: periods,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _setting = AttendanceSetting(
          lockAfterDays: lockAfter,
          periodsPerDay: periods,
        );
        _saving = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Attendance settings updated.')),
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
        _error = 'Unable to update attendance settings.';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          TextField(
            controller: _lockAfterController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Lock attendance after (days)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _periodsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Periods per day',
              border: OutlineInputBorder(),
            ),
          ),
          if (_setting != null) ...[
            const SizedBox(height: 12),
            Text(
              'Current: lock after ${_setting!.lockAfterDays} days, ${_setting!.periodsPerDay} periods/day.',
              style: theme.textTheme.bodyMedium,
            ),
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
            onPressed: _saving ? null : _saveSettings,
            child: Text(_saving ? 'Saving...' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
