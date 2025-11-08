import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/trip_model.dart';

class AddTripScreen extends StatefulWidget {
  final String truckId;
  const AddTripScreen({super.key, required this.truckId});

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  DateTime? loadingDate;
  DateTime? unloadingDate;

  final _src = TextEditingController();
  final _dest = TextEditingController();
  final _party = TextEditingController();
  final _hire = TextEditingController();
  final _advOffice = TextEditingController();
  final _payDriver = TextEditingController();
  final _extraHW = TextEditingController();
  final _loadingMamul = TextEditingController();
  final _unloadingMamul = TextEditingController();
  final _weighmentCharge = TextEditingController();
  final _haltingDays = TextEditingController();
  final _extraPayDriver = TextEditingController();

  final _service = FirestoreService();

  Future<void> pickDate(bool isLoading) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isLoading) {
          loadingDate = picked;
        } else {
          unloadingDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Trip")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => pickDate(true),
                    child: Text(
                      loadingDate == null
                          ? "Select Loading Date"
                          : "Loading: ${loadingDate!.day}-${loadingDate!.month}-${loadingDate!.year}",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => pickDate(false),
                    child: Text(
                      unloadingDate == null
                          ? "Select Unloading Date"
                          : "Unloading: ${unloadingDate!.day}-${unloadingDate!.month}-${unloadingDate!.year}",
                    ),
                  ),
                ),
              ],
            ),
            TextField(controller: _src, decoration: const InputDecoration(labelText: "Source")),
            TextField(controller: _dest, decoration: const InputDecoration(labelText: "Destination")),
            TextField(controller: _party, decoration: const InputDecoration(labelText: "Party Name")),
            TextField(controller: _hire, decoration: const InputDecoration(labelText: "Hire Amount"), keyboardType: TextInputType.number),
            TextField(controller: _advOffice, decoration: const InputDecoration(labelText: "Advance From Office"), keyboardType: TextInputType.number),
            TextField(controller: _payDriver, decoration: const InputDecoration(labelText: "Payment to Driver"), keyboardType: TextInputType.number),
            TextField(controller: _extraHW, decoration: const InputDecoration(labelText: "Extra Height / Weight details")),
            TextField(controller: _loadingMamul, decoration: const InputDecoration(labelText: "Loading Mamul"), keyboardType: TextInputType.number),
            TextField(controller: _unloadingMamul, decoration: const InputDecoration(labelText: "Unloading Mamul"), keyboardType: TextInputType.number),
            TextField(controller: _weighmentCharge, decoration: const InputDecoration(labelText: "Weighment Charge"), keyboardType: TextInputType.number),
            TextField(controller: _haltingDays, decoration: const InputDecoration(labelText: "Halting (days)"), keyboardType: TextInputType.number),
            TextField(controller: _extraPayDriver, decoration: const InputDecoration(labelText: "Extra Payment to Driver"), keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (loadingDate == null || unloadingDate == null) return;

                final trip = TripModel(
                  id: "",
                  loadingDate: loadingDate!,
                  unloadingDate: unloadingDate!,
                  source: _src.text,
                  destination: _dest.text,
                  partyName: _party.text,
                  hireAmount: double.tryParse(_hire.text) ?? 0,
                  advanceFromOffice: double.tryParse(_advOffice.text) ?? 0,
                  paymentToDriver: double.tryParse(_payDriver.text) ?? 0,
                  extraHeightWeight: _extraHW.text,
                  loadingMamul: double.tryParse(_loadingMamul.text) ?? 0,
                  unloadingMamul: double.tryParse(_unloadingMamul.text) ?? 0,
                  weighmentCharge: double.tryParse(_weighmentCharge.text) ?? 0,
                  haltingDays: int.tryParse(_haltingDays.text) ?? 0,
                  extraPaymentToDriver: double.tryParse(_extraPayDriver.text) ?? 0,
                );

                await _service.addTrip(widget.truckId, trip);
                Navigator.pop(context);
              },
              child: const Text("Save Trip"),
            )
          ],
        ),
      ),
    );
  }
}
