class TruckModel {
  String id;
  String truckNumber;
  String driverName;

  TruckModel({
    required this.id,
    required this.truckNumber,
    required this.driverName,
  });

  Map<String, dynamic> toMap() {
    return {
      'truckNumber': truckNumber,
      'driverName': driverName,
    };
  }

  factory TruckModel.fromMap(String id, Map<String, dynamic> data) {
    return TruckModel(
      id: id,
      truckNumber: data['truckNumber'] ?? '',
      driverName: data['driverName'] ?? '',
    );
  }
}
