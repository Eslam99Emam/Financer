import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:financer/helpers.dart';
import 'package:financer/models/models.dart';
import 'package:financer/providers/budget_provider.dart';
import 'package:financer/services/pdf_report_service.dart';
import 'package:financer/services/theme_controller.dart';
import 'package:financer/widgets.dart';

enum _MenuAction { themeSettings, addDebt, managePresets, resetData }

class HomeScreen extends StatefulWidget {
  const HomeScreen(
      {super.key, required this.budget, required this.themeController});
  final BudgetProvider budget;
  final ThemeController themeController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _wealthController =
      TextEditingController(text: numText(widget.budget.wealth));
  late final TextEditingController _dailyCostController =
      TextEditingController(text: numText(widget.budget.dailyCost));
  BudgetProvider get budget => widget.budget;

  @override
  void dispose() {
    _wealthController.dispose();
    _dailyCostController.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _quickLog() async {
    final draft = await showModalBottomSheet<_ExpenseDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _QuickExpenseSheet(),
    );
    if (draft == null) return;
    budget.addTransaction(Transaction(
        id: budget.newId(),
        amount: draft.amount,
        category: draft.category,
        note: draft.note,
        dateLogged: draft.dateLogged));
    _message('Logged ${money(draft.amount)} • ${draft.category.label}');
  }

  void _quickPreset(ExpensePreset preset) {
    if (preset.amount <= 0) {
      _editPreset(existing: preset);
      return;
    }
    budget.addTransaction(Transaction(
      id: budget.newId(),
      amount: preset.amount,
      category: preset.category,
      note: preset.note.trim().isEmpty ? preset.title : preset.note.trim(),
      dateLogged: DateTime.now(),
    ));
    _message('${preset.title} logged • ${money(preset.amount)}');
  }

  Future<void> _showTransactionDetails(Transaction transaction) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(transaction.category.icon, size: 30),
        title: Text(transaction.note.isEmpty
            ? transaction.category.label
            : transaction.note),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount',
                  style: Theme.of(dialogContext).textTheme.labelMedium),
              const SizedBox(height: 2),
              Text('−${money(transaction.amount)}',
                  style: Theme.of(dialogContext)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                          color: Theme.of(dialogContext).colorScheme.error,
                          fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('Category: ${transaction.category.label}'),
              const SizedBox(height: 6),
              Text('Date and time: ${formatDateTime(transaction.dateLogged)}'),
              if (transaction.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Note: ${transaction.note}'),
              ],
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'))
        ],
      ),
    );
  }

  Future<void> _showIncomeDialog() async {
    final draft = await showDialog<_IncomeDraft>(
        context: context, builder: (_) => const _IncomeDialog());
    if (draft == null) return;
    budget.addIncome(IncomeEntry(
        id: budget.newId(),
        amount: draft.amount,
        category: draft.category,
        note: draft.note));
    _message('${money(draft.amount)} added to available resources');
  }

  Future<void> _showDebtDialog() async {
    final draft = await showDialog<_DebtDraft>(
        context: context, builder: (_) => const _DebtDialog());
    if (draft == null) return;
    budget.addObligation(LoanDebt(
        id: budget.newId(),
        title: draft.title,
        amount: draft.amount,
        kind: draft.kind,
        note: draft.note));
  }

  Future<void> _addActivity() async {
    final draft = await showDialog<_ActivityDraft>(
        context: context, builder: (_) => const _ActivityDialog());
    if (draft == null) return;
    budget.addActivity(PersonalActivity(
        id: budget.newId(),
        title: draft.title,
        costPerInstance: draft.amount,
        frequency: draft.frequency));
  }

  Future<void> _editPreset({ExpensePreset? existing}) async {
    final result = await showDialog<_PresetDraft>(
        context: context, builder: (_) => _PresetDialog(existing: existing));
    if (result == null) return;
    if (existing == null) {
      budget.addPreset(ExpensePreset(
          id: budget.newId(),
          title: result.title,
          amount: result.amount,
          category: result.category,
          note: result.note));
    } else {
      budget.updatePreset(ExpensePreset(
          id: existing.id,
          title: result.title,
          amount: result.amount,
          category: result.category,
          note: result.note));
    }
  }

  Future<void> _exportPdf() async {
    try {
      await PdfReportService.shareReport(budget);
    } catch (error) {
      _message('Could not export the report: $error');
    }
  }

  Future<void> _resetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_forever_outlined),
        title: const Text('Reset all finance data?'),
        content: const Text(
            'This removes saved balances, expenses, income entries, presets and loan/debt history from this device. The action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reset everything')),
        ],
      ),
    );
    if (confirmed != true) return;
    await budget.resetAll();
    await widget.themeController.reset();
    _wealthController.clear();
    _dailyCostController.clear();
    if (mounted) _message('All finance data reset.');
  }

  Future<void> _handleMenu(_MenuAction action) async {
    switch (action) {
      case _MenuAction.themeSettings:
        await showDialog<void>(
            context: context,
            builder: (_) =>
                _ThemeSettingsDialog(controller: widget.themeController));
        break;
      case _MenuAction.addDebt:
        await _showDebtDialog();
        break;
      case _MenuAction.managePresets:
        await showDialog<void>(
            context: context,
            builder: (_) => _PresetManagerDialog(
                budget: budget,
                onAdd: () => _editPreset(),
                onEdit: (p) => _editPreset(existing: p)));
        break;
      case _MenuAction.resetData:
        await _resetAll();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: budget,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Personal Finance',
                style: TextStyle(
                    fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            Text('Plan clearly. Track every dollar.',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
          actions: [
            IconButton(
                tooltip: 'Add income',
                onPressed: _showIncomeDialog,
                icon: const Icon(Icons.add_card_rounded)),
            IconButton(
                tooltip: 'Export PDF report',
                onPressed: _exportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined)),
            PopupMenuButton<_MenuAction>(
              tooltip: 'Settings',
              onSelected: _handleMenu,
              itemBuilder: (_) => [
                const PopupMenuItem(enabled: false, child: Text('APPEARANCE')),
                const PopupMenuItem(
                    value: _MenuAction.themeSettings,
                    child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.dark_mode_outlined),
                        title: Text('Theme settings'))),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: _MenuAction.managePresets,
                    child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.bolt_rounded),
                        title: Text('Manage quick presets'))),
                const PopupMenuItem(
                    value: _MenuAction.addDebt,
                    child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.handshake_outlined),
                        title: Text('Add loan or debt'))),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: _MenuAction.resetData,
                    child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading:
                            Icon(Icons.restart_alt_rounded, color: Colors.red),
                        title: Text('Reset all data'))),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _quickLog,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Log expense'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
              children: [
                _overviewSection(),
                const SizedBox(height: 14),
                _surplusSection(),
                const SizedBox(height: 14),
                _presetsSection(),
                const SizedBox(height: 14),
                _incomeSection(),
                const SizedBox(height: 14),
                _transportSection(),
                const SizedBox(height: 14),
                _fixedSection(),
                const SizedBox(height: 14),
                _personalSection(),
                const SizedBox(height: 14),
                _debtSection(),
                const SizedBox(height: 14),
                _distributionSection(),
                const SizedBox(height: 14),
                _varianceSection(),
                const SizedBox(height: 14),
                _historySection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overviewSection() {
    return SectionCard(
      title: 'Your money',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _wealthController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [numFormatter],
          decoration: const InputDecoration(
              labelText: 'Starting wealth',
              prefixText: '\$ ',
              helperText:
                  'Income entries are added separately to this starting amount.'),
          onChanged: (value) => budget.setWealth(parseNum(value)),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: BalanceCard(
                  title: 'Available resources',
                  value: budget.totalResources,
                  caption:
                      'Starting wealth + income and settled loan/debt movements',
                  large: true)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: BalanceCard(
                  title: 'Actual net balance',
                  value: budget.actualRemaining,
                  caption: 'Resources less logged expenses')),
          const SizedBox(width: 10),
          Expanded(
              child: BalanceCard(
                  title: 'Planned remaining',
                  value: budget.plannedRemaining,
                  caption: 'Resources less all planned items')),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _summaryPill(
              Icons.south_west_rounded,
              'Income',
              '+${money(budget.incomeTotal)}',
              Theme.of(context).colorScheme.tertiary),
          _summaryPill(
              Icons.call_made_rounded,
              'Settled debts',
              '-${money(budget.settledDebtsPaid)}',
              Theme.of(context).colorScheme.error),
          _summaryPill(
              Icons.call_received_rounded,
              'Settled loans',
              '+${money(budget.settledLoansCollected)}',
              Theme.of(context).colorScheme.tertiary),
        ]),
      ]),
    );
  }

  Widget _summaryPill(IconData icon, String label, String value, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: .5))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text('$label ', style: Theme.of(context).textTheme.labelMedium),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 12))
        ],
      ),
    );
  }

  Widget _surplusSection() {
    final scheme = Theme.of(context).colorScheme;
    final surplus = budget.unplannedSurplus;
    final ratio = budget.totalResources > 0
        ? (surplus / budget.totalResources).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final indicatorColor = surplus < 0 ? scheme.error : scheme.tertiary;
    return SectionCard(
      title: 'Unplanned / Surplus Buffer',
      icon: Icons.shield_moon_outlined,
      child: Row(children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: ratio),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => SizedBox(
            width: 94,
            height: 94,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                  width: 92,
                  height: 92,
                  child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 8,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: indicatorColor,
                      strokeCap: StrokeCap.round)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${(ratio * 100).round()}%',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text('of funds', style: Theme.of(context).textTheme.labelSmall)
              ]),
            ]),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(money(surplus),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: indicatorColor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(
              surplus >= 0
                  ? 'Unassigned money after planned commitments and actual overspend.'
                  : 'The current plan exceeds available resources. Review commitments or spending.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text('Plan reserve: ${money(budget.projectedTotal)}',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }

  Widget _presetsSection() {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Quick expense presets',
      icon: Icons.bolt_rounded,
      trailing: IconButton(
          tooltip: 'Manage presets',
          onPressed: () => _handleMenu(_MenuAction.managePresets),
          icon: const Icon(Icons.tune_rounded)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tap a preset to log it immediately at the current time.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        if (budget.presets.isEmpty)
          const Text('No presets. Use the tune icon to add one.'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final preset in budget.presets)
            ActionChip(
              avatar: Icon(preset.category.icon, size: 18),
              label: Text('${preset.title} · ${money(preset.amount)}'),
              onPressed: () => _quickPreset(preset),
              side: BorderSide(color: scheme.primary.withValues(alpha: .22)),
              backgroundColor: scheme.secondaryContainer.withValues(alpha: .65),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New preset'),
              onPressed: () => _editPreset(),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
        ]),
      ]),
    );
  }

  Widget _incomeSection() {
    return SectionCard(
      title: 'Income & money in',
      icon: Icons.south_west_rounded,
      trailing: IconButton(
          tooltip: 'Add income',
          onPressed: _showIncomeDialog,
          icon: const Icon(Icons.add_circle_outline_rounded)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('Total additions',
                  style: Theme.of(context).textTheme.bodyMedium)),
          Text('+${money(budget.incomeTotal)}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontWeight: FontWeight.w900,
                  fontSize: 17))
        ]),
        if (budget.incomeEntries.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Divider(),
          for (final entry in budget.incomeEntries.take(5))
            IncomeTile(
                key: ValueKey(entry.id),
                entry: entry,
                onDelete: () => budget.removeIncome(entry.id)),
          if (budget.incomeEntries.length > 5)
            Text(
                '${budget.incomeEntries.length - 5} older entries are included in the total.',
                style: Theme.of(context).textTheme.bodySmall),
        ] else ...[
          const SizedBox(height: 8),
          Text('Log salary, freelance payments, gifts or other cash inflows.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                  onPressed: _showIncomeDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add money'))),
        ],
      ]),
    );
  }

  Widget _transportSection() {
    return SectionCard(
      title: 'Transport plan',
      icon: Icons.directions_transit_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
            controller: _dailyCostController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [numFormatter],
            decoration: const InputDecoration(
                labelText: 'Daily transport cost', prefixText: '\$ '),
            onChanged: (v) => budget.setDailyCost(parseNum(v))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: Text('Active days',
                  style: Theme.of(context).textTheme.titleSmall)),
          Text('${budget.days} days',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800))
        ]),
        Slider(
            value: budget.days.toDouble(),
            min: 0,
            max: 31,
            divisions: 31,
            label: '${budget.days} days',
            onChanged: (v) => budget.setDays(v.round())),
        Align(
            alignment: Alignment.centerRight,
            child: Text('Planned transport: ${money(budget.transport)}',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800))),
      ]),
    );
  }

  Widget _fixedSection() {
    return SectionCard(
      title: 'Fixed costs & investments',
      icon: Icons.receipt_long_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            'Each line can use a fixed amount or a percentage. Percentage values recalculate when income or wealth changes.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (budget.fixed.isEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No fixed costs or investment allocations yet.',
                  style: Theme.of(context).textTheme.bodyMedium)),
        for (final item in budget.fixed)
          FixedExpenseEditor(
              key: ValueKey(item.id),
              item: item,
              startingWealth: budget.wealth,
              totalResources: budget.totalResources,
              onChanged: budget.refresh,
              onDelete: () => budget.removeFixed(item.id)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.tonalIcon(
              onPressed: () => budget.addFixed(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add fixed cost')),
          OutlinedButton.icon(
              onPressed: () => budget.addFixed(investment: true),
              icon: const Icon(Icons.savings_outlined),
              label: const Text('Add investment allocation')),
        ]),
        const SizedBox(height: 12),
        _amountSummary('Fixed costs', budget.fixedTotal),
        const SizedBox(height: 5),
        _amountSummary('Investment allocations', budget.investmentTotal),
        const Divider(height: 20),
        _amountSummary('Fixed + investments total', budget.allFixedTotal,
            strong: true),
      ]),
    );
  }

  Widget _amountSummary(String label, double amount, {bool strong = false}) =>
      Row(children: [
        Expanded(
            child: Text(label,
                style: strong
                    ? Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)
                    : Theme.of(context).textTheme.bodyMedium)),
        Text(money(amount),
            style: strong
                ? Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)
                : Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
      ]);

  Widget _personalSection() {
    return SectionCard(
      title: 'Discretionary expenses',
      icon: Icons.local_activity_rounded,
      trailing: IconButton(
          tooltip: 'Add activity',
          onPressed: _addActivity,
          icon: const Icon(Icons.add_circle_outline_rounded)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (budget.activities.isEmpty) const Text('No discretionary items.'),
        for (final activity in budget.activities)
          ActivityEditor(
              key: ValueKey(activity.id),
              item: activity,
              onChanged: budget.refresh,
              onDelete: () => budget.removeActivity(activity.id)),
        Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
                onPressed: _addActivity,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add activity'))),
        const SizedBox(height: 12),
        _amountSummary('Planned discretionary total', budget.personalTotal,
            strong: true),
      ]),
    );
  }

  Widget _debtSection() {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Loans & debts ledger',
      icon: Icons.handshake_outlined,
      trailing: IconButton(
          tooltip: 'Add loan/debt',
          onPressed: _showDebtDialog,
          icon: const Icon(Icons.add_circle_outline_rounded)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: _debtSummary('I owe', budget.outstandingDebts,
                  scheme.errorContainer, scheme.onErrorContainer)),
          const SizedBox(width: 8),
          Expanded(
              child: _debtSummary('Owed to me', budget.outstandingLoans,
                  scheme.tertiaryContainer, scheme.onTertiaryContainer)),
        ]),
        const SizedBox(height: 12),
        Text(
            'Settled items affect available resources: collecting a loan adds money; paying a debt subtracts money.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        if (budget.obligations.isEmpty)
          Text('No loans or debts recorded.',
              style: Theme.of(context).textTheme.bodyMedium),
        for (final entry in budget.sortedObligations)
          LoanDebtTile(
              key: ValueKey(entry.id),
              entry: entry,
              onToggle: () => budget.toggleObligationSettled(entry.id),
              onDelete: () => budget.removeObligation(entry.id)),
        Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
                onPressed: _showDebtDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add loan or debt'))),
      ]),
    );
  }

  Widget _debtSummary(
          String title, double value, Color background, Color foreground) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    TextStyle(color: foreground, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(money(value),
                style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                    fontSize: 17))
          ],
        ),
      );

  Widget _distributionSection() {
    final scheme = Theme.of(context).colorScheme;
    final sections = <_DistributionPart>[
      _DistributionPart('Fixed', budget.fixedTotal, scheme.primary),
      _DistributionPart('Investments', budget.investmentTotal, scheme.tertiary),
      _DistributionPart('Transport', budget.transport, scheme.secondary),
      _DistributionPart(
          'Discretionary', budget.personalTotal, const Color(0xFFF59E0B)),
    ].where((e) => e.value > 0).toList();
    final total = sections.fold<double>(0, (sum, item) => sum + item.value);
    return SectionCard(
      title: 'Planned expense distribution',
      icon: Icons.donut_large_rounded,
      child: total <= 0
          ? const Text('Add planned costs to see the distribution.')
          : Row(children: [
              SizedBox(
                  width: 116,
                  height: 116,
                  child: CustomPaint(
                      painter: _DistributionPainter(
                          parts: sections.map((e) => e.value).toList(),
                          colors: sections.map((e) => e.color).toList()),
                      child: Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('100%',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        Text('planned',
                            style: Theme.of(context).textTheme.labelSmall)
                      ])))),
              const SizedBox(width: 18),
              Expanded(
                  child: Column(children: [
                for (final part in sections)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: part.color,
                                borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 7),
                        Expanded(
                            child: Text(part.title,
                                style: Theme.of(context).textTheme.bodySmall)),
                        Text('${(part.value / total * 100).round()}%',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        Text(money(part.value),
                            style: Theme.of(context).textTheme.labelMedium)
                      ])),
                const Divider(),
                _amountSummary('Total planned', total, strong: true),
              ])),
            ]),
    );
  }

  Widget _varianceSection() {
    final categories = ExpenseCategory.values
        .where((category) =>
            category != ExpenseCategory.other || budget.actualFor(category) > 0)
        .toList();
    return SectionCard(
      title: 'Planned vs actual',
      icon: Icons.compare_arrows_rounded,
      child: Column(children: [
        for (final category in categories) ...[
          _varianceRow(
              category.label, category.icon, budget.varianceFor(category)),
          const SizedBox(height: 10),
        ],
        const Divider(height: 18),
        _varianceRow('Total', Icons.functions_rounded, budget.totalVariance),
      ]),
    );
  }

  Widget _varianceRow(String label, IconData icon, Variance variance) {
    final scheme = Theme.of(context).colorScheme;
    final isOver = variance.isOver;
    final color = isOver ? scheme.error : scheme.tertiary;
    final ratio = variance.ratio.clamp(0.0, 1.0).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 7),
        Expanded(
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700))),
        Text('${money(variance.actual)} / ${money(variance.planned)}',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 7),
      ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: .15))),
      const SizedBox(height: 4),
      Text(
          isOver
              ? '${money(variance.variance)} over plan'
              : '${money(-variance.variance)} left in plan',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isOver ? scheme.error : scheme.onSurfaceVariant)),
    ]);
  }

  Widget _historySection() {
    final transactions = budget.transactions;
    return SectionCard(
      title: 'Transaction history',
      icon: Icons.history_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('Logged expenses',
                  style: Theme.of(context).textTheme.bodyMedium)),
          Text('${transactions.length} entries',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant))
        ]),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                  'Nothing logged yet. Tap a preset or use Log expense.',
                  style: Theme.of(context).textTheme.bodyMedium)),
        for (final transaction in transactions.take(20))
          TransactionTile(
              key: ValueKey(transaction.id),
              transaction: transaction,
              onDelete: () => budget.removeTransaction(transaction.id),
              onTap: () => _showTransactionDetails(transaction)),
        if (transactions.length > 20)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  'Showing 20 of ${transactions.length} entries. All entries are included in the PDF report.',
                  style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }
}

class _DistributionPart {
  const _DistributionPart(this.title, this.value, this.color);
  final String title;
  final double value;
  final Color color;
}

class _DistributionPainter extends CustomPainter {
  _DistributionPainter({required this.parts, required this.colors});
  final List<double> parts;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final total = parts.fold<double>(0, (sum, e) => sum + e);
    if (total <= 0) return;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    var start = -1.57079632679;
    for (var i = 0; i < parts.length; i++) {
      final sweep = (parts[i] / total) * 6.28318530718;
      paint.color = colors[i];
      canvas.drawArc(rect.deflate(9), start, sweep - .035, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DistributionPainter oldDelegate) =>
      oldDelegate.parts != parts || oldDelegate.colors != colors;
}

class _ThemeSettingsDialog extends StatelessWidget {
  const _ThemeSettingsDialog({required this.controller});
  final ThemeController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => AlertDialog(
          title: const Text('Appearance'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark mode'),
              subtitle: const Text('Quickly switch between light and dark'),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (isDark) =>
                  controller.setMode(isDark ? ThemeMode.dark : ThemeMode.light),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ThemeMode>(
              initialValue: controller.mode,
              decoration: const InputDecoration(labelText: 'Theme mode'),
              items: const [
                DropdownMenuItem(
                    value: ThemeMode.system, child: Text('System default')),
                DropdownMenuItem(
                    value: ThemeMode.light, child: Text('Always light')),
                DropdownMenuItem(
                    value: ThemeMode.dark, child: Text('Always dark')),
              ],
              onChanged: (mode) {
                if (mode != null) controller.setMode(mode);
              },
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'))
          ],
        ),
      );
}

class _ExpenseDraft {
  const _ExpenseDraft(
      {required this.amount,
      required this.category,
      required this.note,
      required this.dateLogged});
  final double amount;
  final ExpenseCategory category;
  final String note;
  final DateTime dateLogged;
}

class _QuickExpenseSheet extends StatefulWidget {
  const _QuickExpenseSheet();
  @override
  State<_QuickExpenseSheet> createState() => _QuickExpenseSheetState();
}

class _QuickExpenseSheetState extends State<_QuickExpenseSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.transport;
  DateTime _dateLogged = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
        context: context,
        initialDate: _dateLogged,
        firstDate: DateTime(2000),
        lastDate: DateTime.now());
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_dateLogged));
    if (pickedTime == null || !mounted) return;
    setState(() => _dateLogged = DateTime(pickedDate.year, pickedDate.month,
        pickedDate.day, pickedTime.hour, pickedTime.minute));
  }

  void _submit() {
    final amount = parseNum(_amountController.text);
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    Navigator.pop(
        context,
        _ExpenseDraft(
            amount: amount,
            category: _category,
            note: _noteController.text.trim(),
            dateLogged: _dateLogged));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Padding(
      padding: EdgeInsets.fromLTRB(
          18, 4, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text('Log expense',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [numFormatter],
                decoration: InputDecoration(
                    labelText: 'Amount', prefixText: '\$ ', errorText: _error),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                }),
            const SizedBox(height: 12),
            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final category in ExpenseCategory.values)
                ChoiceChip(
                    avatar: Icon(category.icon, size: 17),
                    label: Text(category.label),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category))
            ]),
            const SizedBox(height: 12),
            TextField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration:
                    const InputDecoration(labelText: 'Note (optional)')),
            const SizedBox(height: 10),
            Row(children: [
              TextButton.icon(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(formatDateTime(_dateLogged))),
              const Spacer(),
              FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save expense'))
            ]),
          ])),
    ));
  }
}

class _IncomeDraft {
  const _IncomeDraft(this.amount, this.category, this.note);
  final double amount;
  final String category;
  final String note;
}

class _IncomeDialog extends StatefulWidget {
  const _IncomeDialog();
  @override
  State<_IncomeDialog> createState() => _IncomeDialogState();
}

class _IncomeDialogState extends State<_IncomeDialog> {
  final _amount = TextEditingController();
  final _category = TextEditingController(text: 'Salary');
  final _note = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    _category.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add money / income'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [numFormatter],
              decoration: InputDecoration(
                  labelText: 'Amount', prefixText: '\$ ', errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              }),
          const SizedBox(height: 10),
          TextField(
              controller: _category,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Category (e.g. Salary, Freelance)')),
          const SizedBox(height: 10),
          TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (optional)')),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final amount = parseNum(_amount.text);
                if (amount <= 0 || _category.text.trim().isEmpty) {
                  setState(
                      () => _error = 'Enter a positive amount and category.');
                  return;
                }
                Navigator.pop(
                    context,
                    _IncomeDraft(
                        amount, _category.text.trim(), _note.text.trim()));
              },
              child: const Text('Add income'))
        ],
      );
}

class _DebtDraft {
  const _DebtDraft(this.title, this.amount, this.kind, this.note);
  final String title;
  final double amount;
  final LoanDebtKind kind;
  final String note;
}

class _DebtDialog extends StatefulWidget {
  const _DebtDialog();
  @override
  State<_DebtDialog> createState() => _DebtDialogState();
}

class _DebtDialogState extends State<_DebtDialog> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  LoanDebtKind _kind = LoanDebtKind.debtToPay;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add loan or debt'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<LoanDebtKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Ledger type'),
              items: const [
                DropdownMenuItem(
                    value: LoanDebtKind.debtToPay, child: Text('Money I owe')),
                DropdownMenuItem(
                    value: LoanDebtKind.loanToCollect,
                    child: Text('Money owed to me'))
              ],
              onChanged: (v) {
                if (v != null) setState(() => _kind = v);
              }),
          const SizedBox(height: 10),
          TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(labelText: 'Person / description')),
          const SizedBox(height: 10),
          TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [numFormatter],
              decoration: InputDecoration(
                  labelText: 'Amount', prefixText: '\$ ', errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              }),
          const SizedBox(height: 10),
          TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (optional)')),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final amount = parseNum(_amount.text);
                if (_title.text.trim().isEmpty || amount <= 0) {
                  setState(() => _error = 'Enter a title and positive amount.');
                  return;
                }
                Navigator.pop(
                    context,
                    _DebtDraft(
                        _title.text.trim(), amount, _kind, _note.text.trim()));
              },
              child: const Text('Add entry'))
        ],
      );
}

class _ActivityDraft {
  const _ActivityDraft(this.title, this.amount, this.frequency);
  final String title;
  final double amount;
  final int frequency;
}

class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog();
  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _frequency = TextEditingController(text: '1');
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _frequency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add discretionary expense'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [numFormatter],
              decoration: const InputDecoration(
                  labelText: 'Cost per instance', prefixText: '\$ ')),
          const SizedBox(height: 10),
          TextField(
              controller: _frequency,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                  labelText: 'Planned frequency', errorText: _error)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (_title.text.trim().isEmpty) {
                  setState(() => _error = 'Enter a name.');
                  return;
                }
                Navigator.pop(
                    context,
                    _ActivityDraft(
                        _title.text.trim(),
                        parseNum(_amount.text)
                            .clamp(0, double.infinity)
                            .toDouble(),
                        (int.tryParse(_frequency.text) ?? 0)
                            .clamp(0, 100000)
                            .toInt()));
              },
              child: const Text('Add activity'))
        ],
      );
}

class _PresetDraft {
  const _PresetDraft(this.title, this.amount, this.category, this.note);
  final String title;
  final double amount;
  final ExpenseCategory category;
  final String note;
}

class _PresetDialog extends StatefulWidget {
  const _PresetDialog({this.existing});
  final ExpensePreset? existing;
  @override
  State<_PresetDialog> createState() => _PresetDialogState();
}

class _PresetDialogState extends State<_PresetDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _amount = TextEditingController(
      text: widget.existing == null ? '' : numText(widget.existing!.amount));
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');
  late ExpenseCategory _category =
      widget.existing?.category ?? ExpenseCategory.personal;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.existing == null
            ? 'Create expense preset'
            : 'Edit expense preset'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Preset name')),
          const SizedBox(height: 10),
          TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [numFormatter],
              decoration: InputDecoration(
                  labelText: 'Amount', prefixText: '\$ ', errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              }),
          const SizedBox(height: 10),
          DropdownButtonFormField<ExpenseCategory>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Expense category'),
              items: [
                for (final c in ExpenseCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label))
              ],
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              }),
          const SizedBox(height: 10),
          TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Transaction note (optional)')),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final amount = parseNum(_amount.text);
                if (_title.text.trim().isEmpty || amount <= 0) {
                  setState(() =>
                      _error = 'Enter a name and amount greater than zero.');
                  return;
                }
                Navigator.pop(
                    context,
                    _PresetDraft(_title.text.trim(), amount, _category,
                        _note.text.trim()));
              },
              child: const Text('Save preset'))
        ],
      );
}

class _PresetManagerDialog extends StatelessWidget {
  const _PresetManagerDialog(
      {required this.budget, required this.onAdd, required this.onEdit});
  final BudgetProvider budget;
  final VoidCallback onAdd;
  final ValueChanged<ExpensePreset> onEdit;
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Quick expense presets'),
        content: SizedBox(
            width: 420,
            child: AnimatedBuilder(
                animation: budget,
                builder: (context, _) => budget.presets.isEmpty
                    ? const Text('No presets are configured.')
                    : SizedBox(
                        width: double.maxFinite,
                        child: ListView(shrinkWrap: true, children: [
                          for (final preset in budget.presets)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                  child: Icon(preset.category.icon)),
                              title: Text(preset.title),
                              subtitle: Text(
                                  '${preset.category.label} · ${money(preset.amount)}'),
                              trailing: PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      onEdit(preset);
                                    }
                                    if (action == 'delete') {
                                      budget.removePreset(preset.id);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: 'edit', child: Text('Edit')),
                                        PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete'))
                                      ]),
                            )
                        ])))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done')),
          FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add preset'))
        ],
      );
}
