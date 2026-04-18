import 'package:flutter/material.dart';

import '../models/hr_models.dart';
import '../services/laravel_api.dart';

class AuditDetailScreen extends StatefulWidget {
  const AuditDetailScreen({
    super.key,
    required this.api,
    required this.token,
    required this.auditId,
  });

  final LaravelApi api;
  final String token;
  final int auditId;

  @override
  State<AuditDetailScreen> createState() => _AuditDetailScreenState();
}

class _AuditDetailScreenState extends State<AuditDetailScreen> {
  AuditLogItem? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await widget.api.auditDetail(
        token: widget.token,
        auditId: widget.auditId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = detail;
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
        _error = 'Unable to load audit log.';
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

    if (_detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Audit Detail')),
        body: Center(
          child: Text(_error ?? 'Audit log not found.'),
        ),
      );
    }

    final detail = _detail!;

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Detail')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _InfoTile(label: 'Description', value: detail.description ?? '-'),
          _InfoTile(label: 'Event', value: detail.event ?? '-'),
          _InfoTile(label: 'Log', value: detail.logName ?? '-'),
          _InfoTile(label: 'Subject Type', value: detail.subjectType ?? '-'),
          _InfoTile(
            label: 'Subject ID',
            value: detail.subjectId?.toString() ?? '-',
          ),
          _InfoTile(label: 'User', value: detail.causer?.name ?? 'System'),
          _InfoTile(label: 'Created at', value: detail.createdAt ?? '-'),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB42318),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(value),
        ],
      ),
    );
  }
}
