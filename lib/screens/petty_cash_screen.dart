import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/finance_admin_models.dart';
import '../services/laravel_api.dart';
import '../services/offline_cache_store.dart';
import '../services/offline_sync_queue.dart';

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
  final OfflineSyncQueue _syncQueue = const OfflineSyncQueue();

  PettyCashListPayload? _payload;
  String _statusFilter = '';
  Map<int, List<PettyCashTransactionItem>> _transactionsByBudget = const {};
  List<int> _pendingBudgetIds = const [];
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

      final pendingState = await _loadPendingPettyCashQueueState();

      setState(() {
        _payload = _applyPendingPettyCashQueueState(payload, pendingState);
        _pendingBudgetIds = pendingState.pendingIds;
        _loading = false;
        _usingOfflineData = false;
        _statusMessage = pendingState.pendingIds.isEmpty
            ? null
            : 'Some petty cash changes are still queued for sync.';
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
    final pendingState = await _loadPendingPettyCashQueueState();

    if (!mounted) {
      return true;
    }

    setState(() {
      _payload = snapshot.payload == null
          ? null
          : _applyPendingPettyCashQueueState(snapshot.payload!, pendingState);
      _statusFilter = snapshot.statusFilter;
      _transactionsByBudget = snapshot.transactionsByBudget;
      _pendingBudgetIds = pendingState.pendingIds;
      _loading = false;
      _usingOfflineData = true;
      _statusMessage = pendingState.pendingIds.isEmpty
          ? fallbackMessage
          : 'Offline mode: showing cached petty cash with queued local changes.';
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
    } on ApiException catch (_) {
      await _queueOfflineBudgetSave(
        originalBudget: budget,
        payload: payload,
      );
    } catch (_) {
      await _queueOfflineBudgetSave(
        originalBudget: budget,
        payload: payload,
      );
    }
  }

  Future<void> _deleteBudget(PettyCashBudgetItem budget) async {
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
    } on ApiException catch (_) {
      await _queueOfflineBudgetDelete(budget);
    } catch (_) {
      await _queueOfflineBudgetDelete(budget);
    }
  }

  Future<void> _topUpBudget(PettyCashBudgetItem budget) async {
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

    final payload = {
      'amount': double.tryParse(amountController.text.trim()) ?? 0,
      'transaction_date': dateController.text.trim(),
      'reference_no': referenceController.text.trim().isEmpty
          ? null
          : referenceController.text.trim(),
      'notes': notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
    };

    try {
      await widget.api.topUpPettyCashBudget(
        token: widget.token,
        budgetId: budget.id,
        payload: payload,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Top up saved.');
      await _loadBudgets();
    } on ApiException catch (_) {
      await _queueOfflineTopUp(budget, payload);
    } catch (_) {
      await _queueOfflineTopUp(budget, payload);
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

  Future<_PendingPettyCashQueueState> _loadPendingPettyCashQueueState() async {
    final queued = await _syncQueue.readQueue();
    final createdBudgets = <PettyCashBudgetItem>[];
    final updatedBudgets = <PettyCashBudgetItem>[];
    final deletedIds = <int>[];
    final topUps = <int, List<PettyCashTransactionItem>>{};

    for (final item in queued) {
      if (item.key.startsWith(pettyCashCreateQueuePrefix)) {
        final json = item.payload['budget'];
        if (json is Map<String, dynamic>) {
          createdBudgets.add(PettyCashBudgetItem.fromJson(json));
        }
      } else if (item.key.startsWith(pettyCashUpdateQueuePrefix)) {
        final json = item.payload['budget'];
        if (json is Map<String, dynamic>) {
          updatedBudgets.add(PettyCashBudgetItem.fromJson(json));
        }
      } else if (item.key.startsWith(pettyCashDeleteQueuePrefix)) {
        final id = _toInt(item.payload['budget_id']);
        if (id != 0) {
          deletedIds.add(id);
        }
      } else if (item.key.startsWith(pettyCashTopUpQueuePrefix)) {
        final budgetId = _toInt(item.payload['budget_id']);
        final json = item.payload['transaction'];
        if (budgetId != 0 && json is Map<String, dynamic>) {
          topUps[budgetId] = [...(topUps[budgetId] ?? const []), PettyCashTransactionItem.fromJson(json)];
        }
      }
    }

    return _PendingPettyCashQueueState(
      createdBudgets: createdBudgets,
      updatedBudgets: updatedBudgets,
      deletedIds: deletedIds,
      topUpsByBudget: topUps,
    );
  }

  PettyCashListPayload _applyPendingPettyCashQueueState(
    PettyCashListPayload payload,
    _PendingPettyCashQueueState pendingState,
  ) {
    if (!pendingState.hasPendingWork) {
      return payload;
    }

    final items = payload.items.map((budget) {
      final updated = pendingState.updatedBudgets
          .where((item) => item.id == budget.id)
          .firstOrNull;
      var base = updated ?? budget;
      if (pendingState.deletedIds.contains(base.id)) {
        return null;
      }
      final topUps = pendingState.topUpsByBudget[base.id] ?? const [];
      if (topUps.isNotEmpty) {
        final total = topUps.fold<double>(
          0,
          (sum, item) => sum + item.amount,
        );
        base = PettyCashBudgetItem(
          id: base.id,
          name: base.name,
          periodStart: base.periodStart,
          periodEnd: base.periodEnd,
          openingBalance: base.openingBalance,
          currentBalance: base.currentBalance + total,
          status: base.status,
          notes: base.notes,
        );
      }
      return base;
    }).whereType<PettyCashBudgetItem>().toList();

    for (final item in pendingState.createdBudgets) {
      final index = items.indexWhere((entry) => entry.id == item.id);
      if (index >= 0) {
        items[index] = item;
      } else {
        items.insert(0, item);
      }
    }

    return PettyCashListPayload(
      items: items,
      summary: _buildPettyCashSummary(items),
    );
  }

  PettyCashSummary _buildPettyCashSummary(List<PettyCashBudgetItem> items) {
    final activeItems = items.where((item) => item.status == 'active').toList();
    return PettyCashSummary(
      activeBalance: activeItems.fold<double>(
        0,
        (sum, item) => sum + item.currentBalance,
      ),
      activeCount: activeItems.length,
    );
  }

  Future<void> _queueOfflineBudgetSave({
    required PettyCashBudgetItem? originalBudget,
    required Map<String, dynamic> payload,
  }) async {
    final currentPayload = _payload;
    if (currentPayload == null) {
      _showMessage('Unable to save petty cash budget offline.');
      return;
    }

    final localBudget = _buildLocalBudget(
      originalBudget: originalBudget,
      payload: payload,
    );

    if (originalBudget == null || originalBudget.id < 0) {
      await _syncQueue.upsert(
        OfflineSyncOperation(
          key: '$pettyCashCreateQueuePrefix${localBudget.id}',
          type: 'petty_cash_create',
          payload: {
            'budget': localBudget.toJson(),
            'payload': payload,
          },
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    } else {
      await _syncQueue.upsert(
        OfflineSyncOperation(
          key: '$pettyCashUpdateQueuePrefix${localBudget.id}',
          type: 'petty_cash_update',
          payload: {
            'budget_id': localBudget.id,
            'budget': localBudget.toJson(),
            'payload': payload,
          },
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }

    final pendingState = await _loadPendingPettyCashQueueState();
    final nextItems = [
      for (final item in currentPayload.items)
        if (item.id != localBudget.id) item,
      localBudget,
    ];

    if (!mounted) {
      return;
    }

    setState(() {
      _payload = _applyPendingPettyCashQueueState(
        PettyCashListPayload(
          items: nextItems,
          summary: _buildPettyCashSummary(nextItems),
        ),
        pendingState,
      );
      _pendingBudgetIds = pendingState.pendingIds;
      _usingOfflineData = true;
      _statusMessage = originalBudget == null
          ? 'Petty cash budget saved locally and queued for sync.'
          : 'Petty cash update saved locally and queued for sync.';
      _error = null;
    });

    await _writeSnapshot();
    _showMessage(
      originalBudget == null
          ? 'Petty cash budget created locally for later sync.'
          : 'Petty cash update saved locally for later sync.',
    );
  }

  Future<void> _queueOfflineBudgetDelete(PettyCashBudgetItem budget) async {
    final currentPayload = _payload;
    if (currentPayload == null) {
      _showMessage('Unable to delete petty cash budget offline.');
      return;
    }

    if (budget.id < 0) {
      await _syncQueue.remove('$pettyCashCreateQueuePrefix${budget.id}');
    } else {
      await _syncQueue.upsert(
        OfflineSyncOperation(
          key: '$pettyCashDeleteQueuePrefix${budget.id}',
          type: 'petty_cash_delete',
          payload: {
            'budget_id': budget.id,
          },
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      await _syncQueue.remove('$pettyCashUpdateQueuePrefix${budget.id}');
      await _syncQueue.remove('$pettyCashTopUpQueuePrefix${budget.id}');
    }

    final pendingState = await _loadPendingPettyCashQueueState();
    final nextItems =
        currentPayload.items.where((item) => item.id != budget.id).toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _payload = _applyPendingPettyCashQueueState(
        PettyCashListPayload(
          items: nextItems,
          summary: _buildPettyCashSummary(nextItems),
        ),
        pendingState,
      );
      _pendingBudgetIds = pendingState.pendingIds;
      _usingOfflineData = true;
      _statusMessage =
          'Petty cash budget deletion saved locally and queued for sync.';
      _error = null;
    });

    await _writeSnapshot();
    _showMessage('Petty cash budget deletion saved locally for later sync.');
  }

  Future<void> _queueOfflineTopUp(
    PettyCashBudgetItem budget,
    Map<String, dynamic> payload,
  ) async {
    final currentPayload = _payload;
    if (currentPayload == null) {
      _showMessage('Unable to save petty cash top up offline.');
      return;
    }

    final transaction = PettyCashTransactionItem(
      id: -DateTime.now().millisecondsSinceEpoch,
      type: 'top_up',
      amount: (payload['amount'] as num?)?.toDouble() ?? 0,
      transactionDate: payload['transaction_date'] as String?,
      referenceNo: payload['reference_no'] as String?,
      notes: payload['notes'] as String?,
      createdByName: widget.session.name,
    );

    await _syncQueue.upsert(
      OfflineSyncOperation(
        key: '$pettyCashTopUpQueuePrefix${budget.id}',
        type: 'petty_cash_topup',
        payload: {
          'budget_id': budget.id,
          'transaction': transaction.toJson(),
          'payload': payload,
        },
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

    final pendingState = await _loadPendingPettyCashQueueState();
    final nextItems = currentPayload.items.map((item) {
      if (item.id != budget.id) {
        return item;
      }

      return PettyCashBudgetItem(
        id: item.id,
        name: item.name,
        periodStart: item.periodStart,
        periodEnd: item.periodEnd,
        openingBalance: item.openingBalance,
        currentBalance: item.currentBalance + transaction.amount,
        status: item.status,
        notes: item.notes,
      );
    }).toList();

    final nextTransactions = {
      ..._transactionsByBudget,
      budget.id: [transaction, ...(_transactionsByBudget[budget.id] ?? const [])],
    };

    if (!mounted) {
      return;
    }

    setState(() {
      _transactionsByBudget = nextTransactions;
      _payload = _applyPendingPettyCashQueueState(
        PettyCashListPayload(
          items: nextItems,
          summary: _buildPettyCashSummary(nextItems),
        ),
        pendingState,
      );
      _pendingBudgetIds = pendingState.pendingIds;
      _usingOfflineData = true;
      _statusMessage = 'Petty cash top up saved locally and queued for sync.';
      _error = null;
    });

    await _writeSnapshot();
    _showMessage('Petty cash top up saved locally for later sync.');
  }

  PettyCashBudgetItem _buildLocalBudget({
    required PettyCashBudgetItem? originalBudget,
    required Map<String, dynamic> payload,
  }) {
    final openingBalance = originalBudget?.openingBalance ??
        (payload['opening_balance'] as num?)?.toDouble() ??
        0;
    return PettyCashBudgetItem(
      id: originalBudget?.id ?? -DateTime.now().millisecondsSinceEpoch,
      name: '${payload['name'] ?? ''}'.trim(),
      periodStart: payload['period_start'] as String?,
      periodEnd: payload['period_end'] as String?,
      openingBalance: openingBalance,
      currentBalance: originalBudget?.currentBalance ?? openingBalance,
      status: '${payload['status'] ?? 'active'}'.trim(),
      notes: payload['notes'] as String?,
    );
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
                          onPressed: () => _openBudgetEditor(),
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
                            if (_pendingBudgetIds.contains(budget.id))
                              const _PettyMetric(
                                label: 'Queue',
                                value: 'Pending Sync',
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
                                onPressed: () => _topUpBudget(budget),
                                icon: const Icon(Icons.add_card_outlined),
                                label: const Text('Top Up'),
                              ),
                            if (_canEdit)
                              OutlinedButton.icon(
                                onPressed: () => _openBudgetEditor(budget: budget),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                              ),
                            if (_canEdit)
                              OutlinedButton.icon(
                                onPressed: () => _deleteBudget(budget),
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

class _PendingPettyCashQueueState {
  const _PendingPettyCashQueueState({
    required this.createdBudgets,
    required this.updatedBudgets,
    required this.deletedIds,
    required this.topUpsByBudget,
  });

  final List<PettyCashBudgetItem> createdBudgets;
  final List<PettyCashBudgetItem> updatedBudgets;
  final List<int> deletedIds;
  final Map<int, List<PettyCashTransactionItem>> topUpsByBudget;

  List<int> get pendingIds => {
        ...createdBudgets.map((item) => item.id),
        ...updatedBudgets.map((item) => item.id),
        ...topUpsByBudget.keys,
      }.toList()
        ..sort();

  bool get hasPendingWork =>
      createdBudgets.isNotEmpty ||
      updatedBudgets.isNotEmpty ||
      deletedIds.isNotEmpty ||
      topUpsByBudget.isNotEmpty;
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

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is double) {
    return value.round();
  }

  return int.tryParse('$value') ?? 0;
}

String _today() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

const _pettyCashCacheKey = 'petty_cash_snapshot';
