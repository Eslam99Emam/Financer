// ───────────────────────── Models ─────────────────────────

class FixedExpense {
  final String id;
  String title;
  double amount;
  FixedExpense({required this.id, this.title = '', this.amount = 0});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'amount': amount};

  factory FixedExpense.fromJson(Map<String, dynamic> j) => FixedExpense(
    id: j['id'] as String,
    title: (j['title'] as String?) ?? '',
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
  );
}

class PersonalActivity {
  final String id;
  String title;
  double costPerInstance;
  int frequency;
  PersonalActivity({
    required this.id,
    required this.title,
    this.costPerInstance = 0,
    this.frequency = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'costPerInstance': costPerInstance,
    'frequency': frequency,
  };

  factory PersonalActivity.fromJson(Map<String, dynamic> j) => PersonalActivity(
    id: j['id'] as String,
    title: (j['title'] as String?) ?? '',
    costPerInstance: (j['costPerInstance'] as num?)?.toDouble() ?? 0,
    frequency: (j['frequency'] as num?)?.toInt() ?? 0,
  );
}

enum ExpenseCategory {
  transport('Transport'),
  fixed('Fixed'),
  personal('Personal'),
  other('Unplanned');

  final String label;
  const ExpenseCategory(this.label);
}

class Transaction {
  final String id;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final String note;

  const Transaction({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'category': category.name,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
    id: j['id'] as String,
    amount: (j['amount'] as num).toDouble(),
    category: ExpenseCategory.values.firstWhere(
      (c) => c.name == j['category'],
      orElse: () => ExpenseCategory.other,
    ),
    date: DateTime.parse(j['date'] as String),
    note: (j['note'] as String?) ?? '',
  );
}

/// Planned vs actual for one category (or the grand total).
/// variance = actual - planned
class Variance {
  final double planned;
  final double actual;
  const Variance(this.planned, this.actual);

  double get variance => actual - planned;
  bool get isOver => variance > 0.005;

  /// 0..1+ usage ratio. Unplanned spend (planned == 0) counts as full/over.
  double get ratio => planned > 0 ? actual / planned : (actual > 0 ? 1.0 : 0.0);
}

enum AdviceTier { noWealth, deficit, goalFund }

/// "Future Goals Fund" recommendation based on Net Remaining.
class InvestmentAdvice {
  final AdviceTier tier;
  final double amount;
  final double percent; // 10..20 when tier == goalFund, else 0
  final List<String> lines;

  /// Non-null when a warning must be shown.
  final String? alert;

  const InvestmentAdvice({
    required this.tier,
    required this.amount,
    required this.percent,
    required this.lines,
    this.alert,
  });
}
