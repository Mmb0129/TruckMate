class MemoModel {
  String id;
  int memoNo; // 0 until saved; assigned by FirestoreService.createMemo
  DateTime date;
  String from;
  String to;
  String trailerNo;
  String transportName;
  String address;
  String lrNo;
  double hireFixed;
  double advance;
  double otherCharges;
  String otherChargesNote; // e.g. "Halting: One Day"
  double balance;
  String amountInWords;
  DateTime? createdAt;

  MemoModel({
    this.id = '',
    this.memoNo = 0,
    required this.date,
    required this.from,
    required this.to,
    required this.trailerNo,
    required this.transportName,
    required this.address,
    required this.lrNo,
    required this.hireFixed,
    required this.advance,
    required this.otherCharges,
    this.otherChargesNote = '',
    required this.balance,
    required this.amountInWords,
    this.createdAt,
  });

  /// Memo number as printed, e.g. 47 -> "0047".
  String get memoNoText => memoNo.toString().padLeft(4, '0');

  Map<String, dynamic> toMap() {
    return {
      'memoNo': memoNo,
      'date': date.toIso8601String(),
      'from': from,
      'to': to,
      'trailerNo': trailerNo,
      'transportName': transportName,
      'address': address,
      'lrNo': lrNo,
      'hireFixed': hireFixed,
      'advance': advance,
      'otherCharges': otherCharges,
      'otherChargesNote': otherChargesNote,
      'balance': balance,
      'amountInWords': amountInWords,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory MemoModel.fromMap(String id, Map<String, dynamic> data) {
    return MemoModel(
      id: id,
      memoNo: (data['memoNo'] ?? 0).toInt(),
      date: DateTime.parse(data['date']),
      from: data['from'] ?? '',
      to: data['to'] ?? '',
      trailerNo: data['trailerNo'] ?? '',
      transportName: data['transportName'] ?? '',
      address: data['address'] ?? '',
      lrNo: data['lrNo'] ?? '',
      hireFixed: (data['hireFixed'] ?? 0).toDouble(),
      advance: (data['advance'] ?? 0).toDouble(),
      otherCharges: (data['otherCharges'] ?? 0).toDouble(),
      otherChargesNote: data['otherChargesNote'] ?? '',
      balance: (data['balance'] ?? 0).toDouble(),
      amountInWords: data['amountInWords'] ?? '',
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'])
          : null,
    );
  }
}
