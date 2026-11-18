import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/quote_model.dart';
import '../utils/amount_in_words.dart';
import 'memo_pdf.dart' show formatRupees;

// Letterhead details, as on the visiting card.
const bizName = 'MMM Trailer Service';
const bizTagline = 'Expert in the art of Moving...';
const bizAddress = 'No. 4688/4, 12th St, MMDA Mathur, Chennai - 600068';
const bizPhones = '9384943004, 9842596918';
const bizEmail = 'mmmtrailerservice@gmail.com';
const bizWebsite = 'www.mmmtrailerservice.com';

const _navy = PdfColor.fromInt(0xFF0D1B4C);
const _orange = PdfColor.fromInt(0xFFF57C00);
const _grey = PdfColor.fromInt(0xFF5F6368);
const _line = PdfColor.fromInt(0xFFCFD5E3);
const _tint = PdfColor.fromInt(0xFFF1F4FA);
const _noteTint = PdfColor.fromInt(0xFFFFF4E5);

Uint8List? _logoCache;
Uint8List? _signCache;
pw.Font? _fontCache;
pw.Font? _tamilCache;

final _dateFmt = DateFormat('dd-MM-yyyy');

String _qty(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// "Rs. 45,000 per vehicle x 2 vehicles" / "Rs. 1,800 per ton x 25 tons".
String freightDescription(QuoteModel q) {
  final rate = 'Rs. ${formatRupees(q.rate)}';
  if (q.pricing == PricingMode.perTon) {
    return '$rate per ton x ${_qty(q.weightTons)} ton${q.weightTons == 1 ? '' : 's'}';
  }
  return '$rate per vehicle x ${q.vehicles} vehicle${q.vehicles == 1 ? '' : 's'}';
}

String _vehicleLine(QuoteModel q) =>
    '${q.vehicleType.isEmpty ? 'Vehicle' : q.vehicleType} x ${q.vehicles}';

String _chargeValue(QuoteCharge c) =>
    c.mode == ChargeMode.amount ? formatRupees(c.amount) : c.mode.label;

Future<Uint8List> buildQuotePdf(QuoteModel q) async {
  _logoCache ??=
      (await rootBundle.load('assets/quote_logo.jpg')).buffer.asUint8List();
  _signCache ??=
      (await rootBundle.load('assets/memo_sign.png')).buffer.asUint8List();
  _fontCache ??= pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  );
  _tamilCache ??= pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansTamil-Regular.ttf'),
  );

  // User-typed text uses Noto (Tamil-capable); fixed English labels use Helvetica-Bold.
  final base = pw.TextStyle(
    font: _fontCache,
    fontFallback: [_tamilCache!],
    fontSize: 10,
  );
  final bold = pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 10);
  final small = base.copyWith(fontSize: 8.5, color: _grey);

  pw.Widget label(String t) => pw.Text(t, style: small);

  pw.Widget cell(String t, {pw.TextStyle? style, bool right = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: pw.Text(
          t,
          style: style ?? base,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        ),
      );

  final header = pw.Column(
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.ClipRRect(
            horizontalRadius: 6,
            verticalRadius: 6,
            child: pw.Image(pw.MemoryImage(_logoCache!), width: 150),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  bizName.toUpperCase(),
                  style: bold.copyWith(fontSize: 17, color: _navy),
                ),
                pw.Text(
                  bizTagline,
                  style: base.copyWith(fontSize: 9, color: _orange),
                ),
                pw.SizedBox(height: 6),
                pw.Text(bizAddress, style: small, textAlign: pw.TextAlign.right),
                pw.Text('Ph: $bizPhones', style: small),
                pw.Text('$bizEmail  |  $bizWebsite', style: small),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Container(height: 3, color: _navy),
      pw.Container(height: 1.5, color: _orange),
    ],
  );

  final titleRow = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Text('QUOTATION', style: bold.copyWith(fontSize: 18, color: _navy)),
      pw.Spacer(),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (q.quoteNo > 0)
            pw.Text('No: ${q.quoteNoText}', style: bold.copyWith(fontSize: 11)),
          pw.Text('Date: ${_dateFmt.format(q.date)}', style: base),
        ],
      ),
    ],
  );

  final toBlock = pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _tint,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        label('To'),
        pw.Text(q.customerName, style: base.copyWith(fontSize: 12)),
        if (q.address.trim().isNotEmpty) pw.Text(q.address.trim(), style: base),
        if (q.customerPhone.isNotEmpty) pw.Text('Ph: ${q.customerPhone}', style: base),
        if (q.customerEmail.isNotEmpty) pw.Text(q.customerEmail, style: base),
      ],
    ),
  );

  final jobRows = <List<String>>[
    ['Route', '${q.from}  to  ${q.to}'],
    ['Vehicle', _vehicleLine(q)],
    if (q.cargo.trim().isNotEmpty) ['Cargo', q.cargo.trim()],
    if (q.pricing == PricingMode.perTon) ['Weight (approx.)', '${_qty(q.weightTons)} tons'],
  ];
  final jobTable = pw.Table(
    columnWidths: {0: const pw.FixedColumnWidth(110), 1: const pw.FlexColumnWidth()},
    border: pw.TableBorder.all(color: _line, width: 0.6),
    children: [
      for (final r in jobRows)
        pw.TableRow(children: [cell(r[0], style: bold), cell(r[1])]),
    ],
  );

  var sno = 0;
  final chargeTable = pw.Table(
    columnWidths: {
      0: const pw.FixedColumnWidth(36),
      1: const pw.FlexColumnWidth(),
      2: const pw.FixedColumnWidth(110),
    },
    border: pw.TableBorder.all(color: _line, width: 0.6),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _navy),
        children: [
          cell('S.No', style: bold.copyWith(color: PdfColors.white)),
          cell('Description', style: bold.copyWith(color: PdfColors.white)),
          cell('Amount (Rs.)', style: bold.copyWith(color: PdfColors.white), right: true),
        ],
      ),
      pw.TableRow(children: [
        cell('${++sno}'),
        cell('Freight - ${freightDescription(q)}'),
        cell(formatRupees(q.freight), right: true),
      ]),
      for (final c in q.charges.where((c) => c.desc.trim().isNotEmpty))
        pw.TableRow(children: [
          cell('${++sno}'),
          cell(c.desc.trim()),
          cell(_chargeValue(c), right: true),
        ]),
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _tint),
        children: [
          cell(''),
          cell('TOTAL', style: bold),
          cell(formatRupees(q.total), style: bold.copyWith(fontSize: 11), right: true),
        ],
      ),
    ],
  );

  final payment = pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _orange, width: 0.8),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          q.pricing == PricingMode.perTon ? 'PAYMENT (ESTIMATED)' : 'PAYMENT',
          style: bold.copyWith(color: _navy),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${q.isCustomSplit ? 'After' : '${_pctText(q.advancePercent)}% after'} loading:  '
          'Rs. ${formatRupees(q.advanceAmount)}',
          style: base,
        ),
        pw.Text(
          '${q.isCustomSplit ? 'Balance after' : '${_pctText(q.balancePercent)}% after'} unloading:  '
          'Rs. ${formatRupees(q.balanceAmount)}',
          style: base,
        ),
      ],
    ),
  );

  final noteBlock = pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: _noteTint,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('NOTE', style: bold.copyWith(color: _navy)),
        pw.SizedBox(height: 4),
        pw.Text(q.note.trim(), style: base),
      ],
    ),
  );

  final terms = q.terms(formatRupees);
  final termsBlock = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('TERMS & CONDITIONS', style: bold.copyWith(color: _navy)),
      pw.SizedBox(height: 4),
      for (var i = 0; i < terms.length; i++)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text('${i + 1}. ${terms[i]}', style: base),
        ),
    ],
  );

  final signature = pw.Inseparable(child: pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('For $bizName', style: bold),
        pw.Image(pw.MemoryImage(_signCache!), width: 110),
        pw.Text('Authorised Signatory', style: small),
      ],
    ),
  ));

  final doc = pw.Document(title: 'Quotation ${q.quoteNoText}');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 26, 36, 24),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10), child: header)
          : pw.SizedBox(),
      footer: (ctx) => pw.Row(
        children: [
          pw.Text('This is a computer-generated quotation.', style: small),
          pw.Spacer(),
          if (ctx.pagesCount > 1)
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: small),
        ],
      ),
      build: (_) => [
        titleRow,
        pw.SizedBox(height: 10),
        toBlock,
        pw.SizedBox(height: 10),
        jobTable,
        pw.SizedBox(height: 10),
        chargeTable,
        pw.SizedBox(height: 4),
        pw.Text(amountInWords(q.total), style: base.copyWith(color: _grey)),
        if (q.showPayment) ...[pw.SizedBox(height: 10), payment],
        if (q.note.trim().isNotEmpty) ...[pw.SizedBox(height: 10), noteBlock],
        if (terms.isNotEmpty) ...[pw.SizedBox(height: 10), termsBlock],
        pw.SizedBox(height: 14),
        signature,
      ],
    ),
  );
  return doc.save();
}

String _pctText(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

String quoteFileName(QuoteModel q, {String ext = 'pdf'}) {
  final party = q.customerName.replaceAll(RegExp(r'[^\w\-]+'), '_');
  return 'Quotation_${q.quoteNoText}${party.isEmpty ? '' : '_$party'}.$ext';
}

/// Short plain-text quote for WhatsApp/SMS.
String quoteText(QuoteModel q) {
  final terms = q.terms(formatRupees);
  final lines = <String>[
    '$bizName - Quotation ${q.quoteNoText}',
    'Date: ${_dateFmt.format(q.date)}',
    '',
    'Route: ${q.from} to ${q.to}',
    'Vehicle: ${_vehicleLine(q)}',
    if (q.cargo.trim().isNotEmpty) 'Cargo: ${q.cargo.trim()}',
    'Freight: ${freightDescription(q)} = Rs. ${formatRupees(q.freight)}',
    for (final c in q.charges.where((c) => c.desc.trim().isNotEmpty))
      '${c.desc.trim()}: ${c.mode == ChargeMode.amount ? 'Rs. ${formatRupees(c.amount)}' : c.mode.label}',
    'Total: Rs. ${formatRupees(q.total)}',
    if (q.note.trim().isNotEmpty) ...['', 'Note: ${q.note.trim()}'],
    if (terms.isNotEmpty) ...['', 'Terms:', ...terms.map((t) => '- $t')],
    '',
    bizName,
    'Ph: $bizPhones',
  ];
  return lines.join('\n');
}

String quoteEmailSubject(QuoteModel q) =>
    'Quotation ${q.quoteNoText} - ${q.from} to ${q.to} - $bizName';

String quoteEmailBody(QuoteModel q) {
  final name = q.customerName.trim();
  return [
    'Dear ${name.isEmpty ? 'Sir/Madam' : name},',
    '',
    'Thank you for your enquiry. Please find our quotation attached. Summary:',
    '',
    'Route: ${q.from} to ${q.to}',
    'Vehicle: ${_vehicleLine(q)}',
    if (q.cargo.trim().isNotEmpty) 'Cargo: ${q.cargo.trim()}',
    'Freight: ${freightDescription(q)}',
    'Total: Rs. ${formatRupees(q.total)}',
    if (q.showPayment) 'Payment: ${q.paymentTerm(formatRupees)}',
    if (q.note.trim().isNotEmpty) 'Note: ${q.note.trim()}',
    '',
    'Please feel free to call us for any clarification.',
    '',
    'Regards,',
    bizName,
    'Ph: $bizPhones',
    bizWebsite,
  ].join('\n');
}

Future<File> _writeTemp(String name, List<int> bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

// The share functions return false when the user closed the share sheet without picking an app.
bool _picked(ShareResult r) => r.status != ShareResultStatus.dismissed;

Future<bool> shareQuotePdf(QuoteModel q) async {
  final file = await _writeTemp(quoteFileName(q), await buildQuotePdf(q));
  return _picked(await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/pdf')],
    text: '$bizName - Quotation ${q.quoteNoText}',
  ));
}

/// Shares the first page as a JPG (WhatsApp shows it inline).
Future<bool> shareQuoteJpg(QuoteModel q) async {
  final pdf = await buildQuotePdf(q);
  final page = await Printing.raster(pdf, pages: [0], dpi: 170).first;
  final jpg = img.encodeJpg(page.asImage(), quality: 88);
  final file = await _writeTemp(quoteFileName(q, ext: 'jpg'), jpg);
  return _picked(await Share.shareXFiles(
    [XFile(file.path, mimeType: 'image/jpeg')],
    text: '$bizName - Quotation ${q.quoteNoText}',
  ));
}

Future<bool> shareQuoteText(QuoteModel q) async =>
    _picked(await Share.share(quoteText(q)));

/// Opens the phone's mail app with To, CC, subject, body and the PDF filled in.
/// Falls back to the share sheet when no mail app is available; returns false then.
Future<bool> emailQuote(QuoteModel q) async {
  final file = await _writeTemp(quoteFileName(q), await buildQuotePdf(q));
  try {
    await FlutterEmailSender.send(
      Email(
        subject: quoteEmailSubject(q),
        body: quoteEmailBody(q),
        recipients: [if (q.customerEmail.isNotEmpty) q.customerEmail],
        cc: [if (q.ccEmail.isNotEmpty) q.ccEmail],
        attachmentPaths: [file.path],
      ),
    );
    return true;
  } on FlutterEmailSenderNotAvailableException {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: quoteEmailSubject(q),
      text: quoteEmailBody(q),
    );
    return false;
  }
}
