import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/fee_models.dart';
import '../models/student_management_models.dart';
import '../services/laravel_api.dart';
import 'exam_report_screen.dart';

class StudentsGraduatesScreen extends StatefulWidget {
  const StudentsGraduatesScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<StudentsGraduatesScreen> createState() =>
      _StudentsGraduatesScreenState();
}

class _StudentsGraduatesScreenState extends State<StudentsGraduatesScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<AcademicYearOption> _years = const [];
  GraduatesPage? _page;
  int? _selectedYearId;
  bool _loadingMeta = true;
  bool _loadingList = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _error = null;
    });

    try {
      final years = await widget.api.academicYears(widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _years = years;
        _loadingMeta = false;
      });

      await _loadGraduates(page: 1);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMeta = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMeta = false;
        _error = 'Unable to load graduates setup.';
      });
    }
  }

  Future<void> _loadGraduates({int page = 1}) async {
    setState(() {
      _loadingList = true;
      _error = null;
    });

    try {
      final result = await widget.api.graduateStudents(
        token: widget.token,
        page: page,
        search: _searchController.text.trim(),
        academicYearId: _selectedYearId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _page = result;
        _loadingList = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _page = null;
        _loadingList = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _page = null;
        _loadingList = false;
        _error = 'Unable to load graduates.';
      });
    }
  }

  Future<void> _clearFilters() async {
    _searchController.clear();
    setState(() {
      _selectedYearId = null;
    });

    await _loadGraduates(page: 1);
  }

  void _openGradebook(GraduateItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExamReportScreen(
          api: widget.api,
          token: widget.token,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = _page;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Graduates'),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadGraduates(page: 1),
              child: ListView(
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
                        Text('Find graduates',
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Search by student name and filter by graduation year.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            labelText: 'Search graduates',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) => _loadGraduates(page: 1),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          value: _selectedYearId,
                          decoration: const InputDecoration(
                            labelText: 'Graduation Year',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('All Years'),
                            ),
                            ..._years.map(
                              (year) => DropdownMenuItem<int>(
                                value: year.id,
                                child: Text(year.name),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedYearId = value;
                            });
                            _loadGraduates(page: 1);
                          },
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: _loadingList
                                  ? null
                                  : () => _loadGraduates(page: 1),
                              icon: const Icon(Icons.search),
                              label: const Text('Search'),
                            ),
                            OutlinedButton(
                              onPressed: _loadingList ? null : _clearFilters,
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
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
                  const SizedBox(height: 20),
                  if (_loadingList)
                    const Center(child: CircularProgressIndicator())
                  else if (page == null || page.items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        'No graduates found.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Graduates', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            'Showing ${page.from ?? 0} - ${page.to ?? 0} of ${page.total}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...page.items.map(_buildGraduateCard),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: page.hasPreviousPage && !_loadingList
                                ? () =>
                                    _loadGraduates(page: page.currentPage - 1)
                                : null,
                            child: const Text('Prev'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: page.hasNextPage && !_loadingList
                                ? () =>
                                    _loadGraduates(page: page.currentPage + 1)
                                : null,
                            child: const Text('Next'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildGraduateCard(GraduateItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.studentName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2933),
              ),
            ),
            const SizedBox(height: 10),
            _DetailRow(label: 'Year', value: item.academicYearName ?? '—'),
            _DetailRow(label: 'Level', value: item.levelName ?? '—'),
            _DetailRow(label: 'Class', value: item.className ?? '—'),
            _DetailRow(label: 'Phone', value: item.phone ?? '-'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openGradebook(item),
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('Gradebook'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
