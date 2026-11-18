import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/memo_model.dart';

// The memo is the Canva template (assets/memo_template.jpg, 2046×3074 px)
// with the values printed on top. All positions below are in template
// pixels, so if the template changes only this table needs adjusting.
const double _imgW = 2046;
const double _imgH = 3074;
const double _k = 0.25; // PDF points per template pixel → 511.5 × 768.5 pt page

// x = left edge, y = the dotted line the text sits on, w = available width.
class _Slot {
  final double x, y, w;
  const _Slot(this.x, this.y, this.w);
}

const _memoNo = _Slot(225, 1236, 600);
const _dateDd = _Slot(1528, 1231, 102);
const _dateMm = _Slot(1679, 1231, 97);
const _dateYy = _Slot(1880, 1231, 66);
const _from = _Slot(200, 1349, 1070);
const _to = _Slot(1340, 1349, 610);
const _trailerNo = _Slot(345, 1451, 1605);
const _transport = _Slot(470, 1553, 1480);
const _address1 = _Slot(300, 1657, 1650);
const _address2 = _Slot(290, 1755, 1660);
const _lrNo = _Slot(290, 1841, 1660);
const _words1 = _Slot(905, 2471, 1000);
const _words2 = _Slot(905, 2557, 1000);
const _otherNote = _Slot(612, 2192, 715); // dotted line in the Other Charges row

// Signature over the "Authorised Signature" line: left, top, width.
const double _signLeft = 1170, _signTop = 2735, _signW = 840;

// Amount boxes (Hire Fixed, Advance, Other Charges, Balance): left, right, tops, height.
const double _boxLeft = 1514, _boxRight = 1902, _boxH = 82;
const _boxTops = [1934.0, 2035.0, 2136.0, 2237.0];

const _ink = PdfColor.fromInt(0xFF0D2A7A);
const _red = PdfColor.fromInt(0xFFE53935);

Uint8List? _templateCache;
Uint8List? _signCache;
pw.Font? _fontCache;
pw.Font? _tamilCache;

final _money = NumberFormat('#,##,##0.##', 'en_IN');

String formatRupees(double v) => _money.format(v);

Future<Uint8List> buildMemoPdf(MemoModel m) async {
  _templateCache ??=
      (await rootBundle.load('assets/memo_template.jpg')).buffer.asUint8List();
  _signCache ??=
      (await rootBundle.load('assets/memo_sign.png')).buffer.asUint8List();
  _fontCache ??= pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  );
  _tamilCache ??= pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansTamil-Regular.ttf'),
  );

  final style = pw.TextStyle(
    font: _fontCache,
    fontFallback: [_tamilCache!],
    fontSize: 13,
    color: _ink,
  );
  final amountStyle = style.copyWith(fontSize: 15);

  // Text sitting on a dotted line; shrinks to fit if it is too long.
  pw.Widget onLine(
    _Slot s,
    String text, {
    bool center = false,
    pw.TextStyle? textStyle,
  }) {
    if (text.trim().isEmpty) return pw.SizedBox();
    return pw.Positioned(
      left: s.x * _k,
      // Box bottom sits below the line so the text baseline (not its descenders) lands on it.
      bottom: (_imgH - s.y - 9) * _k,
      child: pw.SizedBox(
        width: s.w * _k,
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: center ? pw.Alignment.bottomCenter : pw.Alignment.bottomLeft,
          child: pw.Text(text, style: textStyle ?? style),
        ),
      ),
    );
  }

  pw.Widget inBox(int row, String text) {
    if (text.isEmpty) return pw.SizedBox();
    return pw.Positioned(
      left: _boxLeft * _k,
      top: _boxTops[row] * _k,
      child: pw.Container(
        width: (_boxRight - _boxLeft) * _k,
        height: _boxH * _k,
        padding: const pw.EdgeInsets.symmetric(horizontal: 6),
        alignment: pw.Alignment.centerRight,
        child: pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          child: pw.Text(text, style: amountStyle),
        ),
      ),
    );
  }

  final address = splitInTwo(m.address, 50);
  final words = splitInTwo(m.amountInWords, 40);
  // Amounts not entered (0) are left blank on the memo.
  String amt(double v) => v == 0 ? '' : formatRupees(v);
  final noStyle = pw.TextStyle(
    font: pw.Font.helveticaBold(),
    fontSize: 15,
    color: _red,
  );

  final doc = pw.Document(title: 'Memo ${m.memoNoText}');
  doc.addPage(
    pw.Page(
      pageFormat: const PdfPageFormat(_imgW * _k, _imgH * _k),
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(
        fit: pw.StackFit.expand,
        children: [
          pw.Positioned.fill(
            child: pw.Image(
              pw.MemoryImage(_templateCache!),
              fit: pw.BoxFit.fill,
            ),
          ),
          if (m.memoNo > 0)
            onLine(_memoNo, m.memoNoText, textStyle: noStyle),
          onLine(_dateDd, DateFormat('dd').format(m.date), center: true),
          onLine(_dateMm, DateFormat('MM').format(m.date), center: true),
          onLine(_dateYy, DateFormat('yy').format(m.date), center: true),
          onLine(_from, m.from),
          onLine(_to, m.to),
          onLine(_trailerNo, m.trailerNo),
          onLine(_transport, m.transportName),
          onLine(_address1, address[0]),
          onLine(_address2, address[1]),
          onLine(_lrNo, m.lrNo),
          inBox(0, amt(m.hireFixed)),
          inBox(1, amt(m.advance)),
          onLine(_otherNote, m.otherChargesNote),
          inBox(2, amt(m.otherCharges)),
          inBox(3, amt(m.balance)),
          onLine(_words1, words[0]),
          onLine(_words2, words[1]),
          pw.Positioned(
            left: _signLeft * _k,
            top: _signTop * _k,
            child: pw.Image(pw.MemoryImage(_signCache!), width: _signW * _k),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

/// Splits text over two printed lines: at the first newline if there is one,
/// otherwise at the last space before [maxFirst] characters.
List<String> splitInTwo(String text, int maxFirst) {
  final t = text.trim();
  final nl = t.indexOf('\n');
  if (nl >= 0) {
    return [
      t.substring(0, nl).trim(),
      t.substring(nl + 1).replaceAll('\n', ', ').trim(),
    ];
  }
  if (t.length <= maxFirst) return [t, ''];
  var cut = t.lastIndexOf(' ', maxFirst);
  if (cut <= 0) cut = maxFirst;
  return [t.substring(0, cut).trim(), t.substring(cut).trim()];
}

String memoFileName(MemoModel m, {String ext = 'pdf'}) {
  final party = m.transportName.replaceAll(RegExp(r'[^\w\-]+'), '_');
  return 'Memo_${m.memoNoText}${party.isEmpty ? '' : '_$party'}.$ext';
}

/// Builds the memo PDF and opens the share sheet (WhatsApp, Gmail, …).
Future<void> shareMemoPdf(MemoModel m) async {
  final bytes = await buildMemoPdf(m);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${memoFileName(m)}');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([
    XFile(file.path, mimeType: 'application/pdf'),
  ], text: 'MMM Trailer Service – Memo No. ${m.memoNoText}');
}

/// Renders the memo PDF to a JPG (about 1420×2130 px) and opens the share sheet.
Future<void> shareMemoJpg(MemoModel m) async {
  final pdf = await buildMemoPdf(m);
  final page = await Printing.raster(pdf, pages: [0], dpi: 200).first;
  final jpg = img.encodeJpg(page.asImage(), quality: 90);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${memoFileName(m, ext: 'jpg')}');
  await file.writeAsBytes(jpg, flush: true);
  await Share.shareXFiles([
    XFile(file.path, mimeType: 'image/jpeg'),
  ], text: 'MMM Trailer Service – Memo No. ${m.memoNoText}');
}
