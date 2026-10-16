import 'package:flutter_test/flutter_test.dart';
import 'package:financer/models/models.dart';
import 'package:financer/providers/budget_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('income entries increase available resources', () {
    final budget = BudgetProvider();
    budget.setWealth(100);
    budget.addIncome(IncomeEntry(
        id: budget.newId(),
        amount: 25,
        category: 'Freelance',
        note: 'Project payment'));
    expect(budget.totalResources, 125);
    budget.dispose();
  });

  test('settled debt and collected loan affect available resources', () {
    final budget = BudgetProvider();
    budget.setWealth(500);
    final debt = LoanDebt(
        id: budget.newId(),
        title: 'Borrowed',
        amount: 60,
        kind: LoanDebtKind.debtToPay,
        isSettled: true);
    final loan = LoanDebt(
        id: budget.newId(),
        title: 'Friend repayment',
        amount: 30,
        kind: LoanDebtKind.loanToCollect,
        isSettled: true);
    budget.addObligation(debt);
    budget.addObligation(loan);
    expect(budget.totalResources, 470);
    budget.dispose();
  });

  test('percentage fixed allocations recalculate against resource base', () {
    final budget = BudgetProvider();
    budget.setWealth(200);
    final item = FixedExpense(
        id: budget.newId(),
        title: 'Investments',
        allocationMode: AllocationMode.percentage,
        percent: 10,
        isInvestment: true,
        basis: AllocationBasis.wealthAndIncome);
    budget.fixed.add(item);
    expect(budget.investmentTotal, 20);
    budget.addIncome(IncomeEntry(
        id: budget.newId(), amount: 50, category: 'Salary', note: ''));
    expect(budget.investmentTotal, 25);
    budget.dispose();
  });

  test('transaction migration reads the old date field and writes dateLogged',
      () {
    final transaction = Transaction.fromJson({
      'id': 'legacy-1',
      'amount': 4.5,
      'category': 'personal',
      'date': '2026-10-16T16:15:00.000',
      'note': 'Coffee',
    });
    expect(transaction.dateLogged, DateTime(2026, 10, 16, 16, 15));
    expect(transaction.toJson().containsKey('dateLogged'), isTrue);
  });

  test('surplus reserves planned expenses and reduces for unplanned spends',
      () {
    final budget = BudgetProvider();
    budget.setWealth(100);
    budget.setDailyCost(5);
    budget.setDays(2);
    expect(budget.unplannedSurplus, 90);
    budget.addTransaction(Transaction(
        id: budget.newId(),
        amount: 8,
        category: ExpenseCategory.other,
        note: 'Unexpected',
        dateLogged: DateTime(2026, 10, 16, 16, 15)));
    expect(budget.unplannedSurplus, 82);
    budget.dispose();
  });
}
