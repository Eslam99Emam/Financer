import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:financer/models/models.dart';
import 'package:financer/services/storage_service.dart';

class BudgetProvider extends ChangeNotifier {
  double wealth = 0; // User-entered starting wealth, before logged income.
  double dailyCost = 0;
  int days = 0;

  final List<FixedExpense> fixed = [];
  final List<PersonalActivity> activities = [];
  final List<Transaction> _transactions = [];
  final List<IncomeEntry> _incomeEntries = [];
  final List<ExpensePreset> presets = [];
  final List<LoanDebt> obligations = [];

  int _counter = 0;
  String newId() => '${_counter++}';

  final StorageService? _storage;
  Timer? _saveTimer;

  BudgetProvider({StorageService? storage}) : _storage = storage {
    final data = storage?.read();
    if (data == null || !_restore(data)) _seedDefaults();
    // A v1 snapshot won't contain presets or income/debt lists.
    if (presets.isEmpty) _seedPresets();
    if (_counter == 0) _counter = _maxExistingId + 1;
  }

  int get _maxExistingId {
    final ids = <String>[
      ...fixed.map((e) => e.id),
      ...activities.map((e) => e.id),
      ..._transactions.map((e) => e.id),
      ..._incomeEntries.map((e) => e.id),
      ...presets.map((e) => e.id),
      ...obligations.map((e) => e.id),
    ];
    return ids
        .map((e) => int.tryParse(e) ?? -1)
        .fold<int>(-1, (a, b) => math.max(a, b).toInt());
  }

  void _seedDefaults() {
    wealth = 0;
    dailyCost = 0;
    days = 0;
    fixed.clear();
    activities.clear();
    _transactions.clear();
    _incomeEntries.clear();
    presets.clear();
    obligations.clear();
    _counter = 0;
    for (final title in [
      'Dining Out',
      'Hanging with Friends',
      'Entertainment'
    ]) {
      activities.add(PersonalActivity(id: newId(), title: title));
    }
    _seedPresets();
  }

  void _seedPresets() {
    if (presets.isNotEmpty) return;
    presets.addAll([
      ExpensePreset(
          id: newId(),
          title: 'Coffee',
          amount: 3,
          category: ExpenseCategory.personal),
      ExpensePreset(
          id: newId(),
          title: 'Lunch',
          amount: 10,
          category: ExpenseCategory.personal),
      ExpensePreset(
          id: newId(),
          title: 'Metro',
          amount: 2,
          category: ExpenseCategory.transport),
    ]);
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 2,
        'wealth': wealth,
        'dailyCost': dailyCost,
        'days': days,
        'counter': _counter,
        'fixed': fixed.map((e) => e.toJson()).toList(),
        'activities': activities.map((e) => e.toJson()).toList(),
        'transactions': _transactions.map((e) => e.toJson()).toList(),
        'incomeEntries': _incomeEntries.map((e) => e.toJson()).toList(),
        'presets': presets.map((e) => e.toJson()).toList(),
        'obligations': obligations.map((e) => e.toJson()).toList(),
      };

  bool _restore(Map<String, dynamic> json) {
    try {
      wealth = (json['wealth'] as num?)?.toDouble() ?? 0;
      dailyCost = (json['dailyCost'] as num?)?.toDouble() ?? 0;
      days = ((json['days'] as num?)?.toInt() ?? 0).clamp(0, 31).toInt();
      fixed.addAll(((json['fixed'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => FixedExpense.fromJson(Map<String, dynamic>.from(e))));
      activities.addAll(((json['activities'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => PersonalActivity.fromJson(Map<String, dynamic>.from(e))));
      _transactions.addAll(((json['transactions'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Transaction.fromJson(Map<String, dynamic>.from(e))));
      _incomeEntries.addAll(((json['incomeEntries'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => IncomeEntry.fromJson(Map<String, dynamic>.from(e))));
      presets.addAll(((json['presets'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ExpensePreset.fromJson(Map<String, dynamic>.from(e))));
      obligations.addAll(((json['obligations'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => LoanDebt.fromJson(Map<String, dynamic>.from(e))));
      _counter = math
          .max((json['counter'] as num?)?.toInt() ?? 0, _maxExistingId + 1)
          .toInt();
      return true;
    } catch (_) {
      wealth = 0;
      dailyCost = 0;
      days = 0;
      fixed.clear();
      activities.clear();
      _transactions.clear();
      _incomeEntries.clear();
      presets.clear();
      obligations.clear();
      _counter = 0;
      return false;
    }
  }

  Future<void> _save() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _storage?.write(toJson());
  }

  Future<void> flush() => _save();

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_storage == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), _save);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_save());
    super.dispose();
  }

  void refresh() => notifyListeners();
  void setWealth(double value) {
    wealth = value.clamp(0, double.infinity).toDouble();
    notifyListeners();
  }

  void setDailyCost(double value) {
    dailyCost = value.clamp(0, double.infinity).toDouble();
    notifyListeners();
  }

  void setDays(int value) {
    days = value.clamp(0, 31).toInt();
    notifyListeners();
  }

  void addFixed({bool investment = false}) {
    fixed.add(FixedExpense(
      id: newId(),
      title: investment ? 'Investments' : '',
      allocationMode:
          investment ? AllocationMode.percentage : AllocationMode.fixedAmount,
      percent: investment ? 10 : 0,
      isInvestment: investment,
    ));
    notifyListeners();
  }

  void removeFixed(String id) {
    fixed.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void addActivity(PersonalActivity activity) {
    activities.add(activity);
    notifyListeners();
  }

  void removeActivity(String id) {
    activities.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void addTransaction(Transaction transaction) {
    _transactions.add(transaction);
    notifyListeners();
  }

  void removeTransaction(String id) {
    _transactions.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void addIncome(IncomeEntry entry) {
    _incomeEntries.add(entry);
    notifyListeners();
  }

  void removeIncome(String id) {
    _incomeEntries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void addPreset(ExpensePreset preset) {
    presets.add(preset);
    notifyListeners();
  }

  void updatePreset(ExpensePreset edited) {
    final index = presets.indexWhere((e) => e.id == edited.id);
    if (index >= 0) presets[index] = edited;
    notifyListeners();
  }

  void removePreset(String id) {
    presets.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void addObligation(LoanDebt entry) {
    obligations.add(entry);
    notifyListeners();
  }

  void removeObligation(String id) {
    obligations.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void toggleObligationSettled(String id) {
    final index = obligations.indexWhere((e) => e.id == id);
    if (index < 0) return;
    obligations[index].isSettled = !obligations[index].isSettled;
    notifyListeners();
  }

  List<Transaction> get transactions =>
      [..._transactions]..sort((a, b) => b.dateLogged.compareTo(a.dateLogged));
  List<IncomeEntry> get incomeEntries =>
      [..._incomeEntries]..sort((a, b) => b.dateLogged.compareTo(a.dateLogged));
  List<LoanDebt> get sortedObligations =>
      [...obligations]..sort((a, b) => b.dateLogged.compareTo(a.dateLogged));

  double get incomeTotal =>
      _incomeEntries.fold(0.0, (sum, e) => sum + e.amount);
  double get settledLoansCollected => obligations
      .where((e) => e.kind == LoanDebtKind.loanToCollect && e.isSettled)
      .fold(0.0, (s, e) => s + e.amount);
  double get settledDebtsPaid => obligations
      .where((e) => e.kind == LoanDebtKind.debtToPay && e.isSettled)
      .fold(0.0, (s, e) => s + e.amount);

  /// Available resource base includes income and the cash effect of settled debt/loan entries.
  double get totalResources =>
      wealth + incomeTotal + settledLoansCollected - settledDebtsPaid;

  double effectiveFixed(FixedExpense item) => item.effectiveAmount(
      startingWealth: wealth, totalResources: totalResources);
  double get fixedTotal => fixed
      .where((e) => !e.isInvestment)
      .fold(0.0, (sum, e) => sum + effectiveFixed(e));
  double get investmentTotal => fixed
      .where((e) => e.isInvestment)
      .fold(0.0, (sum, e) => sum + effectiveFixed(e));
  double get allFixedTotal => fixedTotal + investmentTotal;
  double get transport => dailyCost * days;
  double get personalTotal =>
      activities.fold(0.0, (sum, a) => sum + a.plannedAmount);
  double get plannedTotal => allFixedTotal + transport + personalTotal;
  double get plannedRemaining => totalResources - plannedTotal;

  double plannedFor(ExpenseCategory category) => switch (category) {
        ExpenseCategory.transport => transport,
        ExpenseCategory.fixed => allFixedTotal,
        ExpenseCategory.personal => personalTotal,
        ExpenseCategory.other => 0,
      };

  double actualFor(ExpenseCategory category) => _transactions
      .where((e) => e.category == category)
      .fold(0.0, (sum, e) => sum + e.amount);
  double get actualTotal => _transactions.fold(0.0, (sum, e) => sum + e.amount);
  double get actualRemaining => totalResources - actualTotal;
  Variance varianceFor(ExpenseCategory category) =>
      Variance(plannedFor(category), actualFor(category));
  Variance get totalVariance => Variance(plannedTotal, actualTotal);

  /// Reserves each category at the higher of its plan or actual spending.
  /// Unplanned transactions have no budget, so they reduce the surplus directly.
  double get projectedTotal => ExpenseCategory.values.fold<double>(
      0,
      (sum, category) =>
          sum + math.max(plannedFor(category), actualFor(category)).toDouble());
  double get unplannedSurplus => totalResources - projectedTotal;
  double get outstandingDebts => obligations
      .where((e) => e.kind == LoanDebtKind.debtToPay && !e.isSettled)
      .fold(0.0, (s, e) => s + e.amount);
  double get outstandingLoans => obligations
      .where((e) => e.kind == LoanDebtKind.loanToCollect && !e.isSettled)
      .fold(0.0, (s, e) => s + e.amount);

  Future<void> resetAll() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _storage?.clearAll();
    _seedDefaults();
    notifyListeners();
    await _save();
  }
}
