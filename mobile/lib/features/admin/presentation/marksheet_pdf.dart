import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';

class MarksheetPdf {
  static Future<void> printMarksheet({
    required Map<String, dynamic> marksData,
    required Map<String, dynamic> student,
    required String academicYear,
  }) async {
    final pdfDoc = await _buildPdf(
      marksData: marksData,
      student: student,
      academicYear: academicYear,
    );
    
    final studentName = student['full_name'] ?? student['name'] ?? 'Student';
    await Printing.sharePdf(
      bytes: pdfDoc,
      filename: 'Marksheet_${studentName.replaceAll(' ', '_')}_$academicYear.pdf',
    );
  }

  static Future<Uint8List> _buildPdf({
    required Map<String, dynamic> marksData,
    required Map<String, dynamic> student,
    required String academicYear,
  }) async {
    final pdf = pw.Document();

    // Load logo asset
    final logoBytes = await rootBundle.load('assets/images/sunkidz_logo_hd.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final studentName = student['full_name'] ?? student['name'] ?? 'N/A';
    final admissionNumber = student['admission_number'] ?? 'N/A';
    final className = student['standard'] ?? student['class_name'] ?? 'N/A';

    final marksMap = (marksData['data'] as Map<String, dynamic>?) ?? {};

    // Colors
    const primaryBlue = PdfColor.fromInt(0xFF1565C0);
    const accentGold = PdfColor.fromInt(0xFFFFA000);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(logoImage, width: 80, height: 80),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('SUNKIDZ PRE-SCHOOL',
                        style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryBlue)),
                    pw.Text('LMS Academic Report',
                        style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                    pw.Text('Academic Year: $academicYear',
                        style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: accentGold, thickness: 2),
            pw.SizedBox(height: 20),

            // ── Student Info ─────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _infoRow('Student Name', studentName),
                        _infoRow('Admission No', admissionNumber),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _infoRow('Class/Standard', className),
                        _infoRow('Report Date', DateFormat('dd MMM yyyy').format(DateTime.now())),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // ── Marks Table ──────────────────────────────────────
            pw.Text('ACADEMIC EVALUATION',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryBlue)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(1),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                  children: [
                    _cell('Subject / Assessment Area', bold: true),
                    _cell('Max Marks', bold: true, align: pw.Alignment.center),
                    _cell('Marks Obtained', bold: true, align: pw.Alignment.center),
                    _cell('Grade', bold: true, align: pw.Alignment.center),
                  ],
                ),
                // Data
                ...marksMap.entries.map((e) {
                  final data = e.value as Map<String, dynamic>;
                  return pw.TableRow(
                    children: [
                      _cell(e.key),
                      _cell(data['total']?.toString() ?? '100', align: pw.Alignment.center),
                      _cell(data['marks']?.toString() ?? '0', align: pw.Alignment.center, bold: true),
                      _cell(data['grade']?.toString() ?? '—', align: pw.Alignment.center, color: PdfColors.green700, bold: true),
                    ],
                  );
                }),
              ],
            ),
            
            pw.Spacer(),

            // ── Footer ───────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.SizedBox(height: 40),
                    pw.Container(width: 120, height: 0.5, color: PdfColors.black),
                    pw.Text('Class Teacher', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.SizedBox(height: 40),
                    pw.Container(width: 120, height: 0.5, color: PdfColors.black),
                    pw.Text('Principal / Head', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.Center(
              child: pw.Text(
                'Sunkidz LMS - Building Bright Futures Together',
                style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 100, child: pw.Text('$label:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _cell(String text, {bool bold = false, pw.Alignment align = pw.Alignment.centerLeft, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Align(
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ),
    );
  }
}
