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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'data': items.map((item) => item.toJson()).toList(),
      'summary': summary.toJson(),
    };
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

  Map<String, dynamic> toJson() {
    return {
      'total_amount': totalAmount,
      'count': count,
      'categories': categories.map((item) => item.toJson()).toList(),
    };
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

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'amount': amount,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'payment_method': paymentMethod,
      'expense_date': expenseDate,
      'reference_no': referenceNo,
      'notes': notes,
      'recorded_by': recordedByName == null ? null : {'name': recordedByName},
      'petty_cash_budget': pettyCashBudget?.toJson(),
    };
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

  Map<String, dynamic> toJson() {
    return {
      'data': items.map((item) => item.toJson()).toList(),
      'summary': summary.toJson(),
    };
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

  Map<String, dynamic> toJson() {
    return {
      'active_balance': activeBalance,
      'active_count': activeCount,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'period_start': periodStart,
      'period_end': periodEnd,
      'opening_balance': openingBalance,
      'current_balance': currentBalance,
      'status': status,
      'notes': notes,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'transaction_date': transactionDate,
      'reference_no': referenceNo,
      'notes': notes,
      'created_by': createdByName == null ? null : {'name': createdByName},
    };
  }
}

class ExpensesOfflineSnapshot {
  const ExpensesOfflineSnapshot({
    required this.payload,
    required this.paymentMethods,
    required this.pettyCashBudgets,
    required this.search,
    required this.category,
    required this.dateFrom,
    required this.dateTo,
  });

  final ExpenseListPayload? payload;
  final List<PaymentMethodAdminItem> paymentMethods;
  final List<PettyCashBudgetItem> pettyCashBudgets;
  final String search;
  final String category;
  final String dateFrom;
  final String dateTo;

  factory ExpensesOfflineSnapshot.fromJson(Map<String, dynamic> json) {
    return ExpensesOfflineSnapshot(
      payload: json['payload'] is Map<String, dynamic>
          ? ExpenseListPayload.fromJson(json['payload'] as Map<String, dynamic>)
          : null,
      paymentMethods: (json['payment_methods'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PaymentMethodAdminItem.fromJson)
          .toList(),
      pettyCashBudgets:
          (json['petty_cash_budgets'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(PettyCashBudgetItem.fromJson)
              .toList(),
      search: '${json['search'] ?? ''}',
      category: '${json['category'] ?? ''}',
      dateFrom: '${json['date_from'] ?? ''}',
      dateTo: '${json['date_to'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payload': payload?.toJson(),
      'payment_methods': paymentMethods.map((item) => item.toJson()).toList(),
      'petty_cash_budgets': pettyCashBudgets.map((item) => item.toJson()).toList(),
      'search': search,
      'category': category,
      'date_from': dateFrom,
      'date_to': dateTo,
    };
  }
}

class PettyCashOfflineSnapshot {
  const PettyCashOfflineSnapshot({
    required this.payload,
    required this.statusFilter,
    required this.transactionsByBudget,
  });

  final PettyCashListPayload? payload;
  final String statusFilter;
  final Map<int, List<PettyCashTransactionItem>> transactionsByBudget;

  factory PettyCashOfflineSnapshot.fromJson(Map<String, dynamic> json) {
    final transactionsJson =
        json['transactions_by_budget'] as Map<String, dynamic>? ?? const {};

    return PettyCashOfflineSnapshot(
      payload: json['payload'] is Map<String, dynamic>
          ? PettyCashListPayload.fromJson(json['payload'] as Map<String, dynamic>)
          : null,
      statusFilter: '${json['status_filter'] ?? ''}',
      transactionsByBudget: {
        for (final entry in transactionsJson.entries)
          _toInt(entry.key): (entry.value as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(PettyCashTransactionItem.fromJson)
              .toList(),
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payload': payload?.toJson(),
      'status_filter': statusFilter,
      'transactions_by_budget': {
        for (final entry in transactionsByBudget.entries)
          '${entry.key}': entry.value.map((item) => item.toJson()).toList(),
      },
    };
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
