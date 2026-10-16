import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:financer/helpers.dart';
import 'package:financer/models/models.dart';
import 'package:financer/providers/budget_provider.dart';

class PdfReportService {
  static Future<void> shareReport(BudgetProvider budget) async {
    final bytes = await _buildReport(budget);
    await Printing.sharePdf(
        bytes: bytes, filename: 'personal_finance_report.pdf');
  }

  static Future<Uint8List> _buildReport(BudgetProvider budget) async {
    final document = pw.Document();
    final now = DateTime.now();
    final fixedRows = <List<String>>[
      ['Item', 'Allocation', 'Estimated amount'],
      ...budget.fixed.map((item) {
        final description = item.allocationMode == AllocationMode.fixedAmount
            ? 'Fixed amount'
            : '${item.percent.toStringAsFixed(2)}% of ${item.basis == AllocationBasis.startingWealth ? 'starting wealth' : 'wealth + income'}';
        return [
          '${item.isInvestment ? 'Investment · ' : ''}${item.title.isEmpty ? 'Untitled' : item.title}',
          description,
          money(budget.effectiveFixed(item)),
        ];
      }),
      [
        'Transport',
        '${money(budget.dailyCost)} per day × ${budget.days} days',
        money(budget.transport)
      ],
      ...budget.activities.map((item) => [
            item.title,
            '${item.frequency} × ${money(item.costPerInstance)}',
            money(item.plannedAmount)
          ]),
    ];

    String netDescription(LoanDebt entry) =>
        '${entry.kind == LoanDebtKind.debtToPay ? 'Debt to pay' : 'Loan to collect'} · ${entry.isSettled ? 'Settled' : 'Pending'}';
    final debtRows = <List<String>>[
      ['Item', 'Type / status', 'Amount'],
      ...budget.sortedObligations
          .map((e) => [e.title, netDescription(e), money(e.amount)]),
    ];

    final summaryRows = <List<String>>[
      ['Starting wealth', money(budget.wealth)],
      ['Income additions', money(budget.incomeTotal)],
      ['Settled loans collected', money(budget.settledLoansCollected)],
      ['Settled debts paid', '-${money(budget.settledDebtsPaid)}'],
      ['Total available resources', money(budget.totalResources)],
      ['Fixed costs', money(budget.fixedTotal)],
      ['Investment allocations', money(budget.investmentTotal)],
      ['Planned transport', money(budget.transport)],
      ['Planned discretionary', money(budget.personalTotal)],
      ['Projected expenses reserved', money(budget.projectedTotal)],
      ['Outstanding debts (pending)', money(budget.outstandingDebts)],
      ['Outstanding loans (pending)', money(budget.outstandingLoans)],
      ['Final net balance (actual)', money(budget.actualRemaining)],
      ['Unplanned / surplus buffer', money(budget.unplannedSurplus)],
    ];

    pw.Widget table(List<List<String>> rows, {bool header = true}) =>
        pw.TableHelper.fromTextArray(
          data: rows,
          headerCount: header ? 1 : 0,
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F766E)),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
          oddRowDecoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F8FA)),
        );

    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(34),
      theme: pw.ThemeData.withFont(),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
      ),
      build: (context) => [
        pw.Text('Personal Finance Report',
            style: const pw.TextStyle(
                fontSize: 23,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF0F766E))),
        pw.SizedBox(height: 5),
        pw.Text('Generated ${formatDateTime(now)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        pw.Text('Overview',
            style: const pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 7),
        table(summaryRows, header: false),
        pw.SizedBox(height: 16),
        pw.Text('Itemized plan',
            style: const pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 7),
        table(fixedRows),
        pw.SizedBox(height: 16),
        pw.Text('Loans and debts ledger',
            style: const pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 7),
        debtRows.length > 1
            ? table(debtRows)
            : pw.Text('No loans or debts recorded.',
                style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 16),
        pw.Text('Income additions',
            style: const pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 7),
        budget.incomeEntries.isEmpty
            ? pw.Text('No income entries recorded.',
                style: const pw.TextStyle(fontSize: 9))
            : table([
                ['Category', 'Note', 'Logged at', 'Amount'],
                ...budget.incomeEntries.map((e) => [
                      e.category,
                      e.note,
                      formatDateTime(e.dateLogged),
                      money(e.amount)
                    ]),
              ]),
        pw.SizedBox(height: 16),
        pw.Text('Expense history',
            style: const pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 7),
        budget.transactions.isEmpty
            ? pw.Text('No expenses recorded.',
                style: const pw.TextStyle(fontSize: 9))
            : table([
                ['Item / note', 'Category', 'Logged at', 'Amount'],
                ...budget.transactions.map((e) => [
                      e.note.isEmpty ? e.category.label : e.note,
                      e.category.label,
                      formatDateTime(e.dateLogged),
                      money(e.amount)
                    ]),
              ]),
        pw.SizedBox(height: 12),
        pw.Text(
            'Planning note: the surplus reserves the higher of planned or actual expenses per category. Settled receivables increase available resources; settled debts paid decrease them.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
    ));
    return document.save();
  }
}
