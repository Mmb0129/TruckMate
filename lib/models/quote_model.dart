enum PricingMode { perVehicle, perTon }

enum ChargeMode { amount, included, atActuals, partyScope }

enum QuoteStatus { draft, sent, accepted, rejected }

extension ChargeModeText on ChargeMode {
  String get label => switch (this) {
    ChargeMode.amount => 'Amount',
    ChargeMode.included => 'Included',
    ChargeMode.atActuals => 'Extra at actuals',
    ChargeMode.partyScope => "Party's scope",
  };
}

extension QuoteStatusText on QuoteStatus {
  String get label => switch (this) {
    QuoteStatus.draft => 'Draft',
    QuoteStatus.sent => 'Sent',
    QuoteStatus.accepted => 'Accepted',
    QuoteStatus.rejected => 'Rejected',
  };
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// An extra line on the quote such as Loading, Toll or Escort.
class QuoteCharge {
  String desc;
  ChargeMode mode;
  double amount; // used only when mode == amount

  QuoteCharge({required this.desc, this.mode = ChargeMode.amount, this.amount = 0});

  bool get addsToTotal => mode == ChargeMode.amount;

  Map<String, dynamic> toMap() => {
    'desc': desc,
    'mode': mode.name,
    'amount': amount,
  };

  factory QuoteCharge.fromMap(Map<String, dynamic> m) => QuoteCharge(
    desc: m['desc'] ?? '',
    mode: _enumByName(ChargeMode.values, m['mode'], ChargeMode.amount),
    amount: (m['amount'] ?? 0).toDouble(),
  );
}

class QuoteModel {
  String id;
  int quoteNo; // 0 until saved; assigned by FirestoreService.createQuote
  DateTime date;
  String customerName;
  String customerPhone;
  String customerEmail;
  String ccEmail;
  String address;
  String from;
  String to;
  String cargo;
  String vehicleType;
  int vehicles;
  PricingMode pricing;
  double rate; // per vehicle or per ton, depending on [pricing]
  double weightTons; // used only for per-ton pricing
  List<QuoteCharge> charges;
  double haltingPerDay; // 0 = no halting term
  int haltingFreeDays;
  bool showPayment; // false = no payment terms on the quote at all
  double advancePercent; // paid after loading; the rest after unloading
  double? advanceOverride; // typed after-loading amount (e.g. 50,000 instead of 49,500)
  String otherTerms; // one term per line
  String note; // free text printed in a Note box
  QuoteStatus status;
  List<String> memoIds;
  String sentVia;
  DateTime? sentAt;
  DateTime? createdAt;

  QuoteModel({
    this.id = '',
    this.quoteNo = 0,
    required this.date,
    this.customerName = '',
    this.customerPhone = '',
    this.customerEmail = '',
    this.ccEmail = '',
    this.address = '',
    this.from = '',
    this.to = '',
    this.cargo = '',
    this.vehicleType = '40 ft Trailer',
    this.vehicles = 1,
    this.pricing = PricingMode.perVehicle,
    this.rate = 0,
    this.weightTons = 0,
    List<QuoteCharge>? charges,
    this.haltingPerDay = 0,
    this.haltingFreeDays = 0,
    this.showPayment = true,
    this.advancePercent = 90,
    this.advanceOverride,
    this.otherTerms = '',
    this.note = '',
    this.status = QuoteStatus.draft,
    List<String>? memoIds,
    this.sentVia = '',
    this.sentAt,
    this.createdAt,
  }) : charges = charges ?? [],
       memoIds = memoIds ?? [];

  /// Quote number as printed, e.g. 12 -> "Q-0012".
  String get quoteNoText => 'Q-${quoteNo.toString().padLeft(4, '0')}';

  /// Quantity the rate is multiplied by: vehicles, or tons for per-ton pricing.
  double get chargeableQty =>
      pricing == PricingMode.perVehicle ? vehicles.toDouble() : weightTons;

  double get freight => (rate * chargeableQty).roundToDouble();

  double get extrasTotal => charges
      .where((c) => c.addsToTotal)
      .fold(0.0, (s, c) => s + c.amount);

  double get total => freight + extrasTotal;

  /// After-loading amount from the percentage, rounded to the rupee.
  double get percentAdvance => (total * advancePercent / 100).roundToDouble();

  /// Paid after loading: the typed amount if any, else the percentage.
  /// The balance takes the remainder so the two always add up to [total].
  double get advanceAmount => advanceOverride ?? percentAdvance;

  double get balanceAmount => total - advanceAmount;

  double get balancePercent => 100 - advancePercent;

  bool get isCustomSplit => advanceOverride != null;

  // A typed amount isn't an exact percentage, so it is worded in rupees.
  String paymentTerm(String Function(double) money) => isCustomSplit
      ? 'Rs. ${money(advanceAmount)} after loading, '
            'balance Rs. ${money(balanceAmount)} after unloading.'
      : '${_pct(advancePercent)}% payment after loading, '
            '${_pct(balancePercent)}% after unloading.';

  /// Empty when no halting rate is entered.
  String haltingTerm(String Function(double) money) {
    if (haltingPerDay <= 0) return '';
    final free = haltingFreeDays > 0
        ? ' after $haltingFreeDays free day${haltingFreeDays == 1 ? '' : 's'}'
        : '';
    return 'Halting charges Rs. ${money(haltingPerDay)} per day per vehicle$free.';
  }

  /// All terms in print order: payment, halting, per-ton note, then other terms.
  List<String> terms(String Function(double) money) => [
    if (showPayment) paymentTerm(money),
    haltingTerm(money),
    if (pricing == PricingMode.perTon)
      'Final freight on actual loaded weight as per weighbridge slip.',
    ...otherTerms.split('\n'),
  ].map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  static String _pct(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Map<String, dynamic> toMap() => {
    'quoteNo': quoteNo,
    'date': date.toIso8601String(),
    'customerName': customerName,
    'customerPhone': customerPhone,
    'customerEmail': customerEmail,
    'ccEmail': ccEmail,
    'address': address,
    'from': from,
    'to': to,
    'cargo': cargo,
    'vehicleType': vehicleType,
    'vehicles': vehicles,
    'pricing': pricing.name,
    'rate': rate,
    'weightTons': weightTons,
    'charges': charges.map((c) => c.toMap()).toList(),
    'haltingPerDay': haltingPerDay,
    'haltingFreeDays': haltingFreeDays,
    'showPayment': showPayment,
    'advancePercent': advancePercent,
    'advanceOverride': advanceOverride,
    'otherTerms': otherTerms,
    'note': note,
    'status': status.name,
    'memoIds': memoIds,
    'sentVia': sentVia,
    'sentAt': sentAt?.toIso8601String(),
    'total': total, // stored for reading in the Firestore console
    'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
  };

  factory QuoteModel.fromMap(String id, Map<String, dynamic> d) => QuoteModel(
    id: id,
    quoteNo: (d['quoteNo'] ?? 0).toInt(),
    date: DateTime.tryParse(d['date'] ?? '') ?? DateTime.now(),
    customerName: d['customerName'] ?? '',
    customerPhone: d['customerPhone'] ?? '',
    customerEmail: d['customerEmail'] ?? '',
    ccEmail: d['ccEmail'] ?? '',
    address: d['address'] ?? '',
    from: d['from'] ?? '',
    to: d['to'] ?? '',
    cargo: d['cargo'] ?? '',
    vehicleType: d['vehicleType'] ?? '',
    vehicles: (d['vehicles'] ?? 1).toInt(),
    pricing: _enumByName(PricingMode.values, d['pricing'], PricingMode.perVehicle),
    rate: (d['rate'] ?? 0).toDouble(),
    weightTons: (d['weightTons'] ?? 0).toDouble(),
    charges: ((d['charges'] as List?) ?? [])
        .map((c) => QuoteCharge.fromMap(Map<String, dynamic>.from(c)))
        .toList(),
    haltingPerDay: (d['haltingPerDay'] ?? 0).toDouble(),
    haltingFreeDays: (d['haltingFreeDays'] ?? 0).toInt(),
    showPayment: d['showPayment'] ?? true,
    advancePercent: (d['advancePercent'] ?? 90).toDouble(),
    advanceOverride: (d['advanceOverride'] as num?)?.toDouble(),
    otherTerms: d['otherTerms'] ?? '',
    note: d['note'] ?? '',
    status: _enumByName(QuoteStatus.values, d['status'], QuoteStatus.draft),
    memoIds: List<String>.from(d['memoIds'] ?? const []),
    sentVia: d['sentVia'] ?? '',
    sentAt: d['sentAt'] != null ? DateTime.tryParse(d['sentAt']) : null,
    createdAt: d['createdAt'] != null ? DateTime.tryParse(d['createdAt']) : null,
  );
}
