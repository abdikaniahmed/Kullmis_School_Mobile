import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/fee_models.dart';
import '../models/main_attendance_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import 'fee_invoice_detail_screen.dart';

class FeePaymentsScreen extends StatefulWidget {
  const FeePaymentsScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<FeePaymentsScreen> createState() => _FeePaymentsScreenState();
}

class _FeePaymentsScreenState extends State<FeePaymentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _paymentDateController =
      TextEditingController(text: _today());
  final TextEditingController _referenceController = TextEditingController();
  final Map<int, TextEditingController> _amountControllers = {};
  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();

  List<AcademicYearOption> _years = const [];
  List<MainAttendanceLevel> _levels = const [];
  List<MainAttendanceClass> _classes = const [];
  List<FeePaymentMethod> _methods = const [];
  FeeInvoicePage? _page;
  int? _selectedYearId;
  int? _selectedLevelId;
  int? _selectedClassId;
  String _selectedStatus = '';
  String? _selectedMethod;
  bool _loadingMeta = true;
  bool _loadingClasses = false;
  bool _loadingList = false;
  int? _submittingInvoiceId;
  bool _usingOfflineData = false;
  String? _statusMessage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _paymentDateController.dispose();
    _referenceController.dispose();
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
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
        widget.api.feePaymentMethods(token: widget.token),
      ]);

      final years = results[0] as List<AcademicYearOption>;
      final activeYear = results[1] as ActiveAcademicYear;
      final levels = results[2] as List<MainAttendanceLevel>;
      final classes = results[3] as List<MainAttendanceClass>;
      final methods = results[4] as List<FeePaymentMethod>;

      if (!mounted) {
        return;
      }

      setState(() {
        _years = years;
        _levels = levels;
        _classes = classes;
        _methods = methods;
        _selectedMethod = methods.isNotEmpty ? methods.first.name : null;
        _selectedYearId = years.any((year) => year.id == activeYear.id)
            ? activeYear.id
            : (years.isNotEmpty ? years.first.id : null);
        _loadingMeta = false;
        _usingOfflineData = false;
      });

      await _loadInvoices(page: 1);
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced outstanding invoices.',
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
        'Offline mode: showing last synced outstanding invoices.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMeta = false;
        _error = 'Unable to load fee payment setup.';
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
        hasBalance: true,
      );

      if (!mounted) {
        return;
      }

      _syncAmountControllers(result.items);

      setState(() {
        _page = result;
        _loadingList = false;
        _usingOfflineData = false;
      });
      await _writeSnapshot();
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced outstanding invoices.',
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
        'Offline mode: showing last synced outstanding invoices.',
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
        _error = 'Unable to load outstanding invoices.';
      });
    }
  }

  void _syncAmountControllers(List<FeeInvoiceListItem> items) {
    final visibleIds = items.map((entry) => entry.id).toSet();

    final staleIds = _amountControllers.keys
        .where((id) => !visibleIds.contains(id))
        .toList(growable: false);

    for (final id in staleIds) {
      _amountControllers.remove(id)?.dispose();
    }

    for (final invoice in items) {
      final controller = _amountControllers[invoice.id];
      if (controller == null) {
        _amountControllers[invoice.id] = TextEditingController(
          text: invoice.balance.toStringAsFixed(2),
        );
        continue;
      }

      final amount = double.tryParse(controller.text.trim());
      if (amount == null || amount > invoice.balance || amount <= 0) {
        controller.text = invoice.balance.toStringAsFixed(2);
      }
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

  Future<bool> _restoreSnapshot(String fallbackMessage) async {
    final json = await _cacheStore.readCacheDocument(_feePaymentsCacheKey);
    if (json == null) {
      return false;
    }

    final snapshot = FeePaymentsOfflineSnapshot.fromJson(json);
    _searchController.text = snapshot.search;
    _paymentDateController.text =
        snapshot.paymentDate.isEmpty ? _today() : snapshot.paymentDate;
    _referenceController.text = snapshot.reference;

    if (!mounted) {
      return true;
    }

    _syncAmountControllers(snapshot.page?.items ?? const []);

    setState(() {
      _years = snapshot.years;
      _levels = snapshot.levels;
      _classes = snapshot.classes;
      _methods = snapshot.methods;
      _page = snapshot.page;
      _selectedYearId = snapshot.selectedYearId;
      _selectedLevelId = snapshot.selectedLevelId;
      _selectedClassId = snapshot.selectedClassId;
      _selectedStatus = snapshot.selectedStatus;
      _selectedMethod = snapshot.selectedMethod ??
          (snapshot.methods.isNotEmpty ? snapshot.methods.first.name : null);
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
      _feePaymentsCacheKey,
      FeePaymentsOfflineSnapshot(
        years: _years,
        levels: _levels,
        classes: _classes,
        methods: _methods,
        page: _page,
        selectedYearId: _selectedYearId,
        selectedLevelId: _selectedLevelId,
        selectedClassId: _selectedClassId,
        selectedStatus: _selectedStatus,
        selectedMethod: _selectedMethod,
        search: _searchController.text.trim(),
        paymentDate: _paymentDateController.text.trim(),
        reference: _referenceController.text.trim(),
      ).toJson(),
    );
  }

  Future<void> _submitPayment(FeeInvoiceListItem invoice) async {
    final controller = _amountControllers[invoice.id];
    final amount = double.tryParse(controller?.text.trim() ?? '');
    final method = _selectedMethod;

    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'Enter a valid payment amount.';
      });
      return;
    }

    if (amount > invoice.balance) {
      setState(() {
        _error = 'Payment amount cannot exceed the invoice balance.';
      });
      return;
    }

    if (method == null || method.isEmpty) {
      setState(() {
        _error = 'Select a payment method before receiving payment.';
      });
      return;
    }

    if (_paymentDateController.text.trim().isEmpty) {
      setState(() {
        _error = 'Payment date is required.';
      });
      return;
    }

    setState(() {
      _submittingInvoiceId = invoice.id;
      _error = null;
    });

    try {
      await widget.api.createFeePayment(
        token: widget.token,
        feeInvoiceId: invoice.id,
        amount: amount,
        paymentMethod: method,
        paymentDate: _paymentDateController.text.trim(),
        referenceNumber: _referenceController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment received for ${invoice.invoiceNumber}.')),
      );

      await _loadInvoices(page: _page?.currentPage ?? 1);
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
        _error = 'Unable to receive payment.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submittingInvoiceId = null;
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
        title: const Text('Fee Payments'),
      ),
      body: _loadingMeta
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadInvoices(page: _page?.currentPage ?? 1),
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
                        Text('Filter outstanding invoices',
                            style: theme.textTheme.titleLarge),
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
                              child: Text('All Outstanding'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'unpaid',
                              child: Text('Unpaid'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'partial',
                              child: Text('Partial'),
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
                        Text('Receive payment', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                            border: OutlineInputBorder(),
                          ),
                          items: _methods
                              .map(
                                (method) => DropdownMenuItem<String>(
                                  value: method.name,
                                  child: Text(method.name),
                                ),
                              )
                              .toList(),
                          onChanged: _submittingInvoiceId != null
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedMethod = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _paymentDateController,
                          decoration: const InputDecoration(
                            labelText: 'Payment Date',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _referenceController,
                          decoration: const InputDecoration(
                            labelText: 'Reference No. (Optional)',
                            border: OutlineInputBorder(),
                          ),
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
                              icon: const Icon(Icons.refresh),
                              label: const Text('Load Outstanding'),
                            ),
                            OutlinedButton(
                              onPressed: _loadingList ? null : _clearFilters,
                              child: const Text('Clear Filters'),
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
                          _FeePaymentsOfflineBanner(
                            message: _statusMessage!,
                            onRetry: _usingOfflineData ? () => _loadMeta() : null,
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
                        'No outstanding invoices found.',
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
                    ...page.items.map(_buildPaymentCard),
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

  Widget _buildPaymentCard(FeeInvoiceListItem invoice) {
    final controller = _amountControllers[invoice.id] ??
        TextEditingController(text: invoice.balance.toStringAsFixed(2));
    _amountControllers.putIfAbsent(invoice.id, () => controller);
    final isSubmitting = _submittingInvoiceId == invoice.id;

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
            Text('Balance: ${_formatMoney(invoice.balance)}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount to Receive',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: isSubmitting || _usingOfflineData
                      ? null
                      : () => _submitPayment(invoice),
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(isSubmitting ? 'Saving...' : 'Receive'),
                ),
                OutlinedButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          controller.text = invoice.balance.toStringAsFixed(2);
                        },
                  child: const Text('Full Amount'),
                ),
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
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('View Invoice'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeePaymentsOfflineBanner extends StatelessWidget {
  const _FeePaymentsOfflineBanner({
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

const _feePaymentsCacheKey = 'fee_payments_snapshot';
