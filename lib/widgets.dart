import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:financer/helpers.dart';
import 'package:financer/models/models.dart';

extension ExpenseCategoryUi on ExpenseCategory {
  IconData get icon => switch (this) {
        ExpenseCategory.transport => Icons.directions_transit_rounded,
        ExpenseCategory.fixed => Icons.receipt_long_rounded,
        ExpenseCategory.personal => Icons.local_cafe_rounded,
        ExpenseCategory.other => Icons.bolt_rounded,
      };
}

class SectionCard extends StatelessWidget {
  const SectionCard(
      {super.key,
      required this.title,
      required this.icon,
      required this.child,
      this.trailing});
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      shadowColor: scheme.shadow.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side:
              BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: scheme.onPrimaryContainer, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 16),
          child,
        ]),
      ),
    );
  }
}

class BalanceCard extends StatelessWidget {
  const BalanceCard(
      {super.key,
      required this.title,
      required this.value,
      required this.caption,
      this.large = false});
  final String title;
  final double value;
  final String caption;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = value < 0 ? scheme.error : scheme.tertiary;
    final bg = value < 0
        ? scheme.errorContainer.withValues(alpha: 0.55)
        : scheme.primaryContainer;
    final fg = value < 0 ? scheme.onErrorContainer : scheme.onPrimaryContainer;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.all(large ? 20 : 15),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: value < 0
                  ? scheme.error.withValues(alpha: .5)
                  : scheme.primary.withValues(alpha: .10))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text(money(value),
            style: (large
                    ? Theme.of(context).textTheme.headlineMedium
                    : Theme.of(context).textTheme.titleLarge)
                ?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(caption,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: fg.withValues(alpha: .85))),
        if (value < 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: color),
            const SizedBox(width: 6),
            Text('Deficit',
                style: TextStyle(color: color, fontWeight: FontWeight.bold))
          ]),
        ],
      ]),
    );
  }
}

class FixedExpenseEditor extends StatefulWidget {
  const FixedExpenseEditor(
      {super.key,
      required this.item,
      required this.startingWealth,
      required this.totalResources,
      required this.onChanged,
      required this.onDelete});
  final FixedExpense item;
  final double startingWealth;
  final double totalResources;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  State<FixedExpenseEditor> createState() => _FixedExpenseEditorState();
}

class _FixedExpenseEditorState extends State<FixedExpenseEditor> {
  late final TextEditingController _title =
      TextEditingController(text: widget.item.title);
  late final TextEditingController _amount =
      TextEditingController(text: numText(widget.item.amount));
  late final TextEditingController _percent =
      TextEditingController(text: numText(widget.item.percent));

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _percent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final scheme = Theme.of(context).colorScheme;
    final amount = item.effectiveAmount(
        startingWealth: widget.startingWealth,
        totalResources: widget.totalResources);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: .7))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
              item.isInvestment
                  ? Icons.savings_rounded
                  : Icons.receipt_long_outlined,
              size: 20,
              color: item.isInvestment ? scheme.tertiary : scheme.primary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  item.isInvestment ? 'Investment allocation' : 'Fixed expense',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700))),
          if (item.isInvestment)
            const Chip(
                label: Text('Investment'),
                visualDensity: VisualDensity.compact),
          IconButton(
              tooltip: 'Remove item',
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline_rounded)),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
              labelText: item.isInvestment ? 'Allocation name' : 'Expense name',
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          onChanged: (value) {
            item.title = value;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<AllocationMode>(
          initialValue: item.allocationMode,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: 'Allocation type',
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          items: const [
            DropdownMenuItem(
                value: AllocationMode.fixedAmount,
                child: Text('Fixed dollar amount')),
            DropdownMenuItem(
                value: AllocationMode.percentage,
                child: Text('Percentage of wealth / income')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => item.allocationMode = value);
            widget.onChanged();
          },
        ),
        const SizedBox(height: 10),
        if (item.allocationMode == AllocationMode.fixedAmount)
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [numFormatter],
            decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '\$ ',
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12))),
            onChanged: (value) {
              item.amount =
                  parseNum(value).clamp(0, double.infinity).toDouble();
              widget.onChanged();
            },
          )
        else ...[
          Row(children: [
            Expanded(
              child: TextField(
                controller: _percent,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [numFormatter],
                decoration: InputDecoration(
                    labelText: 'Percentage',
                    suffixText: '%',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
                onChanged: (value) {
                  item.percent = parseNum(value).clamp(0, 100).toDouble();
                  widget.onChanged();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<AllocationBasis>(
                initialValue: item.basis,
                isExpanded: true,
                decoration: InputDecoration(
                    labelText: 'Calculate from',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
                items: const [
                  DropdownMenuItem(
                      value: AllocationBasis.wealthAndIncome,
                      child: Text('Wealth + income')),
                  DropdownMenuItem(
                      value: AllocationBasis.startingWealth,
                      child: Text('Starting wealth')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => item.basis = value);
                    widget.onChanged();
                  }
                },
              ),
            ),
          ]),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.calculate_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: 7),
          Expanded(
              child: Text(
                  item.allocationMode == AllocationMode.percentage
                      ? 'Approx. ${item.percent.toStringAsFixed(2)}% = ${money(amount)}'
                      : 'Allocated amount: ${money(amount)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700))),
        ]),
      ]),
    );
  }
}

class ActivityEditor extends StatefulWidget {
  const ActivityEditor(
      {super.key,
      required this.item,
      required this.onChanged,
      required this.onDelete});
  final PersonalActivity item;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  @override
  State<ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends State<ActivityEditor> {
  late final TextEditingController _title =
      TextEditingController(text: widget.item.title);
  late final TextEditingController _cost =
      TextEditingController(text: numText(widget.item.costPerInstance));
  @override
  void dispose() {
    _title.dispose();
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Activity',
                      isDense: true,
                      border: OutlineInputBorder()),
                  onChanged: (v) {
                    item.title = v;
                    widget.onChanged();
                  })),
          IconButton(
              tooltip: 'Remove activity',
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline_rounded)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _cost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [numFormatter],
                  decoration: const InputDecoration(
                      labelText: 'Cost each',
                      prefixText: '\$ ',
                      isDense: true,
                      border: OutlineInputBorder()),
                  onChanged: (v) {
                    item.costPerInstance =
                        parseNum(v).clamp(0, double.infinity).toDouble();
                    widget.onChanged();
                    setState(() {});
                  })),
          const SizedBox(width: 10),
          IconButton.filledTonal(
              onPressed: item.frequency > 0
                  ? () {
                      setState(() => item.frequency =
                          math.max(0, item.frequency - 1).toInt());
                      widget.onChanged();
                    }
                  : null,
              icon: const Icon(Icons.remove)),
          SizedBox(
              width: 28,
              child: Text('${item.frequency}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold))),
          IconButton.filledTonal(
              onPressed: () {
                setState(() => item.frequency =
                    math.min(100000, item.frequency + 1).toInt());
                widget.onChanged();
              },
              icon: const Icon(Icons.add)),
        ]),
        const SizedBox(height: 8),
        Align(
            alignment: Alignment.centerRight,
            child: Text(
                '${item.frequency} × ${money(item.costPerInstance)} = ${money(item.plannedAmount)}',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile(
      {super.key,
      required this.transaction,
      required this.onDelete,
      this.onTap});
  final Transaction transaction;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
              color: scheme.error, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.delete_outline_rounded, color: scheme.onError)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          child: Row(children: [
            CircleAvatar(
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
                child: Icon(transaction.category.icon)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      transaction.note.isEmpty
                          ? transaction.category.label
                          : transaction.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                      '${transaction.category.label} • ${formatDateTime(transaction.dateLogged)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ])),
            const SizedBox(width: 8),
            Text('−${money(transaction.amount)}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.error, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

class IncomeTile extends StatelessWidget {
  const IncomeTile({super.key, required this.entry, required this.onDelete});
  final IncomeEntry entry;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          CircleAvatar(
              backgroundColor: scheme.tertiaryContainer,
              foregroundColor: scheme.onTertiaryContainer,
              child: const Icon(Icons.south_west_rounded)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(entry.category,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                    '${entry.note.isEmpty ? 'Income added' : entry.note} • ${formatDateTime(entry.dateLogged)}',
                    style: Theme.of(context).textTheme.bodySmall)
              ])),
          Text('+${money(entry.amount)}',
              style: TextStyle(
                  color: scheme.tertiary, fontWeight: FontWeight.w800)),
          IconButton(
              tooltip: 'Remove income entry',
              onPressed: onDelete,
              icon: const Icon(Icons.close_rounded, size: 19)),
        ]));
  }
}

class LoanDebtTile extends StatelessWidget {
  const LoanDebtTile(
      {super.key,
      required this.entry,
      required this.onToggle,
      required this.onDelete});
  final LoanDebt entry;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDebt = entry.kind == LoanDebtKind.debtToPay;
    final color = entry.isSettled ? scheme.tertiary : scheme.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(10, 9, 4, 9),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
          color: entry.isSettled
              ? scheme.tertiaryContainer.withValues(alpha: .22)
              : null),
      child: Row(children: [
        Icon(isDebt ? Icons.call_made_rounded : Icons.call_received_rounded,
            color: color),
        const SizedBox(width: 9),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
              '${isDebt ? 'I owe' : 'Owed to me'} • ${entry.note.isEmpty ? formatDateTime(entry.dateLogged) : entry.note}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 5),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                  entry.isSettled
                      ? 'Settled · reflected in net balance'
                      : 'Pending',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700))),
        ])),
        const SizedBox(width: 5),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(money(entry.amount),
              style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          TextButton(
              onPressed: onToggle,
              child: Text(entry.isSettled ? 'Reopen' : 'Settle'))
        ]),
        IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 20)),
      ]),
    );
  }
}
