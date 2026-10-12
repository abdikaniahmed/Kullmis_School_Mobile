import 'package:flutter/material.dart';

import '../models/fee_models.dart';
import '../models/main_attendance_models.dart';
import '../services/laravel_api.dart';

class GenerateFeeInvoicesScreen extends StatefulWidget {
  const GenerateFeeInvoicesScreen({
    super.key,
    required this.api,
    required this.token,
  });

  final LaravelApi api;
  final String token;

  @override
  State<GenerateFeeInvoicesScreen> createState() =>
      _GenerateFeeInvoicesScreenState();
}

class _GenerateFeeInvoicesScreenState extends State<GenerateFeeInvoicesScreen> {
  final TextEditingController _issueDateController =
      TextEditingController(text: _today());
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  List<AcademicYearOption> _years = const [];
  List<MainAttendanceClass> _classes = const [];
  int? _selectedYearId;
  int? _selectedClassId;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _issueDateController.dispose();
    _dueDateController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.academicYears(widget.token),
        widget.api.activeAcademicYear(widget.token),
        widget.api.schoolClasses(token: widget.token, includeAll: true),
      ]);
      final years = results[0] as List<AcademicYearOption>;
      final activeYear = results[1] as ActiveAcademicYear;
      final classes = results[2] as List<MainAttendanceClass>;

      if (!mounted) {
        return;
      }

      setState(() {
        _years = years;
        _classes = classes;
        _selectedYearId = years.any((year) => year.id == activeYear.id)
            ? activeYear.id
            : (years.isNotEmpty ? years.first.id : null);
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
        _error = 'Unable to load invoice generation options.';
      });
    }
  }

  Future<void> _generateInvoices() async {
    final yearId = _selectedYearId;
    final issueDate = _issueDateController.text.trim();
    final dueDate = _dueDateController.text.trim();
    if (yearId == null) {
      setState(() {
        _error = 'Select an academic year before generating invoices.';
      });
      return;
    }
    if (DateTime.tryParse(issueDate) == null ||
        (dueDate.isNotEmpty && DateTime.tryParse(dueDate) == null)) {
      setState(() {
        _error = 'Enter valid issue and due dates in YYYY-MM-DD format.';
      });
      return;
    }

    final selectedYear = _years.firstWhere((year) => year.id == yearId);
    final selectedClass = _selectedClassId == null
        ? null
        : _classes.firstWhere((item) => item.id == _selectedClassId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm invoice generation'),
        content: Text(
          'Generate fee invoices for ${selectedYear.name} '
          '(${selectedClass?.name ?? 'all classes'})? This action will create '
          'invoices for eligible students.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Generate Invoices'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      await widget.api.generateFeeInvoices(
        token: widget.token,
        academicYearId: yearId,
        schoolClassId: _selectedClassId,
        issueDate: issueDate,
        dueDate: dueDate,
        remarks: _remarksController.text.trim(),
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fee invoices generated successfully.')),
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
        _error = 'Unable to generate fee invoices.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Generate Invoices')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                      Text(
                        'Generate fee invoices',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This is a separate task from reviewing daily fee '
                        'invoices. Review the year and class carefully; '
                        'you will be asked to confirm before invoices are created.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedYearId,
                        decoration: const InputDecoration(
                          labelText: 'Academic Year',
                          border: OutlineInputBorder(),
                        ),
                        items: _years
                            .map(
                              (year) => DropdownMenuItem<int>(
                                value: year.id,
                                child: Text(year.name),
                              ),
                            )
                            .toList(),
                        onChanged: _generating
                            ? null
                            : (value) =>
                                setState(() => _selectedYearId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedClassId,
                        decoration: const InputDecoration(
                          labelText: 'Class (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('All Classes'),
                          ),
                          ..._classes.map(
                            (schoolClass) => DropdownMenuItem<int>(
                              value: schoolClass.id,
                              child: Text(schoolClass.name),
                            ),
                          ),
                        ],
                        onChanged: _generating
                            ? null
                            : (value) =>
                                setState(() => _selectedClassId = value),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _issueDateController,
                        decoration: const InputDecoration(
                          labelText: 'Issue Date',
                          hintText: 'YYYY-MM-DD',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _dueDateController,
                        decoration: const InputDecoration(
                          labelText: 'Due Date',
                          hintText: 'YYYY-MM-DD',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _remarksController,
                        decoration: const InputDecoration(
                          labelText: 'Reference',
                          hintText: 'Fee April 2026',
                          border: OutlineInputBorder(),
                        ),
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
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _generating ? null : _generateInvoices,
                        icon: _generating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.receipt_long_outlined),
                        label: Text(
                          _generating ? 'Generating...' : 'Generate Invoices',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

String _today() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}
