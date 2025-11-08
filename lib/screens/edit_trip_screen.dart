import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../services/firestore_service.dart';

class EditTripScreen extends StatefulWidget {
  final String truckId;
  final TripModel trip;

  const EditTripScreen({super.key, required this.truckId, required this.trip});

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
  late DateTime loadingDate;
  late DateTime unloadingDate;

  final service = FirestoreService();

  late TextEditingController src;
  late TextEditingController dest;
  late TextEditingController party;
  late TextEditingController hire;
  late TextEditingController advOffice;
  late TextEditingController payDriver;
  late TextEditingController extraHW;
  late TextEditingController loadingMamul;
  late TextEditingController unloadingMamul;
  late TextEditingController weighmentCharge;
  late TextEditingController haltingDays;
  late TextEditingController extraPayDriver;

  @override
  void initState() {
    super.initState();

    loadingDate = widget.trip.loadingDate;
    unloadingDate = widget.trip.unloadingDate;

    src = TextEditingController(text: widget.trip.source);
    dest = TextEditingController(text: widget.trip.destination);
    party = TextEditingController(text: widget.trip.partyName);
    hire = TextEditingController(text: widget.trip.hireAmount.toString());
    advOffice = TextEditingController(text: widget.trip.advanceFromOffice.toString());
    payDriver = TextEditingController(text: widget.trip.paymentToDriver.toString());
    extraHW = TextEditingController(text: widget.trip.extraHeightWeight);
    loadingMamul = TextEditingController(text: widget.trip.loadingMamul.toString());
    unloadingMamul = TextEditingController(text: widget.trip.unloadingMamul.toString());
    weighmentCharge = TextEditingController(text: widget.trip.weighmentCharge.toString());
    haltingDays = TextEditingController(text: widget.trip.haltingDays.toString());
    extraPayDriver = TextEditingController(text: widget.trip.extraPaymentToDriver.toString());
  }

  Future<void> pickDate(bool isLoading) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isLoading ? loadingDate : unloadingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isLoading) loadingDate = picked;
        else unloadingDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Trip")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () => pickDate(true),
              child: Text("Loading: ${loadingDate.day}-${loadingDate.month}-${loadingDate.year}"),
            ),
            ElevatedButton(
              onPressed: () => pickDate(false),
              child: Text("Unloading: ${unloadingDate.day}-${unloadingDate.month}-${unloadingDate.year}"),
            ),
            TextField(controller: src, decoration: const InputDecoration(labelText: "Source")),
            TextField(controller: dest, decoration: const InputDecoration(labelText: "Destination")),
            TextField(controller: party, decoration: const InputDecoration(labelText: "Party Name")),
            TextField(controller: hire, decoration: const InputDecoration(labelText: "Hire Amount"), keyboardType: TextInputType.number),
            TextField(controller: advOffice, decoration: const InputDecoration(labelText: "Advance From Office"), keyboardType: TextInputType.number),
            TextField(controller: payDriver, decoration: const InputDecoration(labelText: "Payment to Driver"), keyboardType: TextInputType.number),
            TextField(controller: extraHW, decoration: const InputDecoration(labelText: "Extra Height / Weight details")),
            TextField(controller: loadingMamul, decoration: const InputDecoration(labelText: "Loading Mamul"), keyboardType: TextInputType.number),
            TextField(controller: unloadingMamul, decoration: const InputDecoration(labelText: "Unloading Mamul"), keyboardType: TextInputType.number),
            TextField(controller: weighmentCharge, decoration: const InputDecoration(labelText: "Weighment Charge"), keyboardType: TextInputType.number),
            TextField(controller: haltingDays, decoration: const InputDecoration(labelText: "Halting (days)"), keyboardType: TextInputType.number),
            TextField(controller: extraPayDriver, decoration: const InputDecoration(labelText: "Extra Payment to Driver"), keyboardType: TextInputType.number),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final updatedTrip = TripModel(
                  id: widget.trip.id,
                  loadingDate: loadingDate,
                  unloadingDate: unloadingDate,
                  source: src.text,
                  destination: dest.text,
                  partyName: party.text,
                  hireAmount: double.tryParse(hire.text) ?? 0,
                  advanceFromOffice: double.tryParse(advOffice.text) ?? 0,
                  paymentToDriver: double.tryParse(payDriver.text) ?? 0,
                  extraHeightWeight: extraHW.text,
                  loadingMamul: double.tryParse(loadingMamul.text) ?? 0,
                  unloadingMamul: double.tryParse(unloadingMamul.text) ?? 0,
                  weighmentCharge: double.tryParse(weighmentCharge.text) ?? 0,
                  haltingDays: int.tryParse(haltingDays.text) ?? 0,
                  extraPaymentToDriver: double.tryParse(extraPayDriver.text) ?? 0,
                );

                await service.updateTrip(widget.truckId, updatedTrip);
                Navigator.pop(context);
              },
              child: const Text("Save Changes"),
            )
          ],
        ),
      ),
    );
  }
}
