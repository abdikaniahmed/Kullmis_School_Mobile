import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/fee_models.dart';
import '../models/main_attendance_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import 'fee_invoice_detail_screen.dart';

class FeeInvoicesScreen extends StatefulWidget {
  const FeeInvoicesScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<FeeInvoicesScreen> createState() => _FeeInvoicesScreenState();
}

class _FeeInvoicesScreenState extends State<FeeInvoicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _issueDateController =
      TextEditingController(text: _today());
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();

  List<AcademicYearOption> _years = const [];
  List<MainAttendanceLevel> _levels = const [];
  List<MainAttendanceClass> _classes = const [];
  FeeInvoicePage? _page;
  int? _selectedYearId;
  int? _selectedLevelId;
  int? _selectedClassId;
  String _selectedStatus = '';
  bool _loadingMeta = true;
  bool _loadingClasses = false;
  bool _loadingList = false;
  bool _generating = false;
  bool _usingOfflineData = false;
  String? _statusMessage;
  String? _error;

  bool get _canGenerate => widget.session.hasPermission('fees.generate');
  bool get _canPay => widget.session.hasPermission('fees.pay');

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _issueDateController.dispose();
    _dueDateController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final results = await Future.wait([
        widget.api.academicYears(widget.token),
        widget.api.activeAcademicYear(widget.token),
        widget.api.attendanceLevels(widget.token),
        widget.api.schoolClasses(token: widget.token, includeAll: true),
      ]);

      final years = results[0] as List<AcademicYearOption>;
      final activeYear = results[1] as ActiveAcademicYear;
      final levels = results[2] as List<MainAttendanceLevel>;
      final classes = results[3] as List<MainAttendanceClass>;

      if (!mounted) {
        return;
      }

      setState(() {
        _years = years;
        _levels = levels;
        _classes = classes;
        _selectedYearId = years.any((year) => year.id == activeYear.id)
            ? activeYear.id
            : (years.isNotEmpty ? years.first.id : null);
        _loadingMeta = false;
        _usingOfflineData = false;
      });

      await _loadInvoices(page: 1);
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced fee invoices.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMeta = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced fee invoices.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMeta = false;
        _error = 'Unable to load fee invoice setup.';
      });
    }
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loadingClasses = true;
    });

    try {
      final classes = await widget.api.schoolClasses(
        token: widget.token,
        levelId: _selectedLevelId,
        includeAll: _selectedLevelId == null,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _classes = classes;
        _selectedClassId = classes.any((item) => item.id == _selectedClassId)
            ? _selectedClassId
            : null;
        _loadingClasses = false;
      });
      await _writeSnapshot();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _classes = const [];
        _selectedClassId = null;
        _loadingClasses = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _classes = const [];
        _selectedClassId = null;
        _loadingClasses = false;
        _error = 'Unable to load classes for the selected level.';
      });
    }
  }

  Future<void> _loadInvoices({int page = 1}) async {
    setState(() {
      _loadingList = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final result = await widget.api.feeInvoices(
        token: widget.token,
        page: page,
        status: _selectedStatus,
        search: _searchController.text.trim(),
        academicYearId: _selectedYearId,
        levelId: _selectedLevelId,
        schoolClassId: _selectedClassId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _page = result;
        _loadingList = false;
        _usingOfflineData = false;
      });
      await _writeSnapshot();
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced fee invoices.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _page = null;
        _loadingList = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced fee invoices.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _page = null;
        _loadingList = false;
        _error = 'Unable to load fee invoices.';
      });
    }
  }

  Future<void> _applyLevel(int? value) async {
    setState(() {
      _selectedLevelId = value;
      _selectedClassId = null;
      _classes = const [];
    });

    await _loadClasses();
    await _loadInvoices(page: 1);
  }

  Future<bool> _restoreSnapshot(String fallbackMessage) async {
    final json = await _cacheStore.readCacheDocument(_feeInvoicesCacheKey);
    if (json == null) {
      return false;
    }

    final snapshot = FeeInvoicesOfflineSnapshot.fromJson(json);
    _searchController.text = snapshot.search;

    if (!mounted) {
      return true;
    }

    setState(() {
      _years = snapshot.years;
      _levels = snapshot.levels;
      _classes = snapshot.classes;
      _page = snapshot.page;
      _selectedYearId = snapshot.selectedYearId;
      _selectedLevelId = snapshot.selectedLevelId;
      _selectedClassId = snapshot.selectedClassId;
      _selectedStatus = snapshot.selectedStatus;
      _loadingMeta = false;
      _loadingClasses = false;
      _loadingList = false;
      _usingOfflineData = true;
      _statusMessage = fallbackMessage;
      _error = null;
    });

    return true;
  }

  Future<void> _writeSnapshot() async {
    await _cacheStore.writeCacheDocument(
      _feeInvoicesCacheKey,
      FeeInvoicesOfflineSnapshot(
        years: _years,
        levels: _levels,
        classes: _classes,
        page: _page,
        selectedYearId: _selectedYearId,
        selectedLevelId: _selectedLevelId,
        selectedClassId: _selectedClassId,
        selectedStatus: _selectedStatus,
        search: _searchController.text.trim(),
      ).toJson(),
    );
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    setState(() {
      _selectedLevelId = null;
      _selectedClassId = null;
      _selectedStatus = '';
    });

    await _loadClasses();
    await _loadInvoices(page: 1);
  }

  Future<void> _generateInvoices() async {
    final yearId = _selectedYearId;
    if (yearId == null) {
      setState(() {
        _error = 'Select an academic year before generating invoices.';
      });
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
        issueDate: _issueDateController.text.trim(),
        dueDate: _dueDateController.text.trim(),
        remarks: _remarksController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fee invoices generated successfully.')),
      );

      await _loadInvoices(page: 1);
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
    final page = _page;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Invoices'),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadInvoices(page: 1),
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
                        Text('Filter invoices', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _selectedYearId,
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
                          onChanged: (value) async {
                            setState(() {
                              _selectedYearId = value;
                            });
                            await _loadInvoices(page: 1);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            labelText: 'Search Student',
                            hintText: 'Type student name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) => _loadInvoices(page: 1),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _selectedLevelId,
                          decoration: const InputDecoration(
                            labelText: 'Level',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('All Levels'),
                            ),
                            ..._levels.map(
                              (level) => DropdownMenuItem<int>(
                                value: level.id,
                                child: Text(level.name),
                              ),
                            ),
                          ],
                          onChanged: _loadingClasses ? null : _applyLevel,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _selectedClassId,
                          decoration: const InputDecoration(
                            labelText: 'Class',
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
                          onChanged: _loadingClasses
                              ? null
                              : (value) async {
                                  setState(() {
                                    _selectedClassId = value;
                                  });
                                  await _loadInvoices(page: 1);
                                },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text('All Statuses'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'unpaid',
                              child: Text('Unpaid'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'partial',
                              child: Text('Partial'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'paid',
                              child: Text('Paid'),
                            ),
                          ],
                          onChanged: (value) async {
                            setState(() {
                              _selectedStatus = value ?? '';
                            });
                            await _loadInvoices(page: 1);
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
                                  : () => _loadInvoices(page: 1),
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
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFB42318),
                            ),
                          ),
                        ],
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 12),
                          _FeeOfflineBanner(
                            message: _statusMessage!,
                            onRetry: _usingOfflineData ? () => _loadMeta() : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_canGenerate) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Generate invoices', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            'Generate invoices for the selected academic year and optional class.',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _issueDateController,
                            decoration: const InputDecoration(
                              labelText: 'Issue Date',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _dueDateController,
                            decoration: const InputDecoration(
                              labelText: 'Due Date',
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
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _generating || _usingOfflineData
                                ? null
                                : _generateInvoices,
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: Text(
                              _generating ? 'Generating...' : 'Generate Invoices',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                        'No fee invoices found.',
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
                      child: Text(
                        'Showing ${page.from ?? 0} - ${page.to ?? 0} of ${page.total}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...page.items.map(_buildInvoiceCard),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: page.hasPreviousPage && !_loadingList
                                ? () => _loadInvoices(page: page.currentPage - 1)
                                : null,
                            child: const Text('Prev'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: page.hasNextPage && !_loadingList
                                ? () => _loadInvoices(page: page.currentPage + 1)
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

  Widget _buildInvoiceCard(FeeInvoiceListItem invoice) {
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
              invoice.invoiceNumber,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2933),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              invoice.student?.name ?? 'Unknown student',
              style: const TextStyle(color: Color(0xFF52606D)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InvoiceBadge(label: 'Status: ${invoice.status}'),
                _InvoiceBadge(label: 'Net: ${_formatMoney(invoice.netAmount)}'),
                _InvoiceBadge(label: 'Paid: ${_formatMoney(invoice.paidAmount)}'),
                _InvoiceBadge(label: 'Balance: ${_formatMoney(invoice.balance)}'),
              ],
            ),
            const SizedBox(height: 12),
            Text('Issue: ${_formatDate(invoice.issueDate)}'),
            Text('Due: ${_formatDate(invoice.dueDate)}'),
            if (invoice.remarks != null) ...[
              const SizedBox(height: 6),
              Text('Reference: ${invoice.remarks}'),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _usingOfflineData
                      ? null
                      : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FeeInvoiceDetailScreen(
                          api: widget.api,
                          token: widget.token,
                          session: widget.session,
                          invoiceId: invoice.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('View'),
                ),
                if (_canPay && invoice.balance > 0)
                  OutlinedButton.icon(
                    onPressed: _usingOfflineData
                        ? null
                        : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FeeInvoiceDetailScreen(
                            api: widget.api,
                            token: widget.token,
                            session: widget.session,
                            invoiceId: invoice.id,
                            openPaymentComposer: true,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Receive Payment'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceBadge extends StatelessWidget {
  const _InvoiceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

class _FeeOfflineBanner extends StatelessWidget {
  const _FeeOfflineBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEAE9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFFB42318)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                onRetry!();
              },
              child: const Text('Retry Online'),
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

String _formatMoney(num value) {
  return value.toStringAsFixed(2);
}

String _formatDate(String? value) {
  if (value == null || value.isEmpty) {
    return '—';
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }

  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day';
}

const _feeInvoicesCacheKey = 'fee_invoices_snapshot';
