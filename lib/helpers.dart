import 'package:flutter/services.dart';

double parseNum(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

String money(double value) =>
    '${value < 0 ? '-' : ''}\$${value.abs().toStringAsFixed(2)}';

String compactMoney(double value) {
  final abs = value.abs();
  final prefix = value < 0 ? '-\$' : '\$';
  if (abs >= 1000000) return '$prefix${(abs / 1000000).toStringAsFixed(1)}m';
  if (abs >= 10000) return '$prefix${(abs / 1000).toStringAsFixed(1)}k';
  return money(value);
}

final numFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
const monthShortNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

String formatDateTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${monthShortNames[date.month - 1]} ${date.day}, $hour:$minute $period';
}

String formatDate(DateTime date) =>
    '${monthShortNames[date.month - 1]} ${date.day}, ${date.year}';
String numText(double value) => value == 0
    ? ''
    : (value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString());

/// Compatibility helper retained for legacy widgets that use calendar labels.
String dayLabel(DateTime date) {
  final now = DateTime.now();
  final dateOnly = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(dateOnly).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return formatDateTime(date);
}
