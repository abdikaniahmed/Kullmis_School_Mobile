import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/student_management_models.dart';
import '../services/laravel_api.dart';

class StudentsUploadScreen extends StatefulWidget {
  const StudentsUploadScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<StudentsUploadScreen> createState() => _StudentsUploadScreenState();
}

class _StudentsUploadScreenState extends State<StudentsUploadScreen> {
  PlatformFile? _selectedFile;
  StudentImportResult? _result;
  bool _loading = false;
  String? _error;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _selectedFile = result.files.first;
      _result = null;
      _error = null;
    });
  }

  Future<void> _upload() async {
    final file = _selectedFile;
    if (file == null || file.path == null) {
      setState(() {
        _error = 'Select a CSV file to upload.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await widget.api.uploadStudents(
        token: widget.token,
        filePath: file.path!,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
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
        _error = 'Unable to upload students.';
      });
    }
  }

  void _clearForm() {
    setState(() {
      _selectedFile = null;
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Students'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bulk upload students', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Upload a CSV file using the template provided in the web system.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Choose CSV File'),
                ),
                if (_selectedFile != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _selectedFile!.name,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _loading ? null : _upload,
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Upload'),
                    ),
                    OutlinedButton(
                      onPressed: _loading ? null : _clearForm,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFB42318),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upload Summary', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(_result!.message, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Created: ${_result!.created} | Failed: ${_result!.failed}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_result!.errors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Row Errors', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    ..._result!.errors.map(
                      (error) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Row ${error.row}: ${error.errors.join(', ')}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
