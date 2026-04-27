import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/backup_models.dart';
import '../services/laravel_api.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  PlatformFile? _selectedFile;
  BackupRestoreResult? _restoreResult;
  bool _exporting = false;
  bool _restoring = false;
  bool _confirmRestore = false;
  String? _error;
  String? _savedExportPath;

  Future<void> _downloadBackup() async {
    setState(() {
      _exporting = true;
      _error = null;
      _savedExportPath = null;
    });

    try {
      final result = await widget.api.downloadSchoolBackup(
        token: widget.token,
      );

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}${result.fileName}',
      );
      await file.writeAsBytes(result.bytes, flush: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _savedExportPath = file.path;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Backup downloaded to ${file.path}'),
          ),
        );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to download backup.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<void> _pickRestoreFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _selectedFile = result.files.first;
      _restoreResult = null;
      _error = null;
    });
  }

  Future<void> _restoreBackup() async {
    final file = _selectedFile;
    if (file == null || file.path == null) {
      setState(() {
        _error = 'Select a backup ZIP file first.';
      });
      return;
    }

    if (!_confirmRestore) {
      setState(() {
        _error = 'Confirm that restore will overwrite current school data.';
      });
      return;
    }

    setState(() {
      _restoring = true;
      _error = null;
      _restoreResult = null;
    });

    try {
      final result = await widget.api.restoreSchoolBackup(
        token: widget.token,
        filePath: file.path!,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _restoreResult = result;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(result.message)),
        );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Unable to restore backup.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _restoring = false;
        });
      }
    }
  }

  void _resetRestoreForm() {
    setState(() {
      _selectedFile = null;
      _confirmRestore = false;
      _restoreResult = null;
      _error = null;
    });
  }

  List<Widget> _buildSummaryRows(Map<String, dynamic> summary) {
    return summary.entries.map((entry) {
      final value = entry.value;
      final displayValue = value is List
          ? value.map((item) => '$item').join(', ')
          : '$value';

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                entry.key.replaceAll('_', ' '),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                displayValue,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _restoreResult;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Export School Backup', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Export a ZIP file for the current school. Keep it secure because it contains sensitive data.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _exporting ? null : _downloadBackup,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(_exporting ? 'Preparing...' : 'Download Backup ZIP'),
                ),
                if (_savedExportPath != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Saved to: $_savedExportPath',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Restore School Backup', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Restore overwrites the current school data with the uploaded backup ZIP.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'This action replaces the current school data. Use only a backup created from this same school.',
                    style: TextStyle(color: Color(0xFF991B1B)),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _restoring ? null : _pickRestoreFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Choose Backup ZIP'),
                ),
                if (_selectedFile != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Selected: ${_selectedFile!.name}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _confirmRestore,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'I understand that restore will overwrite the current school data.',
                  ),
                  onChanged: _restoring
                      ? null
                      : (value) {
                          setState(() {
                            _confirmRestore = value ?? false;
                          });
                        },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: _restoring ? null : _resetRestoreForm,
                      child: const Text('Reset'),
                    ),
                    FilledButton(
                      onPressed: _restoring ? null : _restoreBackup,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB91C1C),
                      ),
                      child: Text(_restoring ? 'Restoring...' : 'Restore Backup'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB42318),
                  ),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Restore Summary', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(result.message, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  ..._buildSummaryRows(result.summary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
