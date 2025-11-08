import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip_model.dart';
import '../models/truck_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  String get uid {
    final u = auth.currentUser;
    if (u == null) {
      throw StateError('No logged-in user. Make sure to login first.');
    }
    return u.uid;
  }

  Future<void> addTruck(String truckNumber, String driverName) async {
    await _db.collection('users').doc(uid).collection('trucks').add({
      'truckNumber': truckNumber,
      'driverName': driverName,
    });
  }

  Future<void> addTrip(String truckId, TripModel trip) async {
    await _db
        .collection('users').doc(uid)
        .collection('trucks').doc(truckId)
        .collection('trips')
        .add(trip.toMap());
  }

  Future<void> updateTrip(String truckId, TripModel trip) async {
    await _db
        .collection('users').doc(uid)
        .collection('trucks').doc(truckId)
        .collection('trips').doc(trip.id)
        .update(trip.toMap());
  }

  Future<void> deleteTrip(String truckId, String tripId) async {
    await _db
        .collection('users').doc(uid)
        .collection('trucks').doc(truckId)
        .collection('trips').doc(tripId)
        .delete();
  }

  Stream<List<TripModel>> getTrips(String truckId) {
    return _db
        .collection('users').doc(uid)
        .collection('trucks').doc(truckId)
        .collection('trips')
        .snapshots()
        .map((s) => s.docs.map((d) => TripModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<TruckModel>> getTrucks() {
    return _db
        .collection('users').doc(uid)
        .collection('trucks')
        .snapshots()
        .map((s) => s.docs.map((d) => TruckModel.fromMap(d.id, d.data())).toList());
  }
}
