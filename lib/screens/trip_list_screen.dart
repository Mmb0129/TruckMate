import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../services/firestore_service.dart';
import '../models/trip_model.dart';
import 'trip_details_screen.dart';
import '../widgets/month_selector.dart';

class TripListScreen extends StatefulWidget {
  final String truckId;
  final String truckNumber; // pass the readable truck number if you have it

  const TripListScreen({
    super.key,
    required this.truckId,
    this.truckNumber = "",
  });

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  List<DateTime> selectedMonths = [];
  final List<String> selectedTripIds = [];

  @override
  void initState() {
    super.initState();
    selectedMonths = [DateTime(DateTime.now().year, DateTime.now().month)];
  }

  final _dateFmt = DateFormat('dd-MM-yyyy');
  final _moneyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trips"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
                  child: MonthSelector(
                    selected: selectedMonths,
                    onChanged: (newList) {
                      setState(() => selectedMonths = newList);
                    },
                  ),
                ),
              );
            },
            tooltip: 'Filter Months',
          ),
        ],
      ),
      body: StreamBuilder<List<TripModel>>(
        stream: service.getTrips(widget.truckId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final trips = snapshot.data!;

          final filtered = trips.where((t) {
            return selectedMonths.any((m) =>
            t.loadingDate.month == m.month && t.loadingDate.year == m.year
            );
          }).toList()
            ..sort((a, b) => b.loadingDate.compareTo(a.loadingDate)); // newest first

          if (filtered.isEmpty) {
            return const Center(child: Text("No trips in selected period"));
          }

          // header chips (selected months)
          final chips = selectedMonths
              .map((m) => Chip(label: Text("${m.month}-${m.year}")))
              .toList();

          return Column(
            children: [
              if (chips.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(spacing: 8, runSpacing: 6, children: chips),
                  ),
                ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final trip = filtered[i];
                    final selected = selectedTripIds.contains(trip.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            if (!selectedTripIds.contains(trip.id)) {
                              selectedTripIds.add(trip.id);
                            }
                          } else {
                            selectedTripIds.remove(trip.id);
                          }
                        });
                      },
                      title: Text("${trip.source} → ${trip.destination}"),
                      subtitle: Text(
                        "${_dateFmt.format(trip.loadingDate)}"
                            "  |  Hire: ${_moneyFmt.format(trip.hireAmount)}"
                            "  |  Adv: ${_moneyFmt.format(trip.advanceFromOffice)}",
                      ),
                      secondary: IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripDetailsScreen(truckId: widget.truckId, trip: trip),
                            ),
                          );
                        },
                        tooltip: 'View details',
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: selectedTripIds.isNotEmpty
          ? FloatingActionButton.extended(
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text("Export PDF"),
        onPressed: () async {
          final trips = await _collectSelectedTrips(widget.truckId, selectedTripIds);
          if (trips.isEmpty) return;
          await _generateSaveAndSharePdf(
            context: context,
            truckNumber: widget.truckNumber.isNotEmpty ? widget.truckNumber : widget.truckId,
            trips: trips,
          );
        },
      )
          : null,
    );
  }

  Future<List<TripModel>> _collectSelectedTrips(String truckId, List<String> ids) async {
    // We already have the stream’s data in the UI, but to be safe (and avoid passing big lists around)
    // we fetch again by filtering current snapshot from FirestoreService (optional).
    // If your FirestoreService exposes a one-shot getter, you can use that instead.
    final service = FirestoreService();
    final all = await service.getTrips(truckId).first;
    return all.where((t) => ids.contains(t.id)).toList()
      ..sort((a, b) => a.loadingDate.compareTo(b.loadingDate)); // sort oldest→newest for PDF
  }

  Future<void> _generateSaveAndSharePdf({
    required BuildContext context,
    required String truckNumber,
    required List<TripModel> trips,
  }) async {
    final font = await rootBundle.load("assets/fonts/NotoSansTamil-Regular.ttf");
    final ttf = pw.Font.ttf(font);

    final doc = pw.Document();


    // Totals for a small summary at top (optional)
    final totalHire = trips.fold<double>(0, (s, t) => s + t.hireAmount);
    final totalAdv  = trips.fold<double>(0, (s, t) => s + t.advanceFromOffice);
    final balance   = totalHire - totalAdv;

    pw.Widget gap(double h) => pw.SizedBox(height: h);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          theme: pw.ThemeData(defaultTextStyle: pw.TextStyle(font: ttf)),
        ),

        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            "Page ${context.pageNumber} of ${context.pagesCount}",
            style: pw.TextStyle(fontSize: 10, font: ttf, color: PdfColors.grey600),
          ),
        ),

        build: (context) => [

          // Header
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text("MMM Trailer Service",
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, font: ttf,)),
                pw.SizedBox(height: 4),
                pw.Text("Trip Statement – $truckNumber",
                    style: pw.TextStyle(fontSize: 14, font: ttf,)),
              ],
            ),
          ),
          gap(14),
          // Totals line
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Trips: ${trips.length}", style: pw.TextStyle(font: ttf)),
                pw.Text("Total Hire: ${_moneyFmt.format(totalHire)}", style: pw.TextStyle(font: ttf)),
                pw.Text("Total Advance: ${_moneyFmt.format(totalAdv)}", style: pw.TextStyle(font: ttf)),
                pw.Text("Balance: ${_moneyFmt.format(balance)}", style: pw.TextStyle(font: ttf)),
              ],
            ),
          ),
          gap(12),

          gap(10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Generated on: ${DateFormat('dd-MM-yyyy  hh:mm a').format(DateTime.now())}",
              style: pw.TextStyle(fontSize: 10, font: ttf, color: PdfColors.grey600),
            ),
          ),
          gap(6),

          // Each Trip as a Block
          ...trips.map((t) {
            String fmt(DateTime d) => DateFormat('dd-MM-yyyy').format(d);
            String currency(num v) => _moneyFmt.format(v);

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("Load: ${fmt(t.loadingDate)}", style: pw.TextStyle(font: ttf)),
                      pw.Text("Unload: ${fmt(t.unloadingDate)}", style: pw.TextStyle(font: ttf)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text("${t.source} to ${t.destination}",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttf,)),
                  if ((t.partyName).trim().isNotEmpty)
                    pw.Text("Party: ${t.partyName}", style: pw.TextStyle(font: ttf)),
                  gap(6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("Hire: ${currency(t.hireAmount)}", style: pw.TextStyle(font: ttf)),
                      pw.Text("Advance: ${currency(t.advanceFromOffice)}", style: pw.TextStyle(font: ttf)),
                    ],
                  ),
                  gap(4),
                  pw.Wrap(
                    spacing: 16,
                    runSpacing: 2,
                    children: [
                      if ((t.extraHeightWeight).trim().isNotEmpty)
                        pw.Text("Extra HW: ${t.extraHeightWeight}", style: pw.TextStyle(font: ttf)),
                      if ((t.loadingMamul) != 0) pw.Text("Load Mamul: ${currency(t.loadingMamul)}", style: pw.TextStyle(font: ttf)),
                      if ((t.unloadingMamul) != 0) pw.Text("Unload Mamul: ${currency(t.unloadingMamul)}", style: pw.TextStyle(font: ttf)),
                      if ((t.weighmentCharge) != 0) pw.Text("Weighment: ${currency(t.weighmentCharge)}", style: pw.TextStyle(font: ttf)),
                      if ((t.haltingDays) != 0) pw.Text("Halting: ${t.haltingDays} days", style: pw.TextStyle(font: ttf)),
                      if ((t.extraPaymentToDriver) != 0) pw.Text("ExtraPayDrv: ${currency(t.extraPaymentToDriver)}", style: pw.TextStyle(font: ttf)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );

    // Save to a sensible location
    final bytes = await doc.save();

    // Prefer public Downloads on Android; fallback to external/app dir elsewhere.
    String filename = 'Trip_Statement_${_safeFileName(truckNumber)}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    Directory? saveDir;
    try {
      // On Android, getExternalStorageDirectory works; Downloads dir via printing might be better cross-platform
      saveDir = await getDownloadsDirectory(); // Desktop/iOS sometimes null
    } catch (_) {}

    saveDir ??= await getExternalStorageDirectory(); // Android app external
    saveDir ??= await getApplicationDocumentsDirectory(); // ultimate fallback

    final file = File('${saveDir!.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);

    // Share sheet (opens WhatsApp/Gmail/etc.)
    await Share.shareXFiles([XFile(file.path)], text: 'Trip Statement – $truckNumber');

    // Also offer native print/preview if you want (optional):
    // await Printing.layoutPdf(onLayout: (_) async => bytes);

    // Feedback
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: ${file.path}')),
      );
    }
  }

  String _safeFileName(String s) =>
      s.replaceAll(RegExp(r'[^\w\-\.\(\) ]+'), '_');
}
