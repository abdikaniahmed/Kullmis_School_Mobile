import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/fee_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';

class FeeInvoiceDetailScreen extends StatefulWidget {
  const FeeInvoiceDetailScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
    required this.invoiceId,
    this.openPaymentComposer = false,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;
  final int invoiceId;
  final bool openPaymentComposer;

  @override
  State<FeeInvoiceDetailScreen> createState() => _FeeInvoiceDetailScreenState();
}

class _FeeInvoiceDetailScreenState extends State<FeeInvoiceDetailScreen> {
  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();

  FeeInvoiceDetail? _invoice;
  bool _loading = true;
  bool _usingOfflineData = false;
  String? _statusMessage;
  String? _error;
  bool _openedComposer = false;

  bool get _canPay => widget.session.hasPermission('fees.pay');

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final invoice = await widget.api.feeInvoiceDetail(
        token: widget.token,
        invoiceId: widget.invoiceId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _invoice = invoice;
        _loading = false;
        _usingOfflineData = false;
      });

      await _cacheStore.writeCacheDocument(
        _invoiceCacheKey(widget.invoiceId),
        FeeInvoiceDetailOfflineSnapshot(invoice: invoice).toJson(),
      );

      if (widget.openPaymentComposer &&
          !_openedComposer &&
          _canPay &&
          !_usingOfflineData) {
        _openedComposer = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openPaymentComposer();
        });
      }
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced invoice detail.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _invoice = null;
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced invoice detail.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _invoice = null;
        _loading = false;
        _error = 'Unable to load the invoice.';
      });
    }
  }

  Future<bool> _restoreSnapshot(String fallbackMessage) async {
    final json = await _cacheStore.readCacheDocument(
      _invoiceCacheKey(widget.invoiceId),
    );
    if (json == null) {
      return false;
    }

    final snapshot = FeeInvoiceDetailOfflineSnapshot.fromJson(json);

    if (!mounted) {
      return true;
    }

    setState(() {
      _invoice = snapshot.invoice;
      _loading = false;
      _usingOfflineData = true;
      _statusMessage = fallbackMessage;
      _error = null;
    });

    return true;
  }

  Future<void> _openPaymentComposer() async {
    final invoice = _invoice;
    if (invoice == null || invoice.balance <= 0 || _usingOfflineData) {
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReceiveFeePaymentSheet(
        api: widget.api,
        token: widget.token,
        invoice: invoice,
      ),
    );

    if (created == true && mounted) {
      await _loadInvoice();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invoice = _invoice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Invoice'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : invoice == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error ?? 'Invoice not found.'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInvoice,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0F766E),
                              Color(0xFF115E59),
                              Color(0xFF134E4A),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoice.invoiceNumber,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              invoice.student?.name ?? 'Unknown student',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _InfoChip(
                                  label: 'Status',
                                  value: invoice.status,
                                ),
                                _InfoChip(
                                  label: 'Balance',
                                  value: _formatMoney(invoice.balance),
                                ),
                                _InfoChip(
                                  label: 'Paid',
                                  value: _formatMoney(invoice.paidAmount),
                                ),
                              ],
                            ),
                            if (_statusMessage != null) ...[
                              const SizedBox(height: 14),
                              _InvoiceOfflineBanner(
                                message: _statusMessage!,
                                onRetry: _usingOfflineData ? _loadInvoice : null,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Summary', style: theme.textTheme.titleLarge),
                            const SizedBox(height: 12),
                            _DetailLine(
                              label: 'Issue date',
                              value: _formatDate(invoice.issueDate),
                            ),
                            _DetailLine(
                              label: 'Due date',
                              value: _formatDate(invoice.dueDate),
                            ),
                            _DetailLine(
                              label: 'Roll number',
                              value: invoice.studentAcademicYear?.rollNumber ??
                                  '—',
                            ),
                            _DetailLine(
                              label: 'Level',
                              value:
                                  invoice.studentAcademicYear?.levelName ?? '—',
                            ),
                            _DetailLine(
                              label: 'Class',
                              value:
                                  invoice.studentAcademicYear?.className ?? '—',
                            ),
                            _DetailLine(
                              label: 'Total',
                              value: _formatMoney(invoice.totalAmount),
                            ),
                            _DetailLine(
                              label: 'Discount',
                              value: _formatMoney(invoice.discountAmount),
                            ),
                            _DetailLine(
                              label: 'Net amount',
                              value: _formatMoney(invoice.netAmount),
                            ),
                            if (invoice.remarks != null)
                              _DetailLine(
                                label: 'Reference',
                                value: invoice.remarks!,
                              ),
                            if (_canPay && invoice.balance > 0) ...[
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed:
                                    _usingOfflineData ? null : _openPaymentComposer,
                                icon: const Icon(Icons.payments_outlined),
                                label: const Text('Receive Payment'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Invoice Items',
                                style: theme.textTheme.titleLarge),
                            const SizedBox(height: 12),
                            if (invoice.items.isEmpty)
                              Text(
                                'No invoice items found.',
                                style: theme.textTheme.bodyLarge,
                              )
                            else
                              ...invoice.items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(item.description)),
                                      Text(_formatMoney(item.amount)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Payments', style: theme.textTheme.titleLarge),
                            const SizedBox(height: 12),
                            if (invoice.payments.isEmpty)
                              Text(
                                'No payments recorded yet.',
                                style: theme.textTheme.bodyLarge,
                              )
                            else
                              ...invoice.payments.map(_buildPaymentCard),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPaymentCard(FeePaymentRecord payment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatMoney(payment.amount),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _DetailLine(label: 'Date', value: _formatDate(payment.paymentDate)),
            _DetailLine(label: 'Method', value: payment.paymentMethod),
            _DetailLine(
              label: 'Received by',
              value: payment.receivedByName ?? '—',
            ),
            if (payment.referenceNumber != null)
              _DetailLine(label: 'Reference', value: payment.referenceNumber!),
          ],
        ),
      ),
    );
  }
}

class _InvoiceOfflineBanner extends StatelessWidget {
  const _InvoiceOfflineBanner({
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

class _ReceiveFeePaymentSheet extends StatefulWidget {
  const _ReceiveFeePaymentSheet({
    required this.api,
    required this.token,
    required this.invoice,
  });

  final LaravelApi api;
  final String token;
  final FeeInvoiceDetail invoice;

  @override
  State<_ReceiveFeePaymentSheet> createState() =>
      _ReceiveFeePaymentSheetState();
}

class _ReceiveFeePaymentSheetState extends State<_ReceiveFeePaymentSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _dateController;
  late final TextEditingController _referenceController;
  List<FeePaymentMethod> _methods = const [];
  String? _selectedMethod;
  bool _loadingMethods = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.invoice.balance.toStringAsFixed(2),
    );
    _dateController = TextEditingController(text: _today());
    _referenceController = TextEditingController();
    _loadMethods();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _loadMethods() async {
    try {
      final methods = await widget.api.feePaymentMethods(token: widget.token);

      if (!mounted) {
        return;
      }

      setState(() {
        _methods = methods;
        _selectedMethod = methods.isNotEmpty ? methods.first.name : null;
        _loadingMethods = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMethods = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMethods = false;
        _error = 'Unable to load payment methods.';
      });
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() {
        _error = 'Enter a valid payment amount.';
      });
      return;
    }

    if (amount > widget.invoice.balance) {
      setState(() {
        _error = 'Payment amount cannot exceed the invoice balance.';
      });
      return;
    }

    final method = _selectedMethod;
    if (method == null || method.isEmpty) {
      setState(() {
        _error = 'Select a payment method.';
      });
      return;
    }

    if (_dateController.text.trim().isEmpty) {
      setState(() {
        _error = 'Payment date is required.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.api.createFeePayment(
        token: widget.token,
        feeInvoiceId: widget.invoice.id,
        amount: amount,
        paymentMethod: method,
        paymentDate: _dateController.text.trim(),
        referenceNumber: _referenceController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
        _error = 'Unable to record the payment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Receive Payment',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text('Outstanding balance: ${_formatMoney(widget.invoice.balance)}'),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingMethods)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else
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
              onChanged: _submitting
                  ? null
                  : (value) {
                      setState(() {
                        _selectedMethod = value;
                      });
                    },
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _dateController,
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFB42318)),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () {
                          Navigator.of(context).pop(false);
                        },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting || _loadingMethods ? null : _submit,
                  child: Text(_submitting ? 'Saving...' : 'Save Payment'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2933),
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Color(0xFF52606D)),
            ),
          ],
        ),
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

String _invoiceCacheKey(int invoiceId) => 'fee_invoice_detail_$invoiceId';
