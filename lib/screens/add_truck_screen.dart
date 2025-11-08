import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class AddTruckScreen extends StatefulWidget {
  const AddTruckScreen({super.key});

  @override
  State<AddTruckScreen> createState() => _AddTruckScreenState();
}

class _AddTruckScreenState extends State<AddTruckScreen> {
  final _truckNumberController = TextEditingController();
  final _driverNameController = TextEditingController();
  final _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Truck")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _truckNumberController,
              decoration: const InputDecoration(labelText: "Truck Number"),
            ),
            TextField(
              controller: _driverNameController,
              decoration: const InputDecoration(labelText: "Driver Name"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _service.addTruck(
                  _truckNumberController.text,
                  _driverNameController.text,
                );
                Navigator.pop(context);
              },
              child: const Text("Save"),
            )
          ],
        ),
      ),
    );
  }
}
