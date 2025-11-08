import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'truck_details_screen.dart';
import '../services/firestore_service.dart';
import '../models/truck_model.dart';
import 'add_truck_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Text("Loading...");
            final data = snap.data!.data() as Map<String, dynamic>?;

            final company = data?['companyName'] ?? "TruckMate";
            return Text(company);
          },
        ),
      ),
      body: StreamBuilder<List<TruckModel>>(
        stream: service.getTrucks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final trucks = snapshot.data!;
          return ListView.builder(
            itemCount: trucks.length,
            itemBuilder: (context, index) {
              final truck = trucks[index];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TruckDetailsScreen(truck: truck),
                      ),
                    );
                  },
                  child: ListTile(
                    title: Text(truck.truckNumber),
                    subtitle: Text("Driver: ${truck.driverName}"),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AddTruckScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
