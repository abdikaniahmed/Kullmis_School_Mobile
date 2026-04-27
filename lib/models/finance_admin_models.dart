class PaymentMethodAdminItem {
  const PaymentMethodAdminItem({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  final int id;
  final String name;
  final int sortOrder;
  final bool isActive;

  factory PaymentMethodAdminItem.fromJson(Map<String, dynamic> json) {
    return PaymentMethodAdminItem(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      sortOrder: _toInt(json['sort_order']),
      isActive: _toBool(json['is_active']),
    );
  }
}

class ExpenseListPayload {
  const ExpenseListPayload({
    required this.items,
    required this.summary,
  });

  final List<ExpenseItem> items;
  final ExpenseSummary summary;

  factory ExpenseListPayload.fromJson(Map<String, dynamic> json) {
    return ExpenseListPayload(
      items: (json['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ExpenseItem.fromJson)
          .toList(),
      summary: ExpenseSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class ExpenseSummary {
  const ExpenseSummary({
    required this.totalAmount,
    required this.count,
    required this.categories,
  });

  final double totalAmount;
  final int count;
  final List<ExpenseCategorySummary> categories;

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) {
    return ExpenseSummary(
      totalAmount: _toDouble(json['total_amount']),
      count: _toInt(json['count']),
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ExpenseCategorySummary.fromJson)
          .toList(),
    );
  }
}

class ExpenseCategorySummary {
  const ExpenseCategorySummary({
    required this.label,
    required this.amount,
  });

  final String label;
  final double amount;

  factory ExpenseCategorySummary.fromJson(Map<String, dynamic> json) {
    return ExpenseCategorySummary(
      label: '${json['label'] ?? ''}'.trim(),
      amount: _toDouble(json['amount']),
    );
  }
}

class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.expenseDate,
    required this.referenceNo,
    required this.notes,
    required this.recordedByName,
    required this.pettyCashBudget,
  });

  final int id;
  final String title;
  final String? category;
  final double amount;
  final String paymentMethod;
  final String? expenseDate;
  final String? referenceNo;
  final String? notes;
  final String? recordedByName;
  final PettyCashBudgetItem? pettyCashBudget;

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    final recordedBy = json['recorded_by'];
    final pettyCashBudget = json['petty_cash_budget'];

    return ExpenseItem(
      id: _toInt(json['id']),
      title: '${json['title'] ?? ''}'.trim(),
      category: _toNullableString(json['category']),
      amount: _toDouble(json['amount']),
      paymentMethod: '${json['payment_method'] ?? ''}'.trim(),
      expenseDate: _toNullableString(json['expense_date']),
      referenceNo: _toNullableString(json['reference_no']),
      notes: _toNullableString(json['notes']),
      recordedByName: recordedBy is Map<String, dynamic>
          ? _toNullableString(recordedBy['name'])
          : null,
      pettyCashBudget: pettyCashBudget is Map<String, dynamic>
          ? PettyCashBudgetItem.fromJson(pettyCashBudget)
          : null,
    );
  }
}

class PettyCashListPayload {
  const PettyCashListPayload({
    required this.items,
    required this.summary,
  });

  final List<PettyCashBudgetItem> items;
  final PettyCashSummary summary;

  factory PettyCashListPayload.fromJson(Map<String, dynamic> json) {
    return PettyCashListPayload(
      items: (json['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PettyCashBudgetItem.fromJson)
          .toList(),
      summary: PettyCashSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class PettyCashSummary {
  const PettyCashSummary({
    required this.activeBalance,
    required this.activeCount,
  });

  final double activeBalance;
  final int activeCount;

  factory PettyCashSummary.fromJson(Map<String, dynamic> json) {
    return PettyCashSummary(
      activeBalance: _toDouble(json['active_balance']),
      activeCount: _toInt(json['active_count']),
    );
  }
}

class PettyCashBudgetItem {
  const PettyCashBudgetItem({
    required this.id,
    required this.name,
    required this.periodStart,
    required this.periodEnd,
    required this.openingBalance,
    required this.currentBalance,
    required this.status,
    required this.notes,
  });

  final int id;
  final String name;
  final String? periodStart;
  final String? periodEnd;
  final double openingBalance;
  final double currentBalance;
  final String status;
  final String? notes;

  factory PettyCashBudgetItem.fromJson(Map<String, dynamic> json) {
    return PettyCashBudgetItem(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      periodStart: _toNullableString(json['period_start']),
      periodEnd: _toNullableString(json['period_end']),
      openingBalance: _toDouble(json['opening_balance']),
      currentBalance: _toDouble(json['current_balance']),
      status: '${json['status'] ?? ''}'.trim(),
      notes: _toNullableString(json['notes']),
    );
  }
}

class PettyCashTransactionItem {
  const PettyCashTransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.transactionDate,
    required this.referenceNo,
    required this.notes,
    required this.createdByName,
  });

  final int id;
  final String type;
  final double amount;
  final String? transactionDate;
  final String? referenceNo;
  final String? notes;
  final String? createdByName;

  factory PettyCashTransactionItem.fromJson(Map<String, dynamic> json) {
    final createdBy = json['created_by'];

    return PettyCashTransactionItem(
      id: _toInt(json['id']),
      type: '${json['type'] ?? ''}'.trim(),
      amount: _toDouble(json['amount']),
      transactionDate: _toNullableString(json['transaction_date']),
      referenceNo: _toNullableString(json['reference_no']),
      notes: _toNullableString(json['notes']),
      createdByName: createdBy is Map<String, dynamic>
          ? _toNullableString(createdBy['name'])
          : null,
    );
  }
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

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse('$value') ?? 0;
}

bool _toBool(dynamic value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final normalized = '$value'.trim().toLowerCase();
  return normalized == '1' || normalized == 'true';
}

String? _toNullableString(dynamic value) {
  final normalized = '${value ?? ''}'.trim();
  if (normalized.isEmpty) {
    return null;
  }

  return normalized;
}
