// ───────────────────────── Widgets ─────────────────────────

import 'dart:math' as math;

import 'package:financer/helpers.dart';
import 'package:financer/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class FixedRow extends StatefulWidget {
  final FixedExpense item;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  const FixedRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<FixedRow> createState() => _FixedRowState();
}

class _FixedRowState extends State<FixedRow> {
  late final TextEditingController _title = TextEditingController(
    text: widget.item.title,
  );
  late final TextEditingController _amount = TextEditingController(
    text: numText(widget.item.amount),
  );

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Name (e.g. Rent)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                widget.item.title = v;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [numFormatter],
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) {
                widget.item.amount = parseNum(v);
                widget.onChanged();
              },
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline),
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}

class ActivityRow extends StatefulWidget {
  final PersonalActivity item;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  const ActivityRow({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<ActivityRow> createState() => _ActivityRowState();
}

class _ActivityRowState extends State<ActivityRow> {
  late final TextEditingController _cost = TextEditingController(
    text: numText(widget.item.costPerInstance),
  );

  @override
  void dispose() {
    _cost.dispose();
    super.dispose();
  }

  void _setFreq(int f) {
    widget.item.frequency = math.max(0, f);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.item;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _cost,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [numFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Cost each',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    a.costPerInstance = parseNum(v);
                    widget.onChanged();
                  },
                ),
              ),
              const Spacer(),
              IconButton.filledTonal(
                icon: const Icon(Icons.remove),
                onPressed: a.frequency > 0
                    ? () => _setFreq(a.frequency - 1)
                    : null,
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${a.frequency}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.add),
                onPressed: () => _setFreq(a.frequency + 1),
              ),
              const SizedBox(width: 8),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${a.frequency} × ${money(a.costPerInstance)} = ${money(a.costPerInstance * a.frequency)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddActivityDialog extends StatefulWidget {
  final String id;
  const AddActivityDialog({super.key, required this.id});

  @override
  State<AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<AddActivityDialog> {
  final _title = TextEditingController();
  final _cost = TextEditingController();
  final _freq = TextEditingController(text: '1');

  @override
  void dispose() {
    _title.dispose();
    _cost.dispose();
    _freq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New activity'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: _cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [numFormatter],
            decoration: const InputDecoration(
              labelText: 'Cost per instance',
              prefixText: '\$ ',
            ),
          ),
          TextField(
            controller: _freq,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Frequency'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _title.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              PersonalActivity(
                id: widget.id,
                title: name,
                costPerInstance: parseNum(_cost.text),
                frequency: int.tryParse(_freq.text) ?? 0,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
