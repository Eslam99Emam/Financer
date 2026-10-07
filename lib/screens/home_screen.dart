import 'package:financer/helpers.dart';
import 'package:financer/models/models.dart';
import 'package:financer/providers/budget_provider.dart';
import 'package:financer/widgets.dart';
import 'package:financer/widgets/tracking_widgets.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final BudgetProvider budget;
  const HomeScreen({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: budget,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Budget Planner')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _quickLog(context),
          icon: const Icon(Icons.add),
          label: const Text('Log spend'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _wealthSection(),
            const SizedBox(height: 12),
            _varianceSection(),
            const SizedBox(height: 12),
            _transportSection(),
            const SizedBox(height: 12),
            _fixedSection(),
            const SizedBox(height: 12),
            _personalSection(context),
            const SizedBox(height: 12),
            _investmentCard(context),
            const SizedBox(height: 12),
            _historySection(context),
          ],
        ),
      ),
    );
  }

  // ── Actions ──
  Future<void> _quickLog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final tx = await showModalBottomSheet<Transaction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => QuickLogSheet(id: budget.newId()),
    );
    if (tx == null) return;
    budget.addTransaction(tx);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Logged ${money(tx.amount)} • ${tx.category.label}'),
        ),
      );
  }

  void _deleteTx(BuildContext context, Transaction tx) {
    budget.removeTransaction(tx.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted ${money(tx.amount)}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => budget.addTransaction(tx),
          ),
        ),
      );
  }

  Future<void> _addActivity(BuildContext context) async {
    final result = await showDialog<PersonalActivity>(
      context: context,
      builder: (_) => AddActivityDialog(id: budget.newId()),
    );
    if (result != null) budget.addActivity(result);
  }

  // ── 1. Wealth + balances ──
  Widget _wealthSection() {
    return Column(
      children: [
        TextFormField(
          initialValue: numText(budget.wealth),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [numFormatter],
          decoration: const InputDecoration(
            labelText: 'Current Total Wealth / Bank Balance',
            prefixText: '\$ ',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => budget.setWealth(parseNum(v)),
        ),
        const SizedBox(height: 12),
        BalanceCard(
          title: 'Actual Remaining',
          value: budget.actualRemaining,
          caption:
              'Wealth ${money(budget.wealth)}  •  Spent ${money(budget.actualTotal)}',
          large: true,
        ),
        const SizedBox(height: 8),
        BalanceCard(
          title: 'Planned Remaining',
          value: budget.plannedRemaining,
          caption: 'Planned expenses ${money(budget.plannedTotal)}',
        ),
      ],
    );
  }

  // ── 2. Planned vs Actual ──
  Widget _varianceSection() {
    final cats = ExpenseCategory.values.where(
      (c) => c != ExpenseCategory.other || budget.actualFor(c) > 0,
    );
    return SectionCard(
      title: 'Planned vs Actual',
      icon: Icons.compare_arrows,
      child: Column(
        children: [
          for (final c in cats)
            VarianceBar(
              label: c.label,
              icon: c.icon,
              variance: budget.varianceFor(c),
            ),
          const Divider(),
          const SizedBox(height: 8),
          VarianceBar(
            label: 'Total',
            icon: Icons.functions,
            variance: budget.totalVariance,
          ),
        ],
      ),
    );
  }

  // ── 3. Transportation ──
  Widget _transportSection() {
    return SectionCard(
      title: 'Transportation (Planned)',
      icon: Icons.directions_bus_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            initialValue: numText(budget.dailyCost),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [numFormatter],
            decoration: const InputDecoration(
              labelText: 'Daily cost',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => budget.setDailyCost(parseNum(v)),
          ),
          const SizedBox(height: 12),
          Text('Active days: ${budget.days}'),
          Slider(
            value: budget.days.toDouble(),
            min: 0,
            max: 31,
            divisions: 31,
            label: '${budget.days}',
            onChanged: (v) => budget.setDays(v.round()),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Transport total: ${money(budget.transport)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Fixed expenses ──
  Widget _fixedSection() {
    return SectionCard(
      title: 'Fixed Expenses (Planned)',
      icon: Icons.receipt_long_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in budget.fixed)
            FixedRow(
              key: ValueKey(e.id),
              item: e,
              onChanged: budget.refresh,
              onDelete: () => budget.removeFixed(e),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: budget.addFixed,
              icon: const Icon(Icons.add),
              label: const Text('Add fixed expense'),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Fixed total: ${money(budget.fixedTotal)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Discretionary ──
  Widget _personalSection(BuildContext context) {
    return SectionCard(
      title: 'Personal Expenses (Planned)',
      icon: Icons.local_activity_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final a in budget.activities)
            ActivityRow(
              key: ValueKey(a.id),
              item: a,
              onChanged: budget.refresh,
              onDelete: () => budget.removeActivity(a),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => _addActivity(context),
              icon: const Icon(Icons.add),
              label: const Text('Add custom activity'),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Personal total: ${money(budget.personalTotal)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. Future Goals Fund (based on Net Remaining) ──
  Widget _investmentCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final a = budget.advice;
    final fg = scheme.onTertiaryContainer;
    final icon = switch (a.tier) {
      AdviceTier.noWealth => Icons.info_outline,
      AdviceTier.deficit => Icons.savings_outlined,
      AdviceTier.goalFund => Icons.savings_outlined,
    };

    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: fg),
                const SizedBox(width: 8),
                Text(
                  'Future Goals Fund',
                  style: text.titleMedium?.copyWith(color: fg),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              money(a.amount),
              style: text.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              a.tier == AdviceTier.goalFund
                  ? '${a.percent.toStringAsFixed(1)}% of net remaining • for travel, marriage, savings and other goals'
                  : 'Recommended allocation for travel, marriage, savings and other goals',
              style: TextStyle(color: fg),
            ),
            const SizedBox(height: 8),
            for (final l in a.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l, style: TextStyle(color: fg)),
              ),
            if (a.alert != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.12),
                  border: Border.all(color: scheme.error),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: scheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a.alert!,
                        style: TextStyle(
                          color: scheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── 7. Transaction history ──
  Widget _historySection(BuildContext context) {
    const maxShown = 15;
    final txs = budget.transactions;
    return SectionCard(
      title: 'Recent Transactions',
      icon: Icons.history,
      child: txs.isEmpty
          ? const Text('Nothing logged yet. Tap "Log spend" to add one.')
          : Column(
              children: [
                for (final t in txs.take(maxShown))
                  TransactionTile(
                    key: ValueKey(t.id),
                    tx: t,
                    onDelete: () => _deleteTx(context, t),
                  ),
                if (txs.length > maxShown)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Showing $maxShown of ${txs.length} • swipe left to delete',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Swipe left to delete',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
    );
  }
}
