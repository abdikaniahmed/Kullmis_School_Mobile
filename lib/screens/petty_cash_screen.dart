import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/finance_admin_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';

class PettyCashScreen extends StatefulWidget {
  const PettyCashScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<PettyCashScreen> createState() => _PettyCashScreenState();
}

class _PettyCashScreenState extends State<PettyCashScreen> {
  final OfflineCacheStore _cacheStore = const FileOfflineCacheStore();

  PettyCashListPayload? _payload;
  String _statusFilter = '';
  Map<int, List<PettyCashTransactionItem>> _transactionsByBudget = const {};
  bool _loading = true;
  bool _usingOfflineData = false;
  String? _statusMessage;
  String? _error;

  bool get _canCreate => widget.session.hasPermission('petty_cash.create');
  bool get _canEdit => widget.session.hasPermission('petty_cash.edit');
  bool get _canTopUp => widget.session.hasPermission('petty_cash.topup');

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = null;
    });

    try {
      final payload = await widget.api.pettyCashBudgets(
        token: widget.token,
        status: _statusFilter,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _payload = payload;
        _loading = false;
        _usingOfflineData = false;
      });

      await _writeSnapshot();
    } on ApiException catch (error) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced petty cash data.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      final restored = await _restoreSnapshot(
        'Offline mode: showing last synced petty cash data.',
      );
      if (restored) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'Unable to load petty cash budgets.';
      });
    }
  }

  Future<bool> _restoreSnapshot(String fallbackMessage) async {
    final json = await _cacheStore.readCacheDocument(_pettyCashCacheKey);
    if (json == null) {
      return false;
    }

    final snapshot = PettyCashOfflineSnapshot.fromJson(json);

    if (!mounted) {
      return true;
    }

    setState(() {
      _payload = snapshot.payload;
      _statusFilter = snapshot.statusFilter;
      _transactionsByBudget = snapshot.transactionsByBudget;
      _loading = false;
      _usingOfflineData = true;
      _statusMessage = fallbackMessage;
      _error = null;
    });

    return true;
  }

  Future<void> _writeSnapshot() async {
    await _cacheStore.writeCacheDocument(
      _pettyCashCacheKey,
      PettyCashOfflineSnapshot(
        payload: _payload,
        statusFilter: _statusFilter,
        transactionsByBudget: _transactionsByBudget,
      ).toJson(),
    );
  }

  Future<void> _openBudgetEditor({PettyCashBudgetItem? budget}) async {
    if (_usingOfflineData) {
      _showMessage('Petty cash changes are only available while online.');
      return;
    }

    final nameController = TextEditingController(text: budget?.name ?? '');
    final periodStartController = TextEditingController(
      text: budget?.periodStart ?? _today(),
    );
    final periodEndController = TextEditingController(text: budget?.periodEnd ?? '');
    final openingBalanceController = TextEditingController(
      text: budget == null ? '0' : budget.openingBalance.toStringAsFixed(2),
    );
    final notesController = TextEditingController(text: budget?.notes ?? '');
    var status = budget?.status.isNotEmpty == true ? budget!.status : 'active';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            budget == null ? 'Add Petty Cash Budget' : 'Edit Petty Cash Budget',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Budget Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: periodStartController,
                  decoration: const InputDecoration(
                    labelText: 'Period Start',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: periodEndController,
                  decoration: const InputDecoration(
                    labelText: 'Period End (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (budget == null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: openingBalanceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Opening Balance',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<String>(
                      value: 'active',
                      child: Text('Active'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'closed',
                      child: Text('Closed'),
                    ),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      status = value ?? 'active';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      return;
    }

    final payload = <String, dynamic>{
      'name': nameController.text.trim(),
      'period_start': periodStartController.text.trim(),
      'period_end': periodEndController.text.trim().isEmpty
          ? null
          : periodEndController.text.trim(),
      'status': status,
      'notes': notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
    };

    if (budget == null) {
      payload['opening_balance'] =
          double.tryParse(openingBalanceController.text.trim()) ?? 0;
    }

    try {
      if (budget == null) {
        await widget.api.createPettyCashBudget(
          token: widget.token,
          payload: payload,
        );
      } else {
        await widget.api.updatePettyCashBudget(
          token: widget.token,
          budgetId: budget.id,
          payload: payload,
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(budget == null ? 'Budget created.' : 'Budget updated.');
      await _loadBudgets();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to save petty cash budget.');
    }
  }

  Future<void> _deleteBudget(PettyCashBudgetItem budget) async {
    if (_usingOfflineData) {
      _showMessage('Petty cash changes are only available while online.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text('Delete ${budget.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.api.deletePettyCashBudget(
        token: widget.token,
        budgetId: budget.id,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Budget deleted.');
      await _loadBudgets();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to delete petty cash budget.');
    }
  }

  Future<void> _topUpBudget(PettyCashBudgetItem budget) async {
    if (_usingOfflineData) {
      _showMessage('Petty cash changes are only available while online.');
      return;
    }

    final amountController = TextEditingController();
    final dateController = TextEditingController(text: _today());
    final referenceController = TextEditingController();
    final notesController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Top Up ${budget.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Transaction Date',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: referenceController,
                decoration: const InputDecoration(
                  labelText: 'Reference No. (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) {
      return;
    }

    try {
      await widget.api.topUpPettyCashBudget(
        token: widget.token,
        budgetId: budget.id,
        payload: {
          'amount': double.tryParse(amountController.text.trim()) ?? 0,
          'transaction_date': dateController.text.trim(),
          'reference_no': referenceController.text.trim().isEmpty
              ? null
              : referenceController.text.trim(),
          'notes': notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        },
      );

      if (!mounted) {
        return;
      }

      _showMessage('Top up saved.');
      await _loadBudgets();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to top up petty cash budget.');
    }
  }

  Future<void> _showTransactions(PettyCashBudgetItem budget) async {
    try {
      final transactions = await widget.api.pettyCashTransactions(
        token: widget.token,
        budgetId: budget.id,
      );

      _transactionsByBudget = {
        ..._transactionsByBudget,
        budget.id: transactions,
      };
      await _writeSnapshot();

      if (!mounted) {
        return;
      }

      await _showTransactionsDialog(budget, transactions);
    } on ApiException catch (_) {
      final cachedTransactions = _transactionsByBudget[budget.id];
      if (cachedTransactions != null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _usingOfflineData = true;
          _statusMessage =
              'Offline mode: showing cached petty cash transactions.';
        });
        await _showTransactionsDialog(budget, cachedTransactions);
        return;
      }

      _showMessage('Unable to load petty cash transactions.');
    } catch (_) {
      final cachedTransactions = _transactionsByBudget[budget.id];
      if (cachedTransactions != null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _usingOfflineData = true;
          _statusMessage =
              'Offline mode: showing cached petty cash transactions.';
        });
        await _showTransactionsDialog(budget, cachedTransactions);
        return;
      }

      _showMessage('Unable to load petty cash transactions.');
    }
  }

  Future<void> _showTransactionsDialog(
    PettyCashBudgetItem budget,
    List<PettyCashTransactionItem> transactions,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${budget.name} Transactions'),
        content: SizedBox(
          width: 480,
          child: transactions.isEmpty
              ? const Text('No transactions recorded.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => const Divider(height: 20),
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${transaction.type} - ${transaction.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(transaction.transactionDate ?? '-'),
                        if (transaction.referenceNo != null)
                          Text('Ref: ${transaction.referenceNo}'),
                        if (transaction.createdByName != null)
                          Text('By: ${transaction.createdByName}'),
                        if (transaction.notes != null) Text(transaction.notes!),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Petty Cash'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBudgets,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Petty cash budgets',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (_canCreate)
                        FilledButton.icon(
                          onPressed:
                              _usingOfflineData ? null : () => _openBudgetEditor(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _PettyMetric(
                        label: 'Active Balance',
                        value: payload == null
                            ? '0.00'
                            : payload.summary.activeBalance.toStringAsFixed(2),
                      ),
                      _PettyMetric(
                        label: 'Active Budgets',
                        value:
                            payload == null ? '0' : '${payload.summary.activeCount}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status Filter',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem<String>(
                        value: '',
                        child: Text('All Budgets'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'active',
                        child: Text('Active'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'closed',
                        child: Text('Closed'),
                      ),
                    ],
                    onChanged: (value) async {
                      setState(() {
                        _statusFilter = value ?? '';
                      });
                      await _loadBudgets();
                    },
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    _PettyOfflineBanner(
                      message: _statusMessage!,
                      onRetry: _usingOfflineData ? _loadBudgets : null,
                    ),
                  ],
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
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (payload == null || payload.items.isEmpty)
              _PettyEmpty(message: 'No petty cash budgets found.')
            else
              ...payload.items.map(
                (budget) => Padding(
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
                          budget.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2933),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _PettyMetric(
                              label: 'Status',
                              value: budget.status,
                            ),
                            _PettyMetric(
                              label: 'Current',
                              value: budget.currentBalance.toStringAsFixed(2),
                            ),
                            _PettyMetric(
                              label: 'Opening',
                              value: budget.openingBalance.toStringAsFixed(2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Period: ${budget.periodStart ?? '-'} to ${budget.periodEnd ?? '-'}',
                        ),
                        if (budget.notes != null) ...[
                          const SizedBox(height: 6),
                          Text(budget.notes!),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showTransactions(budget),
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('Transactions'),
                            ),
                            if (_canTopUp && budget.status == 'active')
                              OutlinedButton.icon(
                                onPressed:
                                    _usingOfflineData ? null : () => _topUpBudget(budget),
                                icon: const Icon(Icons.add_card_outlined),
                                label: const Text('Top Up'),
                              ),
                            if (_canEdit)
                              OutlinedButton.icon(
                                onPressed: _usingOfflineData
                                    ? null
                                    : () => _openBudgetEditor(budget: budget),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                              ),
                            if (_canEdit)
                              OutlinedButton.icon(
                                onPressed: _usingOfflineData
                                    ? null
                                    : () => _deleteBudget(budget),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PettyOfflineBanner extends StatelessWidget {
  const _PettyOfflineBanner({
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

class _PettyMetric extends StatelessWidget {
  const _PettyMetric({
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _PettyEmpty extends StatelessWidget {
  const _PettyEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

String _today() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

const _pettyCashCacheKey = 'petty_cash_snapshot';
