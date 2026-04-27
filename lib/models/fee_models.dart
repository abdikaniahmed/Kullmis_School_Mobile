import 'main_attendance_models.dart';

class AcademicYearOption {
  const AcademicYearOption({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final int id;
  final String name;
  final bool isActive;

  factory AcademicYearOption.fromJson(Map<String, dynamic> json) {
    return AcademicYearOption(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      isActive: _toBool(json['is_active']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive,
    };
  }
}

class FeeStructureItem {
  const FeeStructureItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.isMandatory,
    required this.isActive,
    required this.feeTypeName,
  });

  final int id;
  final String name;
  final double amount;
  final String? frequency;
  final bool isMandatory;
  final bool isActive;
  final String? feeTypeName;

  factory FeeStructureItem.fromJson(Map<String, dynamic> json) {
    final feeType = json['fee_type'];

    return FeeStructureItem(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
      amount: _toDouble(json['amount']),
      frequency: _toNullableString(json['frequency']),
      isMandatory: _toBool(json['is_mandatory']),
      isActive: _toBool(json['is_active']),
      feeTypeName: feeType is Map<String, dynamic>
          ? _toNullableString(feeType['name'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'frequency': frequency,
      'is_mandatory': isMandatory,
      'is_active': isActive,
      'fee_type': feeTypeName == null ? null : {'name': feeTypeName},
    };
  }
}

class FeeInvoicePage {
  const FeeInvoicePage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.from,
    required this.to,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  final List<FeeInvoiceListItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int? from;
  final int? to;
  final bool hasPreviousPage;
  final bool hasNextPage;

  factory FeeInvoicePage.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FeeInvoiceListItem.fromJson)
        .toList();

    return FeeInvoicePage(
      items: items,
      currentPage: _toInt(json['current_page']),
      lastPage: _toInt(json['last_page']),
      total: _toInt(json['total']),
      from: _toNullableInt(json['from']),
      to: _toNullableInt(json['to']),
      hasPreviousPage: json['prev_page_url'] != null,
      hasNextPage: json['next_page_url'] != null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': items.map((item) => item.toJson()).toList(),
      'current_page': currentPage,
      'last_page': lastPage,
      'total': total,
      'from': from,
      'to': to,
      'prev_page_url': hasPreviousPage ? 'cached' : null,
      'next_page_url': hasNextPage ? 'cached' : null,
    };
  }
}

class FeeInvoiceListItem {
  const FeeInvoiceListItem({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    required this.netAmount,
    required this.paidAmount,
    required this.balance,
    required this.status,
    required this.remarks,
    required this.student,
    required this.createdAt,
  });

  final int id;
  final String invoiceNumber;
  final String? issueDate;
  final String? dueDate;
  final double netAmount;
  final double paidAmount;
  final double balance;
  final String status;
  final String? remarks;
  final FeeInvoiceStudentSummary? student;
  final String? createdAt;

  factory FeeInvoiceListItem.fromJson(Map<String, dynamic> json) {
    return FeeInvoiceListItem(
      id: _toInt(json['id']),
      invoiceNumber: '${json['invoice_number'] ?? ''}'.trim(),
      issueDate: _toNullableString(json['issue_date']),
      dueDate: _toNullableString(json['due_date']),
      netAmount: _toDouble(json['net_amount']),
      paidAmount: _toDouble(json['paid_amount']),
      balance: _toDouble(json['balance']),
      status: '${json['status'] ?? ''}'.trim(),
      remarks: _toNullableString(json['remarks']),
      student: FeeInvoiceStudentSummary.fromDynamic(json['student']),
      createdAt: _toNullableString(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'issue_date': issueDate,
      'due_date': dueDate,
      'net_amount': netAmount,
      'paid_amount': paidAmount,
      'balance': balance,
      'status': status,
      'remarks': remarks,
      'student': student?.toJson(),
      'created_at': createdAt,
    };
  }
}

class FeeInvoiceStudentSummary {
  const FeeInvoiceStudentSummary({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  static FeeInvoiceStudentSummary? fromDynamic(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    return FeeInvoiceStudentSummary(
      id: _toInt(value['id']),
      name: '${value['name'] ?? ''}'.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class FeeInvoiceDetail {
  const FeeInvoiceDetail({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    required this.totalAmount,
    required this.discountAmount,
    required this.netAmount,
    required this.paidAmount,
    required this.balance,
    required this.status,
    required this.remarks,
    required this.student,
    required this.school,
    required this.studentAcademicYear,
    required this.items,
    required this.payments,
  });

  final int id;
  final String invoiceNumber;
  final String? issueDate;
  final String? dueDate;
  final double totalAmount;
  final double discountAmount;
  final double netAmount;
  final double paidAmount;
  final double balance;
  final String status;
  final String? remarks;
  final FeeInvoiceStudentSummary? student;
  final FeeInvoiceSchoolSummary? school;
  final FeeInvoiceStudentAcademicYear? studentAcademicYear;
  final List<FeeInvoiceItemDetail> items;
  final List<FeePaymentRecord> payments;

  factory FeeInvoiceDetail.fromJson(Map<String, dynamic> json) {
    return FeeInvoiceDetail(
      id: _toInt(json['id']),
      invoiceNumber: '${json['invoice_number'] ?? ''}'.trim(),
      issueDate: _toNullableString(json['issue_date']),
      dueDate: _toNullableString(json['due_date']),
      totalAmount: _toDouble(json['total_amount']),
      discountAmount: _toDouble(json['discount_amount']),
      netAmount: _toDouble(json['net_amount']),
      paidAmount: _toDouble(json['paid_amount']),
      balance: _toDouble(json['balance']),
      status: '${json['status'] ?? ''}'.trim(),
      remarks: _toNullableString(json['remarks']),
      student: FeeInvoiceStudentSummary.fromDynamic(json['student']),
      school: FeeInvoiceSchoolSummary.fromDynamic(json['school']),
      studentAcademicYear: FeeInvoiceStudentAcademicYear.fromDynamic(
        json['studentAcademicYear'],
      ),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FeeInvoiceItemDetail.fromJson)
          .toList(),
      payments: (json['payments'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FeePaymentRecord.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'issue_date': issueDate,
      'due_date': dueDate,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'net_amount': netAmount,
      'paid_amount': paidAmount,
      'balance': balance,
      'status': status,
      'remarks': remarks,
      'student': student?.toJson(),
      'school': school?.toJson(),
      'studentAcademicYear': studentAcademicYear?.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'payments': payments.map((payment) => payment.toJson()).toList(),
    };
  }
}

class FeeInvoiceSchoolSummary {
  const FeeInvoiceSchoolSummary({
    required this.name,
    required this.address,
    required this.email,
    required this.telephone,
  });

  final String name;
  final String? address;
  final String? email;
  final String? telephone;

  static FeeInvoiceSchoolSummary? fromDynamic(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    return FeeInvoiceSchoolSummary(
      name: '${value['name'] ?? ''}'.trim(),
      address: _toNullableString(value['address']),
      email: _toNullableString(value['email']),
      telephone: _toNullableString(value['telephone']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'email': email,
      'telephone': telephone,
    };
  }
}

class FeeInvoiceStudentAcademicYear {
  const FeeInvoiceStudentAcademicYear({
    required this.rollNumber,
    required this.levelName,
    required this.className,
  });

  final String? rollNumber;
  final String? levelName;
  final String? className;

  static FeeInvoiceStudentAcademicYear? fromDynamic(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final level = value['level'];
    final schoolClass = value['schoolClass'];

    return FeeInvoiceStudentAcademicYear(
      rollNumber: _toNullableString(value['roll_number']),
      levelName: level is Map<String, dynamic>
          ? _toNullableString(level['name'])
          : null,
      className: schoolClass is Map<String, dynamic>
          ? _toNullableString(schoolClass['name'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roll_number': rollNumber,
      'level': levelName == null ? null : {'name': levelName},
      'schoolClass': className == null ? null : {'name': className},
    };
  }
}

class FeeInvoiceItemDetail {
  const FeeInvoiceItemDetail({
    required this.id,
    required this.description,
    required this.amount,
  });

  final int id;
  final String description;
  final double amount;

  factory FeeInvoiceItemDetail.fromJson(Map<String, dynamic> json) {
    return FeeInvoiceItemDetail(
      id: _toInt(json['id']),
      description: '${json['description'] ?? ''}'.trim(),
      amount: _toDouble(json['amount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
    };
  }
}

class FeePaymentRecord {
  const FeePaymentRecord({
    required this.id,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
    required this.referenceNumber,
    required this.receivedByName,
  });

  final int id;
  final double amount;
  final String paymentMethod;
  final String? paymentDate;
  final String? referenceNumber;
  final String? receivedByName;

  factory FeePaymentRecord.fromJson(Map<String, dynamic> json) {
    final receivedBy = json['received_by'];

    return FeePaymentRecord(
      id: _toInt(json['id']),
      amount: _toDouble(json['amount']),
      paymentMethod: '${json['payment_method'] ?? ''}'.trim(),
      paymentDate: _toNullableString(json['payment_date']),
      referenceNumber: _toNullableString(json['reference_no']),
      receivedByName: receivedBy is Map<String, dynamic>
          ? _toNullableString(receivedBy['name'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_date': paymentDate,
      'reference_no': referenceNumber,
      'received_by': receivedByName == null ? null : {'name': receivedByName},
    };
  }
}

class FeePaymentMethod {
  const FeePaymentMethod({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory FeePaymentMethod.fromJson(Map<String, dynamic> json) {
    return FeePaymentMethod(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}'.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class FeeStructuresOfflineSnapshot {
  const FeeStructuresOfflineSnapshot({
    required this.years,
    required this.selectedYearId,
    required this.fees,
  });

  final List<AcademicYearOption> years;
  final int? selectedYearId;
  final List<FeeStructureItem> fees;

  factory FeeStructuresOfflineSnapshot.fromJson(Map<String, dynamic> json) {
    return FeeStructuresOfflineSnapshot(
      years: (json['years'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AcademicYearOption.fromJson)
          .toList(),
      selectedYearId: _toNullableInt(json['selected_year_id']),
      fees: (json['fees'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FeeStructureItem.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'years': years.map((year) => year.toJson()).toList(),
      'selected_year_id': selectedYearId,
      'fees': fees.map((fee) => fee.toJson()).toList(),
    };
  }
}

class FeeInvoicesOfflineSnapshot {
  const FeeInvoicesOfflineSnapshot({
    required this.years,
    required this.levels,
    required this.classes,
    required this.page,
    required this.selectedYearId,
    required this.selectedLevelId,
    required this.selectedClassId,
    required this.selectedStatus,
    required this.search,
  });

  final List<AcademicYearOption> years;
  final List<MainAttendanceLevel> levels;
  final List<MainAttendanceClass> classes;
  final FeeInvoicePage? page;
  final int? selectedYearId;
  final int? selectedLevelId;
  final int? selectedClassId;
  final String selectedStatus;
  final String search;

  factory FeeInvoicesOfflineSnapshot.fromJson(Map<String, dynamic> json) {
    return FeeInvoicesOfflineSnapshot(
      years: (json['years'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AcademicYearOption.fromJson)
          .toList(),
      levels: (json['levels'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MainAttendanceLevel.fromJson)
          .toList(),
      classes: (json['classes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MainAttendanceClass.fromJson)
          .toList(),
      page: json['page'] is Map<String, dynamic>
          ? FeeInvoicePage.fromJson(json['page'] as Map<String, dynamic>)
          : null,
      selectedYearId: _toNullableInt(json['selected_year_id']),
      selectedLevelId: _toNullableInt(json['selected_level_id']),
      selectedClassId: _toNullableInt(json['selected_class_id']),
      selectedStatus: '${json['selected_status'] ?? ''}',
      search: '${json['search'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'years': years.map((year) => year.toJson()).toList(),
      'levels': levels.map((level) => level.toJson()).toList(),
      'classes': classes.map((schoolClass) => schoolClass.toJson()).toList(),
      'page': page?.toJson(),
      'selected_year_id': selectedYearId,
      'selected_level_id': selectedLevelId,
      'selected_class_id': selectedClassId,
      'selected_status': selectedStatus,
      'search': search,
    };
  }
}

class FeePaymentsOfflineSnapshot {
  const FeePaymentsOfflineSnapshot({
    required this.years,
    required this.levels,
    required this.classes,
    required this.methods,
    required this.page,
    required this.selectedYearId,
    required this.selectedLevelId,
    required this.selectedClassId,
    required this.selectedStatus,
    required this.selectedMethod,
    required this.search,
    required this.paymentDate,
    required this.reference,
  });

  final List<AcademicYearOption> years;
  final List<MainAttendanceLevel> levels;
  final List<MainAttendanceClass> classes;
  final List<FeePaymentMethod> methods;
  final FeeInvoicePage? page;
  final int? selectedYearId;
  final int? selectedLevelId;
  final int? selectedClassId;
  final String selectedStatus;
  final String? selectedMethod;
  final String search;
  final String paymentDate;
  final String reference;

  factory FeePaymentsOfflineSnapshot.fromJson(Map<String, dynamic> json) {
    return FeePaymentsOfflineSnapshot(
      years: (json['years'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AcademicYearOption.fromJson)
          .toList(),
      levels: (json['levels'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MainAttendanceLevel.fromJson)
          .toList(),
      classes: (json['classes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MainAttendanceClass.fromJson)
          .toList(),
      methods: (json['methods'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FeePaymentMethod.fromJson)
          .toList(),
      page: json['page'] is Map<String, dynamic>
          ? FeeInvoicePage.fromJson(json['page'] as Map<String, dynamic>)
          : null,
      selectedYearId: _toNullableInt(json['selected_year_id']),
      selectedLevelId: _toNullableInt(json['selected_level_id']),
      selectedClassId: _toNullableInt(json['selected_class_id']),
      selectedStatus: '${json['selected_status'] ?? ''}',
      selectedMethod: _toNullableString(json['selected_method']),
      search: '${json['search'] ?? ''}',
      paymentDate: '${json['payment_date'] ?? ''}',
      reference: '${json['reference'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'years': years.map((year) => year.toJson()).toList(),
      'levels': levels.map((level) => level.toJson()).toList(),
      'classes': classes.map((schoolClass) => schoolClass.toJson()).toList(),
      'methods': methods.map((method) => method.toJson()).toList(),
      'page': page?.toJson(),
      'selected_year_id': selectedYearId,
      'selected_level_id': selectedLevelId,
      'selected_class_id': selectedClassId,
      'selected_status': selectedStatus,
      'selected_method': selectedMethod,
      'search': search,
      'payment_date': paymentDate,
      'reference': reference,
    };
  }
}

class FeeInvoiceDetailOfflineSnapshot {
  const FeeInvoiceDetailOfflineSnapshot({
    required this.invoice,
  });

  final FeeInvoiceDetail invoice;

  factory FeeInvoiceDetailOfflineSnapshot.fromJson(Map<String, dynamic> json) {
    return FeeInvoiceDetailOfflineSnapshot(
      invoice: FeeInvoiceDetail.fromJson(
        json['invoice'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice': invoice.toJson(),
    };
  }
}

class FeePaymentResult {
  const FeePaymentResult({
    required this.message,
    required this.payment,
    required this.invoice,
  });

  final String? message;
  final FeePaymentRecord payment;
  final FeeInvoiceDetail invoice;

  factory FeePaymentResult.fromJson(Map<String, dynamic> json) {
    return FeePaymentResult(
      message: _toNullableString(json['message']),
      payment: FeePaymentRecord.fromJson(
        json['payment'] as Map<String, dynamic>? ?? const {},
      ),
      invoice: FeeInvoiceDetail.fromJson(
        json['invoice'] as Map<String, dynamic>? ?? const {},
      ),
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

int? _toNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }

  return int.tryParse('$value');
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
