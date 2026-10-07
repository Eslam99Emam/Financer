// ───────────────────────── Helpers ─────────────────────────

import 'package:flutter/services.dart';

double parseNum(String v) => double.tryParse(v.trim().replaceAll(',', '.')) ?? 0;

String money(double v) => '${v < 0 ? '-' : ''}\$${v.abs().toStringAsFixed(2)}';

final numFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String dayLabel(DateTime d) {
  final now = DateTime.now();
  final a = DateTime.utc(d.year, d.month, d.day);
  final t = DateTime.utc(now.year, now.month, now.day);
  final diff = t.difference(a).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${_months[d.month - 1]} ${d.day}';
}

/// Text for a numeric field: '' for 0, no trailing ".0" for whole numbers.
String numText(double v) {
  if (v == 0) return '';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
