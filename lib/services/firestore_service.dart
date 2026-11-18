import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/trip_model.dart';
import '../models/truck_model.dart';
import '../models/memo_model.dart';
import '../models/quote_model.dart';

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

  // ── Memos ──

  CollectionReference<Map<String, dynamic>> get _memos =>
      _db.collection('users').doc(uid).collection('memos');

  DocumentReference<Map<String, dynamic>> get _counters =>
      _db.collection('users').doc(uid).collection('meta').doc('counters');

  /// Saves a new memo with the next memo number (assigned in a transaction
  /// so two memos never share a number). Returns the memo with id and number.
  Future<MemoModel> createMemo(MemoModel memo) async {
    final ref = _memos.doc();
    await _db.runTransaction((tx) async {
      final counter = await tx.get(_counters);
      final next = ((counter.data()?['memoNo'] ?? 0) as num).toInt() + 1;
      memo.memoNo = next;
      memo.createdAt = DateTime.now();
      tx.set(_counters, {'memoNo': next}, SetOptions(merge: true));
      tx.set(ref, memo.toMap());
    });
    memo.id = ref.id;
    return memo;
  }

  Future<void> updateMemo(MemoModel memo) async {
    await _memos.doc(memo.id).update(memo.toMap());
  }

  Future<void> deleteMemo(String memoId) async {
    await _memos.doc(memoId).delete();
  }

  Stream<List<MemoModel>> getMemos() {
    return _memos
        .orderBy('memoNo', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => MemoModel.fromMap(d.id, d.data())).toList());
  }

  Future<int> getNextMemoNo() async {
    final counter = await _counters.get();
    return ((counter.data()?['memoNo'] ?? 0) as num).toInt() + 1;
  }

  /// Sets the number the next new memo will get (e.g. to continue a paper series).
  Future<void> setNextMemoNo(int next) async {
    await _counters.set({'memoNo': next - 1}, SetOptions(merge: true));
  }

  // ── Quotations ──
  // Numbered by the 'quoteNo' field of the same counters doc; merge keeps memoNo intact.

  CollectionReference<Map<String, dynamic>> get _quotes =>
      _db.collection('users').doc(uid).collection('quotes');

  Future<QuoteModel> createQuote(QuoteModel quote) async {
    final ref = _quotes.doc();
    await _db.runTransaction((tx) async {
      final counter = await tx.get(_counters);
      final next = ((counter.data()?['quoteNo'] ?? 0) as num).toInt() + 1;
      quote.quoteNo = next;
      quote.createdAt = DateTime.now();
      tx.set(_counters, {'quoteNo': next}, SetOptions(merge: true));
      tx.set(ref, quote.toMap());
    });
    quote.id = ref.id;
    return quote;
  }

  Future<void> updateQuote(QuoteModel quote) async {
    await _quotes.doc(quote.id).update(quote.toMap());
  }

  Future<void> deleteQuote(String quoteId) async {
    await _quotes.doc(quoteId).delete();
  }

  Stream<List<QuoteModel>> getQuotes() {
    return _quotes
        .orderBy('quoteNo', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => QuoteModel.fromMap(d.id, d.data())).toList());
  }

  Future<int> getNextQuoteNo() async {
    final counter = await _counters.get();
    return ((counter.data()?['quoteNo'] ?? 0) as num).toInt() + 1;
  }

  Future<void> setNextQuoteNo(int next) async {
    await _counters.set({'quoteNo': next - 1}, SetOptions(merge: true));
  }
}
