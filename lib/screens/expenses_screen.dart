import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/finance_admin_models.dart';
import '../services/laravel_api.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key,
    required this.api,
    required this.token,
    required this.session,
  });

  final LaravelApi api;
  final String token;
  final AuthSession session;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();

  ExpenseListPayload? _payload;
  List<PaymentMethodAdminItem> _paymentMethods = const [];
  List<PettyCashBudgetItem> _pettyCashBudgets = const [];
  bool _loading = true;
  String? _error;

  bool get _canCreate => widget.session.hasPermission('expenses.create');
  bool get _canEdit => widget.session.hasPermission('expenses.edit');
  bool get _canDelete => widget.session.hasPermission('expenses.delete');

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.api.expenses(
          token: widget.token,
          search: _searchController.text.trim(),
          category: _categoryController.text.trim(),
          dateFrom: _dateFromController.text.trim(),
          dateTo: _dateToController.text.trim(),
        ),
        widget.api.paymentMethods(
          token: widget.token,
          includeInactive: false,
        ),
        widget.api.pettyCashBudgets(
          token: widget.token,
          status: 'active',
        ),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _payload = results[0] as ExpenseListPayload;
        _paymentMethods = results[1] as List<PaymentMethodAdminItem>;
        _pettyCashBudgets = (results[2] as PettyCashListPayload).items;
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
        _error = 'Unable to load expenses.';
      });
    }
  }

  Future<void> _openExpenseEditor({ExpenseItem? expense}) async {
    final titleController = TextEditingController(text: expense?.title ?? '');
    final categoryController =
        TextEditingController(text: expense?.category ?? '');
    final amountController = TextEditingController(
      text: expense == null ? '' : expense.amount.toStringAsFixed(2),
    );
    final dateController = TextEditingController(
      text: expense?.expenseDate ?? _today(),
    );
    final referenceController =
        TextEditingController(text: expense?.referenceNo ?? '');
    final notesController = TextEditingController(text: expense?.notes ?? '');
    String? paymentMethod = expense?.paymentMethod.isNotEmpty == true
        ? expense!.paymentMethod
        : (_paymentMethods.isNotEmpty ? _paymentMethods.first.name : null);
    int? budgetId = expense?.pettyCashBudget?.id;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(expense == null ? 'Add Expense' : 'Edit Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
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
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(),
                  ),
                  items: _paymentMethods
                      .map(
                        (method) => DropdownMenuItem<String>(
                          value: method.name,
                          child: Text(method.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      paymentMethod = value;
                      if ((value ?? '').toLowerCase() != 'petty cash') {
                        budgetId = null;
                      }
                    });
                  },
                ),
                if ((paymentMethod ?? '').toLowerCase() == 'petty cash') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: budgetId,
                    decoration: const InputDecoration(
                      labelText: 'Petty Cash Budget',
                      border: OutlineInputBorder(),
                    ),
                    items: _pettyCashBudgets
                        .map(
                          (budget) => DropdownMenuItem<int>(
                            value: budget.id,
                            child: Text(
                              '${budget.name} (${budget.currentBalance.toStringAsFixed(2)})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        budgetId = value;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: 'Expense Date',
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
      ),
    );

    if (saved != true) {
      return;
    }

    final payload = <String, dynamic>{
      'title': titleController.text.trim(),
      'category': categoryController.text.trim().isEmpty
          ? null
          : categoryController.text.trim(),
      'amount': double.tryParse(amountController.text.trim()) ?? 0,
      'payment_method': paymentMethod,
      'petty_cash_budget_id': (paymentMethod ?? '').toLowerCase() == 'petty cash'
          ? budgetId
          : null,
      'expense_date': dateController.text.trim(),
      'reference_no': referenceController.text.trim().isEmpty
          ? null
          : referenceController.text.trim(),
      'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
    };

    try {
      if (expense == null) {
        await widget.api.createExpense(
          token: widget.token,
          payload: payload,
        );
      } else {
        await widget.api.updateExpense(
          token: widget.token,
          expenseId: expense.id,
          payload: payload,
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(expense == null ? 'Expense created.' : 'Expense updated.');
      await _loadExpenses();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to save expense.');
    }
  }

  Future<void> _deleteExpense(ExpenseItem expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete ${expense.title}?'),
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
      await widget.api.deleteExpense(
        token: widget.token,
        expenseId: expense.id,
      );

      if (!mounted) {
        return;
      }

      _showMessage('Expense deleted.');
      await _loadExpenses();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Unable to delete expense.');
    }
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
        title: const Text('Expenses'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadExpenses,
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
                          'Expenses',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (_canCreate)
                        FilledButton.icon(
                          onPressed: () => _openExpenseEditor(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      hintText: 'Title or notes',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _loadExpenses(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dateFromController,
                    decoration: const InputDecoration(
                      labelText: 'Date From',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dateToController,
                    decoration: const InputDecoration(
                      labelText: 'Date To',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _loadExpenses,
                        icon: const Icon(Icons.search),
                        label: const Text('Apply Filters'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          _searchController.clear();
                          _categoryController.clear();
                          _dateFromController.clear();
                          _dateToController.clear();
                          await _loadExpenses();
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  if (payload != null) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _ExpenseBadge(
                          label: 'Total',
                          value: payload.summary.totalAmount.toStringAsFixed(2),
                        ),
                        _ExpenseBadge(
                          label: 'Count',
                          value: '${payload.summary.count}',
                        ),
                      ],
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
              _ExpenseEmpty(message: 'No expenses found.')
            else ...[
              if (payload.summary.categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: payload.summary.categories
                          .map(
                            (category) => _ExpenseBadge(
                              label: category.label,
                              value: category.amount.toStringAsFixed(2),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ...payload.items.map(
                (expense) => Padding(
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
                          expense.title,
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
                            _ExpenseBadge(
                              label: 'Amount',
                              value: expense.amount.toStringAsFixed(2),
                            ),
                            _ExpenseBadge(
                              label: 'Method',
                              value: expense.paymentMethod,
                            ),
                            if (expense.category != null)
                              _ExpenseBadge(
                                label: 'Category',
                                value: expense.category!,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('Date: ${expense.expenseDate ?? '-'}'),
                        if (expense.pettyCashBudget != null)
                          Text('Petty Cash: ${expense.pettyCashBudget!.name}'),
                        if (expense.referenceNo != null)
                          Text('Reference: ${expense.referenceNo}'),
                        if (expense.recordedByName != null)
                          Text('Recorded By: ${expense.recordedByName}'),
                        if (expense.notes != null) ...[
                          const SizedBox(height: 6),
                          Text(expense.notes!),
                        ],
                        if (_canEdit || _canDelete) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              if (_canEdit)
                                OutlinedButton.icon(
                                  onPressed: () => _openExpenseEditor(expense: expense),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit'),
                                ),
                              if (_canDelete)
                                OutlinedButton.icon(
                                  onPressed: () => _deleteExpense(expense),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Delete'),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpenseBadge extends StatelessWidget {
  const _ExpenseBadge({
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

class _ExpenseEmpty extends StatelessWidget {
  const _ExpenseEmpty({required this.message});

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
