import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/hr_models.dart';
import '../services/laravel_api.dart';

class DocumentFormScreen extends StatefulWidget {
  const DocumentFormScreen({
    super.key,
    required this.api,
    required this.token,
    required this.categories,
    required this.statuses,
    this.document,
  });

  final LaravelApi api;
  final String token;
  final List<String> categories;
  final List<String> statuses;
  final DocumentItem? document;

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _staffIdController = TextEditingController();
  final TextEditingController _issuedController = TextEditingController();
  final TextEditingController _expiresController = TextEditingController();

  String _scope = 'school';
  String _category = '';
  String _status = '';
  PlatformFile? _selectedFile;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.document != null;

  @override
  void initState() {
    super.initState();
    final document = widget.document;
    if (document != null) {
      _titleController.text = document.title;
      _descriptionController.text = document.description ?? '';
      _staffIdController.text = document.staffId?.toString() ?? '';
      _issuedController.text = document.issuedAt ?? '';
      _expiresController.text = document.expiresAt ?? '';
      _scope = document.scope.isEmpty ? 'school' : document.scope;
      _category = document.category;
      _status = document.status;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _staffIdController.dispose();
    _issuedController.dispose();
    _expiresController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _selectedFile = result.files.first;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _error = 'Title is required.';
      });
      return;
    }

    if (_category.isEmpty) {
      setState(() {
        _error = 'Category is required.';
      });
      return;
    }

    if (!_isEdit && (_selectedFile?.path == null)) {
      setState(() {
        _error = 'Select a file to upload.';
      });
      return;
    }

    final staffId = int.tryParse(_staffIdController.text.trim());

    setState(() {
      _saving = true;
      _error = null;
    });

    final fields = <String, String>{
      'scope': _scope,
      'category': _category,
      'title': title,
      'status': _status.isEmpty ? 'active' : _status,
    };

    if (_descriptionController.text.trim().isNotEmpty) {
      fields['description'] = _descriptionController.text.trim();
    }

    if (_issuedController.text.trim().isNotEmpty) {
      fields['issued_at'] = _issuedController.text.trim();
    }

    if (_expiresController.text.trim().isNotEmpty) {
      fields['expires_at'] = _expiresController.text.trim();
    }

    if (_scope == 'staff') {
      if (staffId == null) {
        setState(() {
          _saving = false;
          _error = 'Provide a valid staff ID.';
        });
        return;
      }
      fields['staff_id'] = '$staffId';
    }

    try {
      if (_isEdit) {
        await widget.api.updateDocument(
          token: widget.token,
          documentId: widget.document!.id,
          fields: fields,
          filePath: _selectedFile?.path,
        );
      } else {
        await widget.api.createDocument(
          token: widget.token,
          fields: fields,
          filePath: _selectedFile!.path!,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _isEdit ? 'Document updated.' : 'Document created.',
            ),
          ),
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
        _error = 'Unable to save document.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Document' : 'Add Document'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          DropdownButtonFormField<String>(
            value: _scope,
            items: const [
              DropdownMenuItem(value: 'school', child: Text('School')),
              DropdownMenuItem(value: 'staff', child: Text('Staff')),
            ],
            decoration: const InputDecoration(
              labelText: 'Scope',
              border: OutlineInputBorder(),
            ),
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _scope = value;
                    });
                  },
          ),
          if (_scope == 'staff') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _staffIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Staff ID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category.isEmpty ? null : _category,
            items: widget.categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            onChanged: _saving
                ? null
                : (value) {
                    setState(() {
                      _category = value ?? '';
                    });
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _status.isEmpty ? null : _status,
            items: widget.statuses
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  ),
                )
                .toList(),
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            onChanged: _saving
                ? null
                : (value) {
                    setState(() {
                      _status = value ?? '';
                    });
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _issuedController,
            decoration: const InputDecoration(
              labelText: 'Issued at (YYYY-MM-DD)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _expiresController,
            decoration: const InputDecoration(
              labelText: 'Expires at (YYYY-MM-DD)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Select file'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedFile?.name ??
                      (widget.document?.fileName ?? 'No file selected'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
    );
  }
}
