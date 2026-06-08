import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/models/connection_details.dart';
import 'package:frontend/models/financial_transaction.dart';
import 'package:frontend/utils/file_bytes_saver.dart';
import 'package:frontend/utils/financial_transaction_utils.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StatementExportRequest {
  final Set<DisplayTransactionType> selectedTypes;
  final DateTime? startDate;
  final DateTime? endDate;

  const StatementExportRequest({
    required this.selectedTypes,
    this.startDate,
    this.endDate,
  });

  bool includes(FinancialTransaction transaction) {
    final matchesType = selectedTypes.contains(transaction.displayType);
    final matchesStart =
        startDate == null || !transaction.transactionDate.isBefore(startDate!);
    final matchesEnd =
        endDate == null || !transaction.transactionDate.isAfter(endDate!);
    return matchesType && matchesStart && matchesEnd;
  }
}

class StatementExportResult {
  final String fileName;
  final String? savedPath;
  final bool browserDownload;

  const StatementExportResult({
    required this.fileName,
    this.savedPath,
    required this.browserDownload,
  });

  String get locationLabel {
    if (browserDownload) {
      return 'Tarayıcı indirilenleri';
    }
    return savedPath ?? fileName;
  }
}

class StatementPdfService {
  Future<StatementExportResult?> createAndSave({
    required ConnectionDetails person,
    required List<FinancialTransaction> transactions,
    required StatementExportRequest request,
  }) async {
    if (request.selectedTypes.isEmpty) {
      throw Exception('En az bir işlem türü seçmelisiniz.');
    }

    final filteredTransactions = transactions.where(request.includes).toList()
      ..sort(
        (left, right) => right.transactionDate.compareTo(left.transactionDate),
      );

    if (filteredTransactions.isEmpty) {
      throw Exception('Seçtiğiniz filtrelerle eşleşen işlem bulunamadı.');
    }

    final bytes = await _buildPdf(
      person: person,
      transactions: filteredTransactions,
      request: request,
    );

    final fileName = _buildFileName(person.displayName);
    final useInlineBytes = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    final selectedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Ekstre PDF kaydet',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: useInlineBytes ? bytes : null,
    );

    if (kIsWeb) {
      return StatementExportResult(
        fileName: fileName,
        browserDownload: true,
      );
    }

    if (selectedPath == null) {
      return null;
    }

    if (!useInlineBytes) {
      await saveBytesToPath(selectedPath, bytes);
    }

    return StatementExportResult(
      fileName: fileName,
      savedPath: selectedPath,
      browserDownload: false,
    );
  }

  Future<Uint8List> _buildPdf({
    required ConnectionDetails person,
    required List<FinancialTransaction> transactions,
    required StatementExportRequest request,
  }) async {
    final baseFont = await _resolveFont(
      PdfGoogleFonts.notoSansRegular,
      pw.Font.helvetica(),
    );
    final boldFont = await _resolveFont(
      PdfGoogleFonts.notoSansBold,
      pw.Font.helveticaBold(),
    );

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: baseFont,
        bold: boldFont,
      ),
    );

    final amountFormatter = NumberFormat.currency(locale: 'tr_TR', symbol: '');
    final dateFormatter = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');
    final generatedAt = dateFormatter.format(DateTime.now());
    final selectedTypeLabels =
        request.selectedTypes.map(transactionTypeLabel).join(', ');
    final totalAmount = transactions.fold<double>(
      0,
      (total, transaction) => total + transaction.amount,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F4F7FB'),
              borderRadius: pw.BorderRadius.circular(16),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Musteri Ekstresi',
                  style: pw.TextStyle(font: boldFont, fontSize: 22),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  person.displayName,
                  style: pw.TextStyle(font: boldFont, fontSize: 16),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Olusturulma: $generatedAt'),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Tarih araligi: ${_formatDateRange(request.startDate, request.endDate)}',
                ),
                pw.SizedBox(height: 2),
                pw.Text('Secilen turler: $selectedTypeLabels'),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              _summaryBox(
                title: 'Islem Sayisi',
                value: transactions.length.toString(),
                boldFont: boldFont,
              ),
              pw.SizedBox(width: 12),
              _summaryBox(
                title: 'Toplam Hacim',
                value: '${amountFormatter.format(totalAmount)} TL',
                boldFont: boldFont,
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('#D7DEEA')),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.8),
              1: pw.FlexColumnWidth(1.3),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(1.5),
              5: pw.FlexColumnWidth(2.6),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E8EEF8'),
                ),
                children: [
                  _tableCell('Tarih', boldFont, isHeader: true),
                  _tableCell('Tur', boldFont, isHeader: true),
                  _tableCell('Tutar', boldFont, isHeader: true),
                  _tableCell('Yon', boldFont, isHeader: true),
                  _tableCell('Odeme', boldFont, isHeader: true),
                  _tableCell('Aciklama', boldFont, isHeader: true),
                ],
              ),
              ...transactions.map(
                (transaction) => pw.TableRow(
                  children: [
                    _tableCell(
                      dateFormatter.format(transaction.transactionDate),
                      baseFont,
                    ),
                    _tableCell(
                      transactionTypeLabel(transaction.displayType),
                      baseFont,
                    ),
                    _tableCell(
                      '${_amountPrefix(transaction)}${amountFormatter.format(transaction.amount)} ${transactionCurrencyLabel(transaction.currency)}',
                      baseFont,
                    ),
                    _tableCell(
                      transactionDirectionLabel(transaction.direction),
                      baseFont,
                    ),
                    _tableCell(
                      transaction.paymentMethod ?? '-',
                      baseFont,
                    ),
                    _tableCell(
                      transaction.description?.trim().isNotEmpty == true
                          ? transaction.description!.trim()
                          : '-',
                      baseFont,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<pw.Font> _resolveFont(
    Future<pw.Font> Function() loader,
    pw.Font fallback,
  ) async {
    try {
      return await loader();
    } catch (_) {
      return fallback;
    }
  }

  pw.Widget _summaryBox({
    required String title,
    required String value,
    required pw.Font boldFont,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F8FAFD'),
          border: pw.Border.all(color: PdfColor.fromHex('#D7DEEA')),
          borderRadius: pw.BorderRadius.circular(12),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _tableCell(
    String value,
    pw.Font font, {
    bool isHeader = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 10 : 9,
        ),
      ),
    );
  }

  String _amountPrefix(FinancialTransaction transaction) {
    switch (transaction.direction) {
      case TransactionDirection.incoming:
        return '+';
      case TransactionDirection.outgoing:
        return '-';
      case TransactionDirection.neutral:
        return '';
    }
  }

  String _formatDateRange(DateTime? startDate, DateTime? endDate) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');
    if (startDate == null && endDate == null) {
      return 'Tum zamanlar';
    }

    final startText =
        startDate == null ? 'Baslangic yok' : formatter.format(startDate);
    final endText = endDate == null ? 'Bitis yok' : formatter.format(endDate);
    return '$startText - $endText';
  }

  String _buildFileName(String displayName) {
    final safeName = displayName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final timestamp =
        DateFormat('yyyyMMdd_HHmm', 'tr_TR').format(DateTime.now());
    return 'ekstre_${safeName.isEmpty ? 'kisi' : safeName}_$timestamp.pdf';
  }
}
