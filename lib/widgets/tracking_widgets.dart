import 'package:financer/helpers.dart';
import 'package:financer/models/models.dart';
import 'package:flutter/material.dart';

extension ExpenseCategoryUi on ExpenseCategory {
  IconData get icon => switch (this) {
    ExpenseCategory.transport => Icons.directions_bus_outlined,
    ExpenseCategory.fixed => Icons.receipt_long_outlined,
    ExpenseCategory.personal => Icons.local_activity_outlined,
    ExpenseCategory.other => Icons.help_outline,
  };
}

// ── Balance card (green/primary when >= 0, bold red + warning when < 0) ──
class BalanceCard extends StatelessWidget {
  final String title;
  final double value;
  final String caption;
  final bool large;

  const BalanceCard({
    super.key,
    required this.title,
    required this.value,
    required this.caption,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final deficit = value < 0;
    final red = Colors.red.shade700;
    final bg = large ? scheme.primaryContainer : scheme.secondaryContainer;
    final onBg = large ? scheme.onPrimaryContainer : scheme.onSecondaryContainer;
    final fg = deficit ? red : onBg;

    return Card(
      margin: EdgeInsets.zero,
      color: deficit ? Colors.red.shade50 : bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: deficit ? BorderSide(color: red, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: EdgeInsets.all(large ? 20 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleMedium?.copyWith(color: fg)),
            const SizedBox(height: 4),
            Text(
              money(value),
              style: (large ? text.displaySmall : text.titleLarge)?.copyWith(
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
            const SizedBox(height: 6),
            Text(caption, style: TextStyle(color: fg)),
            if (deficit) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: red),
                  const SizedBox(width: 8),
                  Text(
                    'Budget Deficit',
                    style: TextStyle(
                      color: red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Planned vs Actual bar (green = within budget, red = exceeded) ──
class VarianceBar extends StatelessWidget {
  final String label;
  final IconData icon;
  final Variance variance;

  const VarianceBar({
    super.key,
    required this.label,
    required this.icon,
    required this.variance,
  });

  @override
  Widget build(BuildContext context) {
    final over = variance.isOver;
    final color = over ? Colors.red.shade700 : Colors.green.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: over ? Colors.red.withValues(alpha: 0.08) : null,
        border: Border.all(
          color: over
              ? Colors.red.shade700
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: over ? color : null),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: over ? color : null,
                ),
              ),
              const Spacer(),
              Text(
                '${money(variance.actual)} / ${money(variance.planned)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: variance.ratio.clamp(0.0, 1.0),
              minHeight: 10,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 6),
          if (over)
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: color),
                const SizedBox(width: 4),
                Text(
                  '+${money(variance.variance)} Over Budget',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            )
          else
            Text(
              '${money(-variance.variance)} left',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

// ── Dismissible history row ──
class TransactionTile extends StatelessWidget {
  final Transaction tx;
  final VoidCallback onDelete;

  const TransactionTile({super.key, required this.tx, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: Colors.red.shade700,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(child: Icon(tx.category.icon)),
        title: Text(tx.note.isEmpty ? tx.category.label : tx.note),
        subtitle: Text('${tx.category.label} • ${dayLabel(tx.date)}'),
        trailing: Text(
          '-${money(tx.amount)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ── Quick-log modal bottom sheet ──
class QuickLogSheet extends StatefulWidget {
  final String id;
  const QuickLogSheet({super.key, required this.id});

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.transport;
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final p = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (p != null) {
      setState(
        () => _date = DateTime(
          p.year,
          p.month,
          p.day,
          now.hour,
          now.minute,
          now.second,
        ),
      );
    }
  }

  void _submit() {
    final amount = parseNum(_amount.text);
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    Navigator.pop(
      context,
      Transaction(
        id: widget.id,
        amount: amount,
        category: _category,
        date: _date,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Log spending', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [numFormatter],
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '\$ ',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final c in ExpenseCategory.values)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18),
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (e.g. Extra Transport)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(dayLabel(_date)),
                ),
                const Spacer(),
                FilledButton(onPressed: _submit, child: const Text('Add')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
