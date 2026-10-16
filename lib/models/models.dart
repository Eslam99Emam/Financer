// Domain models for the personal finance planner.
// JSON readers are deliberately tolerant of the original v1 app's fields.

enum ExpenseCategory {
  transport('Transport'),
  fixed('Fixed costs'),
  personal('Discretionary'),
  other('Unplanned');

  const ExpenseCategory(this.label);
  final String label;

  static ExpenseCategory fromJson(Object? value) =>
      ExpenseCategory.values.where((c) => c.name == value).firstOrNull ??
      ExpenseCategory.other;
}

enum AllocationMode { fixedAmount, percentage }

enum AllocationBasis { startingWealth, wealthAndIncome }

enum LoanDebtKind { debtToPay, loanToCollect }

class FixedExpense {
  FixedExpense({
    required this.id,
    this.title = '',
    this.amount = 0,
    this.allocationMode = AllocationMode.fixedAmount,
    this.percent = 10,
    this.basis = AllocationBasis.wealthAndIncome,
    this.isInvestment = false,
  });

  final String id;
  String title;
  double amount;
  AllocationMode allocationMode;
  double percent;
  AllocationBasis basis;
  bool isInvestment;

  double effectiveAmount(
      {required double startingWealth, required double totalResources}) {
    if (allocationMode == AllocationMode.fixedAmount) {
      return amount.clamp(0, double.infinity).toDouble();
    }
    final base = basis == AllocationBasis.startingWealth
        ? startingWealth
        : totalResources;
    return base * percent.clamp(0, 100).toDouble() / 100;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'allocationMode': allocationMode.name,
        'percent': percent,
        'basis': basis.name,
        'isInvestment': isInvestment,
      };

  factory FixedExpense.fromJson(Map<String, dynamic> json) => FixedExpense(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] as String?) ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        allocationMode: AllocationMode.values
                .where((v) => v.name == json['allocationMode'])
                .firstOrNull ??
            AllocationMode.fixedAmount,
        percent: (json['percent'] as num?)?.toDouble() ?? 10,
        basis: AllocationBasis.values
                .where((v) => v.name == json['basis'])
                .firstOrNull ??
            AllocationBasis.wealthAndIncome,
        isInvestment: (json['isInvestment'] as bool?) ?? false,
      );
}

class PersonalActivity {
  PersonalActivity(
      {required this.id,
      required this.title,
      this.costPerInstance = 0,
      this.frequency = 0});

  final String id;
  String title;
  double costPerInstance;
  int frequency;

  double get plannedAmount =>
      costPerInstance.clamp(0, double.infinity).toDouble() *
      frequency.clamp(0, 100000).toInt();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'costPerInstance': costPerInstance,
        'frequency': frequency,
      };

  factory PersonalActivity.fromJson(Map<String, dynamic> json) =>
      PersonalActivity(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] as String?) ?? '',
        costPerInstance: (json['costPerInstance'] as num?)?.toDouble() ?? 0,
        frequency: ((json['frequency'] as num?)?.toInt() ?? 0)
            .clamp(0, 100000)
            .toInt(),
      );
}

class Transaction {
  Transaction({
    required this.id,
    required this.amount,
    required this.category,
    DateTime? dateLogged,
    DateTime? date,
    this.note = '',
  }) : dateLogged = dateLogged ?? date ?? DateTime.now();

  final String id;
  final double amount;
  final ExpenseCategory category;

  /// When the expense was logged (not just a calendar date).
  final DateTime dateLogged;
  String note;

  // Compatibility getter for code that used the old field name.
  DateTime get date => dateLogged;

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category.name,
        'dateLogged': dateLogged.toIso8601String(),
        // Keep old key during migration so older builds can still open the data.
        'date': dateLogged.toIso8601String(),
        'note': note,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: (json['id'] ?? '').toString(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        category: ExpenseCategory.fromJson(json['category']),
        dateLogged: DateTime.tryParse(
                (json['dateLogged'] ?? json['date'] ?? '').toString()) ??
            DateTime.now(),
        note: (json['note'] as String?) ?? '',
      );
}

class IncomeEntry {
  IncomeEntry({
    required this.id,
    required this.amount,
    required this.category,
    required this.note,
    DateTime? dateLogged,
  }) : dateLogged = dateLogged ?? DateTime.now();

  final String id;
  final double amount;
  final String category;
  final String note;
  final DateTime dateLogged;

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category,
        'note': note,
        'dateLogged': dateLogged.toIso8601String(),
      };

  factory IncomeEntry.fromJson(Map<String, dynamic> json) => IncomeEntry(
        id: (json['id'] ?? '').toString(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        category: (json['category'] as String?) ?? 'Other income',
        note: (json['note'] as String?) ?? '',
        dateLogged: DateTime.tryParse((json['dateLogged'] ?? '').toString()) ??
            DateTime.now(),
      );
}

class ExpensePreset {
  ExpensePreset({
    required this.id,
    required this.title,
    required this.amount,
    this.category = ExpenseCategory.personal,
    this.note = '',
  });

  final String id;
  String title;
  double amount;
  ExpenseCategory category;
  String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category.name,
        'note': note,
      };

  factory ExpensePreset.fromJson(Map<String, dynamic> json) => ExpensePreset(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] as String?) ?? 'Expense',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        category: ExpenseCategory.fromJson(json['category']),
        note: (json['note'] as String?) ?? '',
      );
}

class LoanDebt {
  LoanDebt({
    required this.id,
    required this.title,
    required this.amount,
    required this.kind,
    this.note = '',
    this.isSettled = false,
    DateTime? dateLogged,
  }) : dateLogged = dateLogged ?? DateTime.now();

  final String id;
  String title;
  double amount;
  LoanDebtKind kind;
  String note;
  bool isSettled;
  final DateTime dateLogged;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'kind': kind.name,
        'note': note,
        'isSettled': isSettled,
        'dateLogged': dateLogged.toIso8601String(),
      };

  factory LoanDebt.fromJson(Map<String, dynamic> json) => LoanDebt(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] as String?) ?? 'Loan / debt',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        kind: LoanDebtKind.values
                .where((v) => v.name == json['kind'])
                .firstOrNull ??
            LoanDebtKind.debtToPay,
        note: (json['note'] as String?) ?? '',
        isSettled: (json['isSettled'] as bool?) ?? false,
        dateLogged: DateTime.tryParse((json['dateLogged'] ?? '').toString()) ??
            DateTime.now(),
      );
}

class Variance {
  const Variance(this.planned, this.actual);
  final double planned;
  final double actual;
  double get variance => actual - planned;
  bool get isOver => variance > 0.005;
  double get ratio => planned > 0 ? actual / planned : (actual > 0 ? 1 : 0);
}

// Dart's Iterable.firstOrNull was added to recent SDKs; this local extension
// keeps the source compatible with earlier Dart 3 versions.
extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
