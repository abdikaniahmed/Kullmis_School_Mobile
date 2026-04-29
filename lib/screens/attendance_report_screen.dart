import 'package:flutter/material.dart';

import '../models/main_attendance_models.dart';
import '../models/school_reports_models.dart';
import '../services/laravel_api.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  ActiveAcademicYear? _academicYear;
  List<MainAttendanceLevel> _levels = const [];
  List<MainAttendanceClass> _classes = const [];
  AttendanceReportResponse? _report;
  int? _selectedLevelId;
  int? _selectedClassId;
  String _selectedShift = 'shift_1';
  String _reportType = 'monthly';
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  int _recentDays = 7;
  bool _loadingFilters = true;
  bool _loadingReport = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  List<MainAttendanceClass> get _filteredClasses {
    if (_selectedLevelId == null) {
      return _classes;
    }

    return _classes
        .where((entry) => entry.levelId == _selectedLevelId)
        .toList();
  }

  String get _reportTitle {
    switch (_reportType) {
      case 'daily':
        return 'Daily Attendance Report';
      case 'yesterday':
        return 'Yesterday Attendance Report';
      case 'recent':
        return 'Recent Attendance Report';
      default:
        return 'Attendance Report';
    }
  }

  Future<void> _loadFilters() async {
    setState(() {
      _loadingFilters = true;
      _error = null;
    });

    try {
      final academicYear = await widget.api.activeAcademicYear(widget.token);
      final levels = await widget.api.attendanceLevels(widget.token);
      final classes = await widget.api.schoolClasses(
        token: widget.token,
        includeAll: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _academicYear = academicYear;
        _levels = levels;
        _classes = classes;
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
        _error = 'Unable to load attendance report filters.';
      });
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
    });
  }

  Future<void> _loadReport() async {
    final academicYear = _academicYear;
    if (academicYear == null) {
      return;
    }

    setState(() {
      _loadingReport = true;
      _error = null;
    });

    try {
      final report = await widget.api.attendanceReport(
        token: widget.token,
        academicYearId: academicYear.id,
        levelId: _selectedLevelId,
        schoolClassId: _selectedClassId,
        shift: _selectedShift,
        reportType: _reportType,
        month: _reportType == 'monthly' ? _formatMonth(_selectedMonth) : null,
        date: _reportType == 'daily' ? _formatDate(_selectedDate) : null,
        recentDays: _reportType == 'recent' ? _recentDays : null,
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
        _error = 'Unable to load attendance report.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = _report;

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Report')),
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
                        _DropdownField<String>(
                          label: 'Report Type',
                          value: _reportType,
                          items: const [
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text('Monthly'),
                            ),
                            DropdownMenuItem(
                              value: 'daily',
                              child: Text('Specific Day'),
                            ),
                            DropdownMenuItem(
                              value: 'yesterday',
                              child: Text('Yesterday'),
                            ),
                            DropdownMenuItem(
                              value: 'recent',
                              child: Text('Recent'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _reportType = value;
                              _report = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<int?>(
                          label: 'Level',
                          value: _selectedLevelId,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All Levels'),
                            ),
                            ..._levels.map(
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
                              _report = null;
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
                              _report = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _DropdownField<String>(
                          label: 'Shift',
                          value: _selectedShift,
                          items: const [
                            DropdownMenuItem(
                              value: 'shift_1',
                              child: Text('Shift 1'),
                            ),
                            DropdownMenuItem(
                              value: 'shift_2',
                              child: Text('Shift 2'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _selectedShift = value;
                              _report = null;
                            });
                          },
                        ),
                        if (_reportType == 'monthly') ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _pickMonth,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(_formatMonth(_selectedMonth)),
                          ),
                        ],
                        if (_reportType == 'daily') ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(_formatDate(_selectedDate)),
                          ),
                        ],
                        if (_reportType == 'recent') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: '$_recentDays',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Recent Days',
                            ),
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              setState(() {
                                _recentDays = parsed == null
                                    ? 7
                                    : parsed.clamp(1, 30);
                                _report = null;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadingReport ? null : _loadReport,
                          icon: const Icon(Icons.analytics_outlined),
                          label: Text(
                            _loadingReport ? 'Loading...' : 'Generate Report',
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
            if (report != null) ...[
              _buildHeaderCard(context, report),
              const SizedBox(height: 12),
              ...report.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: report.isDailyView
                      ? _buildDailyCard(context, item)
                      : _buildSummaryCard(context, item),
                ),
              ),
            ] else if (!_loadingFilters && !_loadingReport)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Generate an attendance report to review monthly, specific-day, yesterday, or recent attendance.',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    AttendanceReportResponse report,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_reportTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            report.periodLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475467),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${report.items.length} students',
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCard(BuildContext context, AttendanceReportRow item) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.studentName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${item.className ?? '-'} · Roll ${item.rollNumber ?? '-'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475467),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(_formatStatus(item.status)),
                backgroundColor: _statusColor(item.status),
              ),
              if (item.remarks != null && item.remarks!.isNotEmpty)
                Chip(label: Text(item.remarks!)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, AttendanceReportRow item) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.studentName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${item.className ?? '-'} · Roll ${item.rollNumber ?? '-'}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475467),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('Present ${item.present}')),
              Chip(label: Text('Absent ${item.absent}')),
              Chip(label: Text('Late ${item.late}')),
              Chip(label: Text('Excused ${item.excused}')),
              Chip(label: Text('Total ${item.totalDays}')),
            ],
          ),
        ],
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

String _formatMonth(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  return '${value.year}-$month';
}

String _formatStatus(String? value) {
  final normalized = (value ?? 'not_marked').trim();
  if (normalized == 'not_marked') {
    return 'Not Marked';
  }

  return normalized
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

Color _statusColor(String? value) {
  switch ((value ?? '').trim()) {
    case 'present':
      return const Color(0xFFDCFCE7);
    case 'absent':
      return const Color(0xFFFEE2E2);
    case 'late':
      return const Color(0xFFFEF3C7);
    case 'excused':
      return const Color(0xFFE0F2FE);
    default:
      return const Color(0xFFF2F4F7);
  }
}
