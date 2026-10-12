import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _usingOfflineData = false;
  String? _statusMessage;
  String? _error;

  bool get _canPay => widget.session.hasPermission('fees.pay');

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

  bool _showFilters = true;

  InputDecoration _filterDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF344054)),
      prefixIconConstraints: const BoxConstraints(minWidth: 36),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: Color(0xFFD5D8DA)),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
    );
  }

  Widget _buildFilters() {
    final disabled = _loadingList || _loadingClasses;
    final fields = <Widget>[
      DropdownButtonFormField<int>(
        key: ValueKey('year-$_selectedYearId'),
        initialValue: _selectedYearId,
        isExpanded: true,
        decoration:
            _filterDecoration('Academic Year', Icons.calendar_month_outlined),
        items: _years
            .map((year) => DropdownMenuItem(
                  value: year.id,
                  child: Text(year.name, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: disabled
            ? null
            : (value) async {
                setState(() => _selectedYearId = value);
                await _loadInvoices(page: 1);
              },
      ),
      DropdownButtonFormField<int>(
        key: ValueKey('level-$_selectedLevelId'),
        initialValue: _selectedLevelId,
        isExpanded: true,
        decoration: _filterDecoration('Level', Icons.school_outlined),
        items: [
          const DropdownMenuItem<int>(value: null, child: Text('All Levels')),
          ..._levels.map((level) => DropdownMenuItem(
                value: level.id,
                child: Text(level.name, overflow: TextOverflow.ellipsis),
              )),
        ],
        onChanged: disabled ? null : _applyLevel,
      ),
      DropdownButtonFormField<int>(
        key: ValueKey('class-$_selectedClassId'),
        initialValue: _selectedClassId,
        isExpanded: true,
        decoration: _filterDecoration('Class', Icons.groups_outlined),
        items: [
          const DropdownMenuItem<int>(value: null, child: Text('All Classes')),
          ..._classes.map((item) => DropdownMenuItem(
                value: item.id,
                child: Text(item.name, overflow: TextOverflow.ellipsis),
              )),
        ],
        onChanged: disabled
            ? null
            : (value) async {
                setState(() => _selectedClassId = value);
                await _loadInvoices(page: 1);
              },
      ),
      DropdownButtonFormField<String>(
        key: ValueKey('status-$_selectedStatus'),
        initialValue: _selectedStatus,
        isExpanded: true,
        decoration: _filterDecoration('Status', Icons.receipt_long_outlined),
        items: const [
          DropdownMenuItem(value: '', child: Text('All Statuses')),
          DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
          DropdownMenuItem(value: 'partial', child: Text('Partial')),
          DropdownMenuItem(value: 'paid', child: Text('Paid')),
          DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
        ],
        onChanged: disabled
            ? null
            : (value) async {
                setState(() => _selectedStatus = value ?? '');
                await _loadInvoices(page: 1);
              },
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt, color: Color(0xFF101828), size: 24),
              const SizedBox(width: 6),
              const Expanded(
                  child: Text('Filter Invoices',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700))),
              TextButton.icon(
                onPressed: disabled ? null : _clearFilters,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF667085),
                  backgroundColor: const Color(0xFFF7F9FA),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 11),
                ),
                icon: const Icon(Icons.refresh, size: 17),
                label: const Text('Reset Filters'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final singleColumn = constraints.maxWidth < 290 ||
                MediaQuery.textScalerOf(context).scale(14) > 20;
            return Wrap(
              spacing: 10,
              runSpacing: 18,
              children: fields
                  .map((field) => SizedBox(
                        width: singleColumn
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 10) / 2,
                        child: field,
                      ))
                  .toList(),
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Student name or phone number',
              hintStyle:
                  const TextStyle(fontSize: 13, color: Color(0xFF7A808B)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF344054)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Color(0xFFD5D8DA)),
              ),
            ),
            onSubmitted: disabled ? null : (_) => _loadInvoices(page: 1),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: disabled ? null : () => _loadInvoices(page: 1),
                icon: const Icon(Icons.search, size: 21),
                label: const Text('Search Invoices'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF0F766E)),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: disabled ? null : _clearFilters,
                icon: const Icon(Icons.restart_alt, size: 21),
                label: const Text('Clear'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F8FA),
        foregroundColor: const Color(0xFF101828),
        title: const Text('Fee Invoices',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: IconButton.outlined(
              tooltip: _showFilters ? 'Hide filters' : 'Show filters',
              onPressed: () => setState(() => _showFilters = !_showFilters),
              icon: const Icon(Icons.filter_list),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE0E4E7)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: () => _loadInvoices(page: 1),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  children: [
                    if (_showFilters) _buildFilters(),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Color(0xFFB42318))),
                    ],
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 12),
                      _FeeOfflineBanner(
                        message: _statusMessage!,
                        onRetry: _usingOfflineData ? () => _loadMeta() : null,
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (_loadingList)
                      const Center(child: CircularProgressIndicator())
                    else if (page == null || page.items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('No fee invoices found.'),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                              child: Text(
                            'Showing ${page.from ?? 0} - ${page.to ?? 0} of ${page.total}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF344054)),
                          )),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.swap_vert, size: 19),
                                  SizedBox(width: 6),
                                  Text('Latest First',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...page.items.map(_buildInvoiceCard),
                      if (page.hasPreviousPage || page.hasNextPage)
                        Row(children: [
                          Expanded(
                              child: OutlinedButton(
                            onPressed: page.hasPreviousPage
                                ? () =>
                                    _loadInvoices(page: page.currentPage - 1)
                                : null,
                            child: const Text('Prev'),
                          )),
                          const SizedBox(width: 12),
                          Expanded(
                              child: FilledButton(
                            onPressed: page.hasNextPage
                                ? () =>
                                    _loadInvoices(page: page.currentPage + 1)
                                : null,
                            child: const Text('Next'),
                          )),
                        ]),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInvoiceCard(FeeInvoiceListItem invoice) {
    final phone = invoice.student?.phone?.trim();
    final className = invoice.studentAcademicYear?.className?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE8EEF2)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A172B4D),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F7F4),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: Color(0xFF0F766E),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.student?.name ?? 'Unknown student',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF172B4D),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        invoice.invoiceNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF52606D),
                        ),
                      ),
                      if (phone != null && phone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3, bottom: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.call,
                                size: 15,
                                color: Color(0xFF0F766E),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  phone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF52606D),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (className != null && className.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.class_outlined,
                                size: 15,
                                color: Color(0xFF52606D),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Class: $className',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF52606D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _InvoiceStatusBadge(status: invoice.status),
                    if (phone != null && phone.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      IconButton(
                        onPressed: () => _callStudent(phone),
                        tooltip: 'Call $phone',
                        style: IconButton.styleFrom(
                          foregroundColor: const Color(0xFF0F766E),
                          backgroundColor: const Color(0xFFE4F7F4),
                          minimumSize: const Size(48, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon:
                            const Icon(Icons.phone_in_talk_outlined, size: 22),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F8FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _InvoiceMetric(
                      icon: Icons.payments_outlined,
                      label: 'Net Amount',
                      value: _formatMoney(invoice.netAmount),
                    ),
                  ),
                  const _InvoiceMetricDivider(),
                  Expanded(
                    child: _InvoiceMetric(
                      icon: Icons.storage_outlined,
                      label: 'Paid',
                      value: _formatMoney(invoice.paidAmount),
                    ),
                  ),
                  const _InvoiceMetricDivider(),
                  Expanded(
                    child: _InvoiceMetric(
                      icon: Icons.pie_chart_outline,
                      label: 'Balance',
                      value: _formatMoney(invoice.balance),
                      valueColor: invoice.balance > 0
                          ? const Color(0xFFB42332)
                          : const Color(0xFF19734D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InvoiceDetail(
                    icon: Icons.calendar_month_outlined,
                    label: 'Issue Date',
                    value: _formatDate(invoice.issueDate),
                  ),
                ),
                const _InvoiceDetailDivider(),
                Expanded(
                  child: _InvoiceDetail(
                    icon: Icons.event_outlined,
                    label: 'Due Date',
                    value: _formatDate(invoice.dueDate),
                  ),
                ),
                const _InvoiceDetailDivider(),
                Expanded(
                  child: _InvoiceDetail(
                    icon: Icons.description_outlined,
                    label: 'Reference',
                    value: invoice.remarks?.trim().isNotEmpty == true
                        ? invoice.remarks!.trim()
                        : '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE4E9ED)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: _invoiceActionStyle,
                    onPressed:
                        _usingOfflineData ? null : () => _openInvoice(invoice),
                    icon: const Icon(Icons.description_outlined, size: 19),
                    label: const Text('View Invoice'),
                  ),
                ),
                if (_canPay && invoice.balance > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: _invoiceActionStyle.copyWith(
                        foregroundColor:
                            const WidgetStatePropertyAll(Color(0xFF0F766E)),
                        side: const WidgetStatePropertyAll(
                            BorderSide(color: Color(0xFF0F766E))),
                      ),
                      onPressed: _usingOfflineData
                          ? null
                          : () => _openInvoice(invoice, openPayment: true),
                      icon: const Icon(Icons.payments_outlined, size: 19),
                      label: const Text('Receive Payment'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openInvoice(FeeInvoiceListItem invoice, {bool openPayment = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeeInvoiceDetailScreen(
          api: widget.api,
          token: widget.token,
          session: widget.session,
          invoiceId: invoice.id,
          openPaymentComposer: openPayment,
        ),
      ),
    );
  }

  Future<void> _callStudent(String phone) async {
    try {
      final launched = await launchUrl(
        Uri(scheme: 'tel', path: phone),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Unable to open the phone dialer.')),
          );
      }
    } on PlatformException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Unable to open the phone dialer.')),
        );
    }
  }
}

class _InvoiceStatusBadge extends StatelessWidget {
  const _InvoiceStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status.toLowerCase()) {
      'paid' => (
          background: const Color(0xFFE8F6EE),
          foreground: const Color(0xFF19734D)
        ),
      'partial' => (
          background: const Color(0xFFFFF4DB),
          foreground: const Color(0xFF9A6700)
        ),
      'cancelled' => (
          background: const Color(0xFFF0F2F4),
          foreground: const Color(0xFF52606D)
        ),
      _ => (
          background: const Color(0xFFFDEBEC),
          foreground: const Color(0xFFB42332)
        ),
    };
    final label = status.isEmpty
        ? 'Unknown'
        : '${status[0].toUpperCase()}${status.substring(1).toLowerCase()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: colors.foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceMetric extends StatelessWidget {
  const _InvoiceMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF172B4D),
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: const Color(0xFF0F766E)),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF52606D),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InvoiceMetricDivider extends StatelessWidget {
  const _InvoiceMetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFFDDE6EB),
    );
  }
}

class _InvoiceDetail extends StatelessWidget {
  const _InvoiceDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF344054)),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF52606D),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF344054),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InvoiceDetailDivider extends StatelessWidget {
  const _InvoiceDetailDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFFE4E9ED),
    );
  }
}

const _invoiceActionStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(0, 46)),
  shape: WidgetStatePropertyAll(RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  )),
  textStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
  padding: WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 6),
  ),
);

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

String _formatMoney(num value) {
  return '\$ ${value.toStringAsFixed(2)}';
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
