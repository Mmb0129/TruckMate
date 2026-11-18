// Converts an amount to Indian-style words (thousand / lakh / crore).
// e.g. 1234567 -> "Rupees Twelve Lakh Thirty-Four Thousand Five Hundred Sixty-Seven Only"

const _ones = [
  '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
  'Seventeen', 'Eighteen', 'Nineteen',
];

const _tens = [
  '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty',
  'Ninety',
];

String _belowHundred(int n) {
  if (n < 20) return _ones[n];
  final t = _tens[n ~/ 10];
  final o = n % 10;
  return o == 0 ? t : '$t-${_ones[o]}';
}

String _belowThousand(int n) {
  final parts = <String>[];
  if (n >= 100) {
    parts.add('${_ones[n ~/ 100]} Hundred');
    n %= 100;
  }
  if (n > 0) parts.add(_belowHundred(n));
  return parts.join(' ');
}

String numberToIndianWords(int n) {
  if (n == 0) return 'Zero';
  final parts = <String>[];
  final crore = n ~/ 10000000;
  n %= 10000000;
  final lakh = n ~/ 100000;
  n %= 100000;
  final thousand = n ~/ 1000;
  n %= 1000;

  if (crore > 0) parts.add('${numberToIndianWords(crore)} Crore');
  if (lakh > 0) parts.add('${_belowHundred(lakh)} Lakh');
  if (thousand > 0) parts.add('${_belowHundred(thousand)} Thousand');
  if (n > 0) parts.add(_belowThousand(n));
  return parts.join(' ');
}

String amountInWords(double amount) {
  final rupees = amount.abs().floor();
  final paise = ((amount.abs() - rupees) * 100).round();
  var words = 'Rupees ${numberToIndianWords(rupees)}';
  if (paise > 0) words += ' and ${numberToIndianWords(paise)} Paise';
  return '$words Only';
}
