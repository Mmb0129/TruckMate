import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../services/firestore_service.dart';
import 'edit_trip_screen.dart';

class TripDetailsScreen extends StatelessWidget {
  final TripModel trip;
  final String truckId;

  const TripDetailsScreen({super.key, required this.truckId, required this.trip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditTripScreen(truckId: truckId, trip: trip),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Delete Trip"),
                  content: const Text("Are you sure you want to delete this trip?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                  ],
                ),
              );

              if (confirm == true) {
                final service = FirestoreService();
                await service.deleteTrip(truckId, trip.id);
                Navigator.pop(context); // close details screen
              }
            },
          ),
        ],

      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text("Loading: ${trip.loadingDate.day}-${trip.loadingDate.month}-${trip.loadingDate.year}", style: _s),
            Text("Unloading: ${trip.unloadingDate.day}-${trip.unloadingDate.month}-${trip.unloadingDate.year}", style: _s),
            const SizedBox(height: 10),
            Text("Source: ${trip.source}", style: _s),
            Text("Destination: ${trip.destination}", style: _s),
            Text("Party: ${trip.partyName}", style: _s),
            const SizedBox(height: 10),
            Text("Hire Amount: ₹${trip.hireAmount}", style: _s),
            Text("Advance From Office: ₹${trip.advanceFromOffice}", style: _s),
            Text("Payment to Driver: ₹${trip.paymentToDriver}", style: _s),
            const SizedBox(height: 10),
            Text("Extra Height/Weight: ${trip.extraHeightWeight}", style: _s),
            Text("Loading Mamul: ₹${trip.loadingMamul}", style: _s),
            Text("Unloading Mamul: ₹${trip.unloadingMamul}", style: _s),
            Text("Weighment Charge: ₹${trip.weighmentCharge}", style: _s),
            Text("Halting Days: ${trip.haltingDays}", style: _s),
            Text("Extra Payment to Driver: ₹${trip.extraPaymentToDriver}", style: _s),
          ],
        ),
      ),
    );
  }

  TextStyle get _s => const TextStyle(fontSize: 18);
}
