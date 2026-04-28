import 'package:flutter/material.dart';

import '../models/main_attendance_models.dart';
import '../models/school_reports_models.dart';
import '../models/subject_attendance_models.dart';
import '../services/laravel_api.dart';

class SubjectAttendanceReportScreen extends StatefulWidget {
  const SubjectAttendanceReportScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<SubjectAttendanceReportScreen> createState() =>
      _SubjectAttendanceReportScreenState();
}

class _SubjectAttendanceReportScreenState
    extends State<SubjectAttendanceReportScreen> {
  SubjectAttendanceFilters? _filters;
  SubjectAttendanceReportResponse? _report;
  int? _selectedLevelId;
  int? _selectedClassId;
  int? _selectedPeriodNumber;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _loadingFilters = true;
  bool _loadingReport = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  List<AttendanceClass> get _filteredClasses {
    final filters = _filters;
    if (filters == null) {
      return const [];
    }

    if (_selectedLevelId == null) {
      return filters.classes;
    }

    return filters.classes
        .where((entry) => entry.levelId == _selectedLevelId)
        .toList();
  }

  Future<void> _loadFilters() async {
    setState(() {
      _loadingFilters = true;
      _error = null;
    });

    try {
      final filters = await widget.api.subjectAttendanceFilters(widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _filters = filters;
        _loadingFilters = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingFilters = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingFilters = false;
        _error = 'Unable to load subject attendance report filters.';
      });
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_dateFrom ?? DateTime.now())
          : (_dateTo ?? _dateFrom ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isFrom) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
  }

  Future<void> _loadReport() async {
    setState(() {
      _loadingReport = true;
      _error = null;
    });

    try {
      final report = await widget.api.subjectAttendanceReport(
        token: widget.token,
        academicYearId: _filters?.academicYearId,
        levelId: _selectedLevelId,
        schoolClassId: _selectedClassId,
        dateFrom: _dateFrom == null ? null : _formatDate(_dateFrom!),
        dateTo: _dateTo == null ? null : _formatDate(_dateTo!),
        periodNumber: _selectedPeriodNumber,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _report = report;
        _loadingReport = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _report = null;
        _loadingReport = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _report = null;
        _loadingReport = false;
        _error = 'Unable to load subject attendance report.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = _report;

    return Scaffold(
      appBar: AppBar(title: const Text('Subject Attendance Report')),
      body: RefreshIndicator(
        onRefresh: _loadFilters,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _loadingFilters
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Report Filters', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 16),
                        _DropdownField<int?>(
                          label: 'Level',
                          value: _selectedLevelId,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All Levels'),
                            ),
                            ...?_filters?.levels.map(
                              (item) => DropdownMenuItem<int?>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedLevelId = value;
                              _selectedClassId = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int?>(
                          label: 'Class',
                          value: _selectedClassId,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All Classes'),
                            ),
                            ..._filteredClasses.map(
                              (item) => DropdownMenuItem<int?>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedClassId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int?>(
                          label: 'Period',
                          value: _selectedPeriodNumber,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All Periods'),
                            ),
                            ...?_filters?.periods.map(
                              (item) => DropdownMenuItem<int?>(
                                value: item.value,
                                child: Text(item.label),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedPeriodNumber = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickDate(true),
                                child: Text(
                                  _dateFrom == null
                                      ? 'Date From'
                                      : _formatDate(_dateFrom!),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickDate(false),
                                child: Text(
                                  _dateTo == null
                                      ? 'Date To'
                                      : _formatDate(_dateTo!),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadingReport ? null : _loadReport,
                          icon: const Icon(Icons.fact_check_outlined),
                          label: Text(
                            _loadingReport ? 'Loading...' : 'Load Report',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            if (report != null)
              ...report.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.subjectName ?? '-'} · ${item.className ?? '-'}',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.date} · Period ${item.periodNumber} · ${item.teacherName ?? '-'}',
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text('Present ${item.present}')),
                            Chip(label: Text('Absent ${item.absent}')),
                            Chip(label: Text('Late ${item.late}')),
                            Chip(label: Text('Excused ${item.excused}')),
                            Chip(label: Text('Total ${item.total}')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (!_loadingFilters && !_loadingReport)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Load a subject attendance report to review recent class sessions.',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: items.any((entry) => entry.value == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: items.isEmpty ? null : onChanged,
    );
  }
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
