import 'dart:async';
import 'dart:math' as math;

import 'package:financer/helpers.dart';
import 'package:financer/models/models.dart';
import 'package:financer/services/storage_service.dart';
import 'package:flutter/foundation.dart';

class BudgetProvider extends ChangeNotifier {
  // ── Plan inputs ──
  double wealth = 0;
  double dailyCost = 0;
  int days = 0;
  final List<FixedExpense> fixed = [];
  final List<PersonalActivity> activities = [];

  // ── Actuals ──
  final List<Transaction> _transactions = [];

  int _counter = 0;
  String newId() => '${_counter++}';

  // ── Persistence ──
  final StorageService? _storage;
  Timer? _saveTimer;

  BudgetProvider({StorageService? storage}) : _storage = storage {
    final data = storage?.read();
    if (data != null && _restore(data)) return;
    // First launch (or unreadable data): seed defaults.
    for (final t in ['Dining Out', 'Hanging with Friends', 'Entertainment']) {
      activities.add(PersonalActivity(id: newId(), title: t));
    }
  }

  Map<String, dynamic> toJson() => {
    'wealth': wealth,
    'dailyCost': dailyCost,
    'days': days,
    'counter': _counter,
    'fixed': fixed.map((e) => e.toJson()).toList(),
    'activities': activities.map((a) => a.toJson()).toList(),
    'transactions': _transactions.map((t) => t.toJson()).toList(),
  };

  bool _restore(Map<String, dynamic> j) {
    try {
      wealth = (j['wealth'] as num?)?.toDouble() ?? 0;
      dailyCost = (j['dailyCost'] as num?)?.toDouble() ?? 0;
      days = ((j['days'] as num?)?.toInt() ?? 0).clamp(0, 31);
      fixed.addAll(
        ((j['fixed'] as List?) ?? const []).map(
          (e) => FixedExpense.fromJson(e as Map<String, dynamic>),
        ),
      );
      activities.addAll(
        ((j['activities'] as List?) ?? const []).map(
          (e) => PersonalActivity.fromJson(e as Map<String, dynamic>),
        ),
      );
      _transactions.addAll(
        ((j['transactions'] as List?) ?? const []).map(
          (e) => Transaction.fromJson(e as Map<String, dynamic>),
        ),
      );

      final maxId = [
        ...fixed.map((e) => e.id),
        ...activities.map((a) => a.id),
        ..._transactions.map((t) => t.id),
      ].map((s) => int.tryParse(s) ?? -1).fold<int>(-1, (a, b) => math.max(a, b));
      _counter = math.max((j['counter'] as num?)?.toInt() ?? 0, maxId + 1);
      return true;
    } catch (_) {
      wealth = 0;
      dailyCost = 0;
      days = 0;
      fixed.clear();
      activities.clear();
      _transactions.clear();
      _counter = 0;
      return false;
    }
  }

  Future<void> _save() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _storage?.write(toJson());
  }

  /// Save immediately (used when the app goes to background).
  Future<void> flush() => _save();

  // Every mutation calls notifyListeners → schedule a debounced save.
  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_storage == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) _save();
    super.dispose();
  }

  // ── Mutations ──
  void refresh() => notifyListeners();

  void setWealth(double v) {
    wealth = v;
    notifyListeners();
  }

  void setDailyCost(double v) {
    dailyCost = v;
    notifyListeners();
  }

  void setDays(int v) {
    days = v;
    notifyListeners();
  }

  void addFixed() {
    fixed.add(FixedExpense(id: newId()));
    notifyListeners();
  }

  void removeFixed(FixedExpense e) {
    fixed.remove(e);
    notifyListeners();
  }

  void addActivity(PersonalActivity a) {
    activities.add(a);
    notifyListeners();
  }

  void removeActivity(PersonalActivity a) {
    activities.remove(a);
    notifyListeners();
  }

  void addTransaction(Transaction t) {
    _transactions.add(t);
    notifyListeners();
  }

  void removeTransaction(String id) {
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ── Transactions (newest first) ──
  List<Transaction> get transactions {
    final list = [..._transactions];
    list.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0
          ? c
          : (int.tryParse(b.id) ?? 0).compareTo(int.tryParse(a.id) ?? 0);
    });
    return list;
  }

  // ── Planned ──
  double get transport => dailyCost * days;
  double get fixedTotal => fixed.fold(0.0, (s, e) => s + e.amount);
  double get personalTotal =>
      activities.fold(0.0, (s, a) => s + a.costPerInstance * a.frequency);
  double get plannedTotal => transport + fixedTotal + personalTotal;
  double get plannedRemaining => wealth - plannedTotal;

  double plannedFor(ExpenseCategory c) => switch (c) {
    ExpenseCategory.transport => transport,
    ExpenseCategory.fixed => fixedTotal,
    ExpenseCategory.personal => personalTotal,
    ExpenseCategory.other => 0,
  };

  // ── Actual ──
  double actualFor(ExpenseCategory c) => _transactions
      .where((t) => t.category == c)
      .fold(0.0, (s, t) => s + t.amount);

  double get actualTotal => _transactions.fold(0.0, (s, t) => s + t.amount);

  /// R_actual = initial wealth - total actual spent
  double get actualRemaining => wealth - actualTotal;

  // ── Variance engine ──
  Variance varianceFor(ExpenseCategory c) =>
      Variance(plannedFor(c), actualFor(c));

  Variance get totalVariance => Variance(plannedTotal, actualTotal);

  // ── Net Remaining (investment basis) ──
  /// Expenses used for investing: per category, the higher of planned or
  /// actual. Unspent plan stays reserved; overspending reduces the margin.
  double get projectedTotal => ExpenseCategory.values.fold(
    0.0,
    (s, c) => s + math.max(plannedFor(c), actualFor(c)),
  );

  /// Net Remaining = Starting Wealth - Total Expenses
  double get netRemaining => wealth - projectedTotal;

  /// 10% when margin (net / wealth) <= 10%, scaling to 20% at >= 20%.
  double _pctFor(double w, double net) {
    final t = (((net / w) - 0.10) / 0.10).clamp(0.0, 1.0).toDouble();
    return 10 + 10 * t;
  }

  double _fundFor(double w, double net) =>
      (w <= 0 || net <= 0) ? 0 : net * _pctFor(w, net) / 100;

  // ── Future Goals Fund ──
  InvestmentAdvice get advice {
    final w = wealth;
    final net = netRemaining;

    if (w <= 0) {
      return const InvestmentAdvice(
        tier: AdviceTier.noWealth,
        amount: 0,
        percent: 0,
        lines: ['Enter your wealth to get a Future Goals Fund recommendation.'],
      );
    }

    if (net <= 0) {
      final lines = <String>[
        'Net remaining is ${money(net)}; nothing is left to allocate.',
      ];

      // Discretionary cuts that actually lower projected expenses.
      var need = -net;
      var reducible = math.max(
        0.0,
        personalTotal - actualFor(ExpenseCategory.personal),
      );
      final sorted =
          activities
              .where((a) => a.costPerInstance > 0 && a.frequency > 0)
              .toList()
            ..sort(
              (a, b) => (b.costPerInstance * b.frequency).compareTo(
                a.costPerInstance * a.frequency,
              ),
            );

      final cuts = <String>[];
      for (final a in sorted) {
        if (need <= 0 || reducible <= 0) break;
        final cut = math.min(
          a.frequency,
          math.min(
            (need / a.costPerInstance).ceil(),
            (reducible / a.costPerInstance).floor(),
          ),
        );
        if (cut <= 0) continue;
        cuts.add("Reduce '${a.title}' by $cut instance${cut == 1 ? '' : 's'}");
        need -= cut * a.costPerInstance;
        reducible -= cut * a.costPerInstance;
      }
      if (cuts.isNotEmpty) {
        lines.add('${cuts.join('; ')} to cover the shortfall.');
      }
      if (need > 0) {
        lines.add(
          'Still ${money(need)} short after discretionary cuts — review fixed costs, transport or unplanned spending.',
        );
      }

      return InvestmentAdvice(
        tier: AdviceTier.deficit,
        amount: 0,
        percent: 0,
        lines: lines,
        alert: 'Reduce discretionary activities before allocating to future goals.',
      );
    }

    final pct = _pctFor(w, net);
    final fund = net * pct / 100;
    final lines = <String>[
      'Net remaining ${money(net)} = wealth − expenses (higher of planned or actual per category).',
      'Left after funding goals: ${money(net - fund)}',
    ];
    if (net / w < 0.10) {
      lines.add('Low margin: trimming discretionary spending would raise your fund.');
    }

    String? alert;
    final plannedFund = _fundFor(w, plannedRemaining);
    if (fund < plannedFund - 0.005) {
      alert =
          'Overspending reduced your Future Goals Fund from ${money(plannedFund)} to ${money(fund)}.';
    }

    return InvestmentAdvice(
      tier: AdviceTier.goalFund,
      amount: fund,
      percent: pct,
      lines: lines,
      alert: alert,
    );
  }
}
