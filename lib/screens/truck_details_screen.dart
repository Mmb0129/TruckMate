import 'package:flutter/material.dart';
import 'truck_summary_screen.dart';
import '../models/truck_model.dart';
import 'add_trip_screen.dart';
import 'trip_list_screen.dart';

class TruckDetailsScreen extends StatelessWidget {
  final TruckModel truck;

  const TruckDetailsScreen({super.key, required this.truck});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(truck.truckNumber)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Driver: ${truck.driverName}", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TripListScreen(truckId: truck.id, truckNumber: truck.truckNumber),
                  ),
                );
              },
              child: const Text("View Trips"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddTripScreen(truckId: truck.id),
                  ),
                );
              },
              child: const Text("Add Trip"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TruckSummaryScreen(truckId: truck.id),
                  ),
                );
              },
              child: const Text("Monthly Summary"),
            ),

          ],
        ),
      ),
    );
  }
}
