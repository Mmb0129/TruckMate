import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/trip_model.dart';

class TruckSummaryScreen extends StatefulWidget {
  final String truckId;
  const TruckSummaryScreen({super.key, required this.truckId});

  @override
  State<TruckSummaryScreen> createState() => _TruckSummaryScreenState();
}

class _TruckSummaryScreenState extends State<TruckSummaryScreen> {
  DateTime selectedMonth = DateTime.now();
  double totalHire = 0;
  double totalAdvance = 0;

  final service = FirestoreService();

  void calculate(List<TripModel> trips) {
    final filtered = trips.where((t) =>
    t.loadingDate.month == selectedMonth.month &&
        t.loadingDate.year == selectedMonth.year
    );

    double hire = 0;
    double adv = 0;

    for (var t in filtered) {
      hire += t.hireAmount;
      adv += t.advanceFromOffice;
    }

    setState(() {
      totalHire = hire;
      totalAdvance = adv;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Monthly Summary")),
      body: StreamBuilder<List<TripModel>>(
        stream: service.getTrips(widget.truckId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final trips = snapshot.data!;
            final filtered = trips.where((t) =>
            t.loadingDate.month == selectedMonth.month &&
                t.loadingDate.year == selectedMonth.year
            );

            double totalHire = filtered.fold(0, (sum, t) => sum + t.hireAmount);
            double totalAdvance = filtered.fold(0, (sum, t) => sum + t.advanceFromOffice);
            double balance = totalHire - totalAdvance;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Month: ${selectedMonth.month}-${selectedMonth.year}", style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 20),
                  Text("Total Hire: ₹$totalHire", style: const TextStyle(fontSize: 18)),
                  Text("Total Advance: ₹$totalAdvance", style: const TextStyle(fontSize: 18)),
                  Text("Balance: ₹$balance", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      onPressed: () async {
                        final picked = await showDialog<DateTime>(
                          context: context,
                          builder: (context) {
                            DateTime temp = selectedMonth;
                            return AlertDialog(
                              title: const Text("Select Month"),
                              content: SizedBox(
                                height: 150,
                                child: Column(
                                  children: [
                                    DropdownButton<int>(
                                      value: temp.month,
                                      items: List.generate(12, (i) => i + 1)
                                          .map((m) => DropdownMenuItem(value: m, child: Text("Month $m")))
                                          .toList(),
                                      onChanged: (v) {
                                        temp = DateTime(temp.year, v!);
                                        setState(() {});
                                      },
                                    ),
                                    DropdownButton<int>(
                                      value: temp.year,
                                      items: List.generate(20, (i) => 2020 + i)
                                          .map((y) => DropdownMenuItem(value: y, child: Text("$y")))
                                          .toList(),
                                      onChanged: (v) {
                                        temp = DateTime(v!, temp.month);
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancel")),
                                ElevatedButton(
                                    onPressed: () => Navigator.pop(context, temp),
                                    child: const Text("OK")),
                              ],
                            );
                          },
                        );

                        if (picked != null) {
                          setState(() => selectedMonth = picked);
                        }
                      },
                      child: const Text("Select Month"),
                  )
                ],
              ),
            );
          }

      ),
    );
  }
}
