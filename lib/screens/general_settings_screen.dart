import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/settings_models.dart';
import '../services/laravel_api.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  SchoolProfile? _profile;
  PlatformFile? _selectedLogo;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await widget.api.schoolProfile(token: widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _nameController.text = profile.name;
        _addressController.text = profile.address ?? '';
        _contactController.text = profile.contact ?? '';
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
        _error = 'Unable to load school profile.';
      });
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _selectedLogo = result.files.first;
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _error = 'School name is required.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await widget.api.updateSchoolProfile(
        token: widget.token,
        name: name,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        contact: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        logoPath: _selectedLogo?.path,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = updated;
        _selectedLogo = null;
        _saving = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('School profile updated.')),
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
        _error = 'Unable to update school profile.';
      });
    }
  }

  String? _resolveLogoUrl(String? logoUrl) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return null;
    }

    if (logoUrl.startsWith('http')) {
      return logoUrl;
    }

    final base = LaravelApi.baseUrl.replaceAll('/api', '');
    if (logoUrl.startsWith('/')) {
      return '$base$logoUrl';
    }

    return '$base/$logoUrl';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final profile = _profile;
    final logoUrl = _resolveLogoUrl(profile?.logoUrl);

    return Scaffold(
      appBar: AppBar(title: const Text('General Settings')),
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
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          theme.colorScheme.primary.withOpacity(0.12),
                      backgroundImage:
                          logoUrl == null ? null : NetworkImage(logoUrl),
                      child: logoUrl == null
                          ? Icon(
                              Icons.school_outlined,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.name ?? 'School profile',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile?.email ?? '',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'School name',
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
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Contact phone',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _saving ? null : _pickLogo,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Select logo'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedLogo?.name ?? 'No logo selected',
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (kIsWeb && _selectedLogo != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Logo upload requires a supported file picker on web.',
                    style: theme.textTheme.bodySmall,
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
                  onPressed: _saving ? null : _saveProfile,
                  child: Text(_saving ? 'Saving...' : 'Save changes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
