import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

class FeeReceiptPdf {
  static const _componentLabels = {
    'advance_fees': 'Advance Fees',
    'term_fee_1': 'Term Fee 1',
    'term_fee_2': 'Term Fee 2',
    'term_fee_3': 'Term Fee 3',
  };

  static const _modeLabels = {
    'cash': 'Cash',
    'upi': 'UPI',
    'net_banking': 'Net Banking',
    'cheque': 'Cheque',
    'bank_transfer': 'Bank Transfer',
  };

  /// Build and show a printable/shareable PDF receipt for a single payment.
  static Future<void> printReceipt({
    required Map<String, dynamic> payment,
    required Map<String, dynamic> feeData,
    required Map<String, dynamic>? student,
  }) async {
    final pdfDoc = await _buildPdf(payment: payment, feeData: feeData, student: student);
    final receiptRef = (payment['id']?.toString() ?? '').isNotEmpty
        ? payment['id'].toString().substring(0, 8).toUpperCase()
        : 'RECEIPT';
    await Printing.layoutPdf(
      onLayout: (_) async => pdfDoc,
      name: 'Sunkidz_Fee_Receipt_$receiptRef.pdf',
    );
  }

  static Future<Uint8List> _buildPdf({
    required Map<String, dynamic> payment,
    required Map<String, dynamic> feeData,
    required Map<String, dynamic>? student,
  }) async {
    final pdf = pw.Document();

    // Load logo asset
    final logoBytes = await rootBundle.load('assets/images/new_logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // Derived values
    final component = payment['component'] as String? ?? '';
    final componentLabel = _componentLabels[component] ?? component;
    final modeLabel = _modeLabels[payment['payment_mode']] ?? payment['payment_mode'] ?? '';
    final amountPaid = (payment['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final paymentDateRaw = payment['payment_date'] as String?;
    final paymentDateStr = paymentDateRaw != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(paymentDateRaw))
        : 'N/A';
    final createdAtRaw = payment['created_at'] as String?;
    final createdAtStr = createdAtRaw != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(createdAtRaw))
        : 'N/A';

    final studentName =
        student?['full_name'] ?? student?['name'] ?? feeData['student_name'] ?? 'N/A';
    final admissionNumber =
        student?['admission_number'] ?? feeData['admission_number'] ?? 'N/A';
    final receiptRef = (payment['id']?.toString() ?? '').isNotEmpty
        ? payment['id'].toString().substring(0, 8).toUpperCase()
        : 'N/A';

    final totalDue = (feeData['total_due'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = (feeData['total_paid'] as num?)?.toDouble() ?? 0.0;
    final totalBalance = (feeData['total_balance'] as num?)?.toDouble() ?? 0.0;

    // Per-component details for history table
    final rows = [
      _feeRow('Advance Fees', feeData['advance_fees'], feeData['advance_fees_paid'],
          feeData['advance_fees_balance']),
      _feeRow('Term Fee 1', feeData['term_fee_1'], feeData['term_fee_1_paid'],
          feeData['term_fee_1_balance']),
      _feeRow('Term Fee 2', feeData['term_fee_2'], feeData['term_fee_2_paid'],
          feeData['term_fee_2_balance']),
      _feeRow('Term Fee 3', feeData['term_fee_3'], feeData['term_fee_3_paid'],
          feeData['term_fee_3_balance']),
    ];

    // Brand colours
    const headerBlue = PdfColor.fromInt(0xFF1565C0);
    const accentOrange = PdfColor.fromInt(0xFFFF8F00);

    final moneyFmt = NumberFormat('#,##0.00', 'en_IN');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────
            pw.Container(
              decoration: pw.BoxDecoration(
                color: headerBlue,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: pw.Center(
                child: pw.Image(logoImage, width: 96, height: 96),
              ),
            ),
            pw.SizedBox(height: 6),

            // ── Receipt banner ───────────────────────────────────
            pw.Container(
              color: accentOrange,
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'FEE RECEIPT',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('Receipt No: #$receiptRef',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Issued: $createdAtStr',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // ── Student details ──────────────────────────────────
            _section(
              title: 'Student Details',
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _detailRow('Name', studentName),
                        pw.SizedBox(height: 4),
                        _detailRow('Admission No', admissionNumber),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _detailRow('Payment Date', paymentDateStr),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // ── Payment details ──────────────────────────────────
            _section(
              title: 'Payment Details',
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(1.5),
                },
                children: [
                  _tableHeaderRow(['Component', 'Amount Paid', 'Payment Mode']),
                  _tableDataRow([
                    componentLabel,
                    'Rs. ${moneyFmt.format(amountPaid)}',
                    modeLabel,
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // ── Fee summary ──────────────────────────────────────
            _section(
              title: 'Fee Summary',
              child: pw.Column(
                children: [
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(2),
                      1: pw.FlexColumnWidth(1),
                      2: pw.FlexColumnWidth(1),
                      3: pw.FlexColumnWidth(1),
                    },
                    children: [
                      _tableHeaderRow(['Component', 'Due (Rs.)', 'Paid (Rs.)', 'Balance (Rs.)']),
                      ...rows,
                      // Total row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          _cell('TOTAL', bold: true),
                          _cell('Rs. ${moneyFmt.format(totalDue)}', bold: true),
                          _cell('Rs. ${moneyFmt.format(totalPaid)}', bold: true),
                          _cell('Rs. ${moneyFmt.format(totalBalance)}',
                              bold: true,
                              color: totalBalance > 0 ? PdfColors.red700 : PdfColors.green700),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.Spacer(),

            // ── Footer ───────────────────────────────────────────
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                'This is a computer-generated receipt and does not require a physical signature.',
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Thank you for choosing Sunkidz! 🌟',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: headerBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static pw.Widget _section({required String title, required pw.Widget child}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            color: PdfColors.grey100,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: pw.Text(
              title,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            child: child,
          ),
        ],
      ),
    );
  }

  static pw.Widget _detailRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Flexible(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  static pw.TableRow _tableHeaderRow(List<String> labels) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
      children: labels
          .map((l) => _cell(l, bold: true))
          .toList(),
    );
  }

  static pw.TableRow _tableDataRow(List<String> values) {
    return pw.TableRow(
      children: values.map((v) => _cell(v)).toList(),
    );
  }

  static pw.TableRow _feeRow(String label, dynamic due, dynamic paid, dynamic balance) {
    final d = (due as num?)?.toDouble() ?? 0.0;
    final p = (paid as num?)?.toDouble() ?? 0.0;
    final b = (balance as num?)?.toDouble() ?? 0.0;
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    return pw.TableRow(
      children: [
        _cell(label),
        _cell('Rs. ${fmt.format(d)}'),
        _cell('Rs. ${fmt.format(p)}'),
        _cell('Rs. ${fmt.format(b)}',
            color: b > 0 ? PdfColors.red700 : PdfColors.green700),
      ],
    );
  }

  static pw.Widget _cell(String text,
      {bool bold = false, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }
}
