class TripModel {
  String id;
  DateTime loadingDate;
  DateTime unloadingDate;
  String source;
  String destination;
  String partyName;
  double hireAmount;

  double advanceFromOffice;
  double paymentToDriver;

  String extraHeightWeight;
  double loadingMamul;
  double unloadingMamul;
  double weighmentCharge;
  int haltingDays;
  double extraPaymentToDriver;

  TripModel({
    required this.id,
    required this.loadingDate,
    required this.unloadingDate,
    required this.source,
    required this.destination,
    required this.partyName,
    required this.hireAmount,
    required this.advanceFromOffice,
    required this.paymentToDriver,
    required this.extraHeightWeight,
    required this.loadingMamul,
    required this.unloadingMamul,
    required this.weighmentCharge,
    required this.haltingDays,
    required this.extraPaymentToDriver,
  });

  Map<String, dynamic> toMap() {
    return {
      'loadingDate': loadingDate.toIso8601String(),
      'unloadingDate': unloadingDate.toIso8601String(),
      'source': source,
      'destination': destination,
      'partyName': partyName,
      'hireAmount': hireAmount,
      'advanceFromOffice': advanceFromOffice,
      'paymentToDriver': paymentToDriver,
      'extraHeightWeight': extraHeightWeight,
      'loadingMamul': loadingMamul,
      'unloadingMamul': unloadingMamul,
      'weighmentCharge': weighmentCharge,
      'haltingDays': haltingDays,
      'extraPaymentToDriver': extraPaymentToDriver,
    };
  }

  factory TripModel.fromMap(String id, Map<String, dynamic> data) {
    return TripModel(
      id: id,
      loadingDate: DateTime.parse(data['loadingDate']),
      unloadingDate: DateTime.parse(data['unloadingDate']),
      source: data['source'] ?? '',
      destination: data['destination'] ?? '',
      partyName: data['partyName'] ?? '',
      hireAmount: (data['hireAmount'] ?? 0).toDouble(),
      advanceFromOffice: (data['advanceFromOffice'] ?? 0).toDouble(),
      paymentToDriver: (data['paymentToDriver'] ?? 0).toDouble(),
      extraHeightWeight: data['extraHeightWeight'] ?? '',
      loadingMamul: (data['loadingMamul'] ?? 0).toDouble(),
      unloadingMamul: (data['unloadingMamul'] ?? 0).toDouble(),
      weighmentCharge: (data['weighmentCharge'] ?? 0).toDouble(),
      haltingDays: (data['haltingDays'] ?? 0).toInt(),
      extraPaymentToDriver: (data['extraPaymentToDriver'] ?? 0).toDouble(),
    );
  }
}
