import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truckmate/models/memo_model.dart';
import 'package:truckmate/services/memo_pdf.dart';
import 'package:truckmate/utils/amount_in_words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('amount in words (Indian numbering)', () {
    expect(amountInWords(0), 'Rupees Zero Only');
    expect(amountInWords(950), 'Rupees Nine Hundred Fifty Only');
    expect(amountInWords(36500), 'Rupees Thirty-Six Thousand Five Hundred Only');
    expect(amountInWords(100000), 'Rupees One Lakh Only');
    expect(
      amountInWords(1234567),
      'Rupees Twelve Lakh Thirty-Four Thousand Five Hundred Sixty-Seven Only',
    );
    expect(amountInWords(25000000), 'Rupees Two Crore Fifty Lakh Only');
    expect(amountInWords(1500.5), 'Rupees One Thousand Five Hundred and Fifty Paise Only');
  });

  test('splitInTwo', () {
    expect(splitInTwo('Short', 40), ['Short', '']);
    expect(splitInTwo('Line one\nLine two', 40), ['Line one', 'Line two']);
    final s = splitInTwo('Rupees Twelve Lakh Thirty-Four Thousand Five Hundred Only', 40);
    expect(s[0].length <= 40, isTrue);
    expect('${s[0]} ${s[1]}', 'Rupees Twelve Lakh Thirty-Four Thousand Five Hundred Only');
  });

  test('builds memo PDF on the template', () async {
    final memo = MemoModel(
      memoNo: 40,
      date: DateTime(2026, 9, 23),
      from: 'Oragadam',
      to: 'Murugancherry',
      trailerNo: 'TN88E1359',
      transportName: 'SKL',
      address: '',
      lrNo: '',
      hireFixed: 13000,
      advance: 10000,
      otherCharges: 0,
      otherChargesNote: 'Halting: One Day',
      balance: 3000,
      amountInWords: amountInWords(3000),
    );
    expect(memo.memoNoText, '0040');
    final bytes = await buildMemoPdf(memo);
    expect(bytes.length, greaterThan(100000)); // template image is embedded

    // Set MEMO_PDF_OUT to save the sample for a visual check.
    final out = Platform.environment['MEMO_PDF_OUT'];
    if (out != null) await File(out).writeAsBytes(bytes);
  });
}
