import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truckmate/models/quote_model.dart';
import 'package:truckmate/services/memo_pdf.dart' show formatRupees;
import 'package:truckmate/services/quote_pdf.dart';

QuoteModel _quote({
  PricingMode pricing = PricingMode.perVehicle,
  double rate = 45000,
  int vehicles = 2,
  double weight = 0,
  List<QuoteCharge>? charges,
}) => QuoteModel(
  quoteNo: 12,
  date: DateTime(2026, 11, 18),
  customerName: 'Sri Balaji Roadways',
  customerPhone: '9876543210',
  customerEmail: 'ops@balaji.example',
  ccEmail: bizEmail,
  address: 'No. 12, GST Road\nGuindy, Chennai - 600032',
  from: 'Chennai',
  to: 'Pune',
  cargo: 'Steel coils',
  vehicles: vehicles,
  pricing: pricing,
  rate: rate,
  weightTons: weight,
  charges: charges,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('freight', () {
    test('per vehicle = rate x vehicles', () {
      final q = _quote(rate: 45000, vehicles: 2);
      expect(q.freight, 90000);
      expect(freightDescription(q), 'Rs. 45,000 per vehicle x 2 vehicles');
    });

    test('per ton = rate x weight, rounded to the rupee', () {
      final q = _quote(pricing: PricingMode.perTon, rate: 1850.5, weight: 24.75);
      expect(q.freight, 45800); // 45799.875
      expect(freightDescription(q), 'Rs. 1,850.5 per ton x 24.75 tons');
    });

    test('per ton ignores vehicle count', () {
      final q = _quote(pricing: PricingMode.perTon, rate: 1800, weight: 25, vehicles: 3);
      expect(q.freight, 45000);
    });
  });

  test('only "Amount" charges add to the total', () {
    final q = _quote(
      charges: [
        QuoteCharge(desc: 'Loading', amount: 2500),
        QuoteCharge(desc: 'Toll', mode: ChargeMode.atActuals, amount: 999),
        QuoteCharge(desc: 'Unloading', mode: ChargeMode.partyScope),
        QuoteCharge(desc: 'Escort', mode: ChargeMode.included),
      ],
    );
    expect(q.extrasTotal, 2500);
    expect(q.total, 92500);
  });

  group('90/10 payment split', () {
    test('default split', () {
      final q = _quote();
      expect(q.advanceAmount, 81000);
      expect(q.balanceAmount, 9000);
      expect(q.paymentTerm(formatRupees), '90% payment after loading, 10% after unloading.');
    });

    test('odd total still adds up exactly', () {
      final q = _quote(rate: 45001, vehicles: 1);
      expect(q.advanceAmount, 40501); // 40500.9
      expect(q.balanceAmount, 4500);
      expect(q.advanceAmount + q.balanceAmount, q.total);
    });

    test('typed round amount: 55,000 total, collect 50,000 not 49,500', () {
      final q = _quote(rate: 55000, vehicles: 1);
      expect(q.percentAdvance, 49500);
      q.advanceOverride = 50000;
      expect(q.isCustomSplit, isTrue);
      expect(q.advanceAmount, 50000);
      expect(q.balanceAmount, 5000);
      expect(
        q.paymentTerm(formatRupees),
        'Rs. 50,000 after loading, balance Rs. 5,000 after unloading.',
      );
    });

    test('payment terms off: no payment term, other terms stay', () {
      final q = _quote()
        ..showPayment = false
        ..otherTerms = 'Loading by party.';
      expect(q.terms(formatRupees), ['Loading by party.']);
      expect(quoteText(q), isNot(contains('after loading')));
      expect(quoteEmailBody(q), isNot(contains('Payment:')));
    });

    test('custom split', () {
      final q = _quote()..advancePercent = 80;
      expect(q.advanceAmount, 72000);
      expect(q.paymentTerm(formatRupees), '80% payment after loading, 20% after unloading.');
    });
  });

  group('terms', () {
    test('halting term only when a rate is entered', () {
      final q = _quote();
      expect(q.terms(formatRupees), [
        '90% payment after loading, 10% after unloading.',
      ]);
      q
        ..haltingPerDay = 3000
        ..haltingFreeDays = 1
        ..otherTerms = 'Loading by party.\n\nGoods insured by party.';
      expect(q.terms(formatRupees), [
        '90% payment after loading, 10% after unloading.',
        'Halting charges Rs. 3,000 per day per vehicle after 1 free day.',
        'Loading by party.',
        'Goods insured by party.',
      ]);
    });

    test('per ton adds the weighbridge term', () {
      final q = _quote(pricing: PricingMode.perTon, rate: 1800, weight: 25);
      expect(
        q.terms(formatRupees),
        contains('Final freight on actual loaded weight as per weighbridge slip.'),
      );
    });
  });

  test('Firestore map round trip', () {
    final q = _quote(
      pricing: PricingMode.perTon,
      weight: 25,
      charges: [QuoteCharge(desc: 'Toll', mode: ChargeMode.atActuals)],
    )
      ..haltingPerDay = 2000
      ..advanceOverride = 40000
      ..showPayment = false
      ..note = 'Vehicle available from 20th'
      ..status = QuoteStatus.sent
      ..memoIds = ['m1'];
    final back = QuoteModel.fromMap('id1', q.toMap());
    expect(back.quoteNoText, 'Q-0012');
    expect(back.pricing, PricingMode.perTon);
    expect(back.charges.single.mode, ChargeMode.atActuals);
    expect(back.status, QuoteStatus.sent);
    expect(back.memoIds, ['m1']);
    expect(back.advanceOverride, 40000);
    expect(back.showPayment, isFalse);
    expect(back.note, 'Vehicle available from 20th');
    expect(back.total, q.total);
  });

  test('old or partial documents still load', () {
    final q = QuoteModel.fromMap('x', {'quoteNo': 3, 'pricing': 'unknown'});
    expect(q.pricing, PricingMode.perVehicle);
    expect(q.advancePercent, 90);
    expect(q.showPayment, isTrue); // quotes saved before the checkbox existed
    expect(q.advanceOverride, isNull);
    expect(q.note, '');
    expect(q.charges, isEmpty);
  });

  test('text and email content', () {
    final q = _quote(charges: [QuoteCharge(desc: 'Toll', mode: ChargeMode.atActuals)]);
    expect(quoteEmailSubject(q), 'Quotation Q-0012 - Chennai to Pune - MMM Trailer Service');
    expect(quoteEmailBody(q), startsWith('Dear Sri Balaji Roadways,'));
    expect(quoteText(q), contains('Toll: Extra at actuals'));
    expect(quoteText(q), contains('Total: Rs. 90,000'));
    expect(quoteFileName(q), 'Quotation_Q-0012_Sri_Balaji_Roadways.pdf');
    q.note = 'Rate valid for this load only';
    expect(quoteText(q), contains('Note: Rate valid for this load only'));
    expect(quoteEmailBody(q), contains('Note: Rate valid for this load only'));
  });

  test('builds quotation PDF small enough for email', () async {
    final q = _quote(
      charges: [
        QuoteCharge(desc: 'Loading', amount: 2500),
        QuoteCharge(desc: 'Toll', mode: ChargeMode.atActuals),
        QuoteCharge(desc: 'Unloading', mode: ChargeMode.partyScope),
      ],
    )
      ..haltingPerDay = 3000
      ..haltingFreeDays = 1
      ..advanceOverride = 85000
      ..note = 'Vehicle available from 20th Nov. Rate valid for this load only.'
      ..otherTerms = 'Goods to be insured by the party.';
    final bytes = await buildQuotePdf(q);
    expect(bytes.length, greaterThan(20000)); // logo + signature embedded
    expect(bytes.length, lessThan(1024 * 1024));

    // Set QUOTE_PDF_OUT to save the sample for a visual check.
    final out = Platform.environment['QUOTE_PDF_OUT'];
    if (out != null) await File(out).writeAsBytes(bytes);
  });
}
