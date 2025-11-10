import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
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
  final _moneyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trips"),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_rounded),
            tooltip: 'Filter Months',
            onPressed: () => _openFilter(context),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<TripModel>>(
          stream: service.getTrips(widget.truckId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final trips = snapshot.data ?? [];

            final filtered =
                trips
                    .where(
                      (t) => selectedMonths.any(
                        (m) =>
                            t.loadingDate.month == m.month &&
                            t.loadingDate.year == m.year,
                      ),
                    )
                    .toList()
                  ..sort((a, b) => b.loadingDate.compareTo(a.loadingDate));

            if (filtered.isEmpty) {
              return _EmptyTripsState(
                onFilterTap: () => _openFilter(context),
                months: selectedMonths,
              );
            }

            final chips = selectedMonths
                .map(
                  (m) => InputChip(
                    avatar: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('MMM yyyy').format(m)),
                    onDeleted: selectedMonths.length > 1
                        ? () {
                            setState(() {
                              selectedMonths.removeWhere(
                                (x) => x.month == m.month && x.year == m.year,
                              );
                            });
                          }
                        : null,
                  ),
                )
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.truckNumber.isNotEmpty
                            ? widget.truckNumber
                            : 'Trips',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select trips to export as PDF or tap for details.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(spacing: 8, runSpacing: 8, children: chips),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final trip = filtered[i];
                      final selected = selectedTripIds.contains(trip.id);
                      return _TripCard(
                        trip: trip,
                        selected: selected,
                        dateFmt: _dateFmt,
                        moneyFmt: _moneyFmt,
                        onToggleSelected: (value) {
                          setState(() {
                            if (value) {
                              if (!selectedTripIds.contains(trip.id)) {
                                selectedTripIds.add(trip.id);
                              }
                            } else {
                              selectedTripIds.remove(trip.id);
                            }
                          });
                        },
                        onViewDetails: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripDetailsScreen(
                                truckId: widget.truckId,
                                trip: trip,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: selectedTripIds.isNotEmpty
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Export PDF"),
              onPressed: () async {
                final trips = await _collectSelectedTrips(
                  widget.truckId,
                  selectedTripIds,
                );
                if (trips.isEmpty) return;
                await _generateSaveAndSharePdf(
                  context: context,
                  truckNumber: widget.truckNumber.isNotEmpty
                      ? widget.truckNumber
                      : widget.truckId,
                  trips: trips,
                );
              },
            )
          : null,
    );
  }

  Future<void> _openFilter(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: MonthSelector(
          selected: selectedMonths,
          onChanged: (newList) {
            setState(() => selectedMonths = newList);
          },
        ),
      ),
    );
  }

  Future<List<TripModel>> _collectSelectedTrips(
    String truckId,
    List<String> ids,
  ) async {
    // We already have the stream’s data in the UI, but to be safe (and avoid passing big lists around)
    // we fetch again by filtering current snapshot from FirestoreService (optional).
    // If your FirestoreService exposes a one-shot getter, you can use that instead.
    final service = FirestoreService();
    final all = await service.getTrips(truckId).first;
    return all.where((t) => ids.contains(t.id)).toList()..sort(
      (a, b) => a.loadingDate.compareTo(b.loadingDate),
    ); // sort oldest→newest for PDF
  }

  Future<void> _generateSaveAndSharePdf({
    required BuildContext context,
    required String truckNumber,
    required List<TripModel> trips,
  }) async {
    final font = await rootBundle.load(
      "assets/fonts/NotoSansTamil-Regular.ttf",
    );
    final ttf = pw.Font.ttf(font);

    final doc = pw.Document();

    // Totals for a small summary at top (optional)
    final totalHire = trips.fold<double>(0, (s, t) => s + t.hireAmount);
    final totalAdv = trips.fold<double>(0, (s, t) => s + t.advanceFromOffice);
    final balance = totalHire - totalAdv;

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
            style: pw.TextStyle(
              fontSize: 10,
              font: ttf,
              color: PdfColors.grey600,
            ),
          ),
        ),

        build: (context) => [
          // Header
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  "MMM Trailer Service",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    font: ttf,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  "Trip Statement – $truckNumber",
                  style: pw.TextStyle(fontSize: 14, font: ttf),
                ),
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
                pw.Text(
                  "Trips: ${trips.length}",
                  style: pw.TextStyle(font: ttf),
                ),
                pw.Text(
                  "Total Hire: ${_moneyFmt.format(totalHire)}",
                  style: pw.TextStyle(font: ttf),
                ),
                pw.Text(
                  "Total Advance: ${_moneyFmt.format(totalAdv)}",
                  style: pw.TextStyle(font: ttf),
                ),
                pw.Text(
                  "Balance: ${_moneyFmt.format(balance)}",
                  style: pw.TextStyle(font: ttf),
                ),
              ],
            ),
          ),
          gap(12),

          gap(10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Generated on: ${DateFormat('dd-MM-yyyy  hh:mm a').format(DateTime.now())}",
              style: pw.TextStyle(
                fontSize: 10,
                font: ttf,
                color: PdfColors.grey600,
              ),
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
                      pw.Text(
                        "Load: ${fmt(t.loadingDate)}",
                        style: pw.TextStyle(font: ttf),
                      ),
                      pw.Text(
                        "Unload: ${fmt(t.unloadingDate)}",
                        style: pw.TextStyle(font: ttf),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "${t.source} to ${t.destination}",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      font: ttf,
                    ),
                  ),
                  if ((t.partyName).trim().isNotEmpty)
                    pw.Text(
                      "Party: ${t.partyName}",
                      style: pw.TextStyle(font: ttf),
                    ),
                  gap(6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "Hire: ${currency(t.hireAmount)}",
                        style: pw.TextStyle(font: ttf),
                      ),
                      pw.Text(
                        "Advance: ${currency(t.advanceFromOffice)}",
                        style: pw.TextStyle(font: ttf),
                      ),
                    ],
                  ),
                  gap(4),
                  pw.Wrap(
                    spacing: 16,
                    runSpacing: 2,
                    children: [
                      if ((t.extraHeightWeight).trim().isNotEmpty)
                        pw.Text(
                          "Extra HW: ${t.extraHeightWeight}",
                          style: pw.TextStyle(font: ttf),
                        ),
                      if ((t.loadingMamul) != 0)
                        pw.Text(
                          "Load Mamul: ${currency(t.loadingMamul)}",
                          style: pw.TextStyle(font: ttf),
                        ),
                      if ((t.unloadingMamul) != 0)
                        pw.Text(
                          "Unload Mamul: ${currency(t.unloadingMamul)}",
                          style: pw.TextStyle(font: ttf),
                        ),
                      if ((t.weighmentCharge) != 0)
                        pw.Text(
                          "Weighment: ${currency(t.weighmentCharge)}",
                          style: pw.TextStyle(font: ttf),
                        ),
                      if ((t.haltingDays) != 0)
                        pw.Text(
                          "Halting: ${t.haltingDays} days",
                          style: pw.TextStyle(font: ttf),
                        ),
                      if ((t.extraPaymentToDriver) != 0)
                        pw.Text(
                          "ExtraPayDrv: ${currency(t.extraPaymentToDriver)}",
                          style: pw.TextStyle(font: ttf),
                        ),
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
    String filename =
        'Trip_Statement_${_safeFileName(truckNumber)}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

    Directory? saveDir;
    try {
      // On Android, getExternalStorageDirectory works; Downloads dir via printing might be better cross-platform
      saveDir = await getDownloadsDirectory(); // Desktop/iOS sometimes null
    } catch (_) {}

    saveDir ??= await getExternalStorageDirectory(); // Android app external
    final directory =
        saveDir ??
        await getApplicationDocumentsDirectory(); // ultimate fallback

    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);

    // Share sheet (opens WhatsApp/Gmail/etc.)
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Trip Statement – $truckNumber');

    // Also offer native print/preview if you want (optional):
    // await Printing.layoutPdf(onLayout: (_) async => bytes);

    // Feedback
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved: ${file.path}')));
    }
  }

  String _safeFileName(String s) =>
      s.replaceAll(RegExp(r'[^\w\-\.\(\) ]+'), '_');
}

class _TripCard extends StatelessWidget {
  final TripModel trip;
  final bool selected;
  final DateFormat dateFmt;
  final NumberFormat moneyFmt;
  final ValueChanged<bool> onToggleSelected;
  final VoidCallback onViewDetails;

  const _TripCard({
    required this.trip,
    required this.selected,
    required this.dateFmt,
    required this.moneyFmt,
    required this.onToggleSelected,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: selected ? 2 : 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => onToggleSelected(!selected),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onChanged: (v) => onToggleSelected(v ?? false),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trip.source} → ${trip.destination}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dateFmt.format(trip.loadingDate)}  ·  Hire ${moneyFmt.format(trip.hireAmount)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _PillChip(
                          icon: Icons.currency_rupee_rounded,
                          label:
                              'Advance ${moneyFmt.format(trip.advanceFromOffice)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onViewDetails,
                icon: const Icon(Icons.info_outline),
                tooltip: 'View details',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PillChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTripsState extends StatelessWidget {
  final VoidCallback onFilterTap;
  final List<DateTime> months;

  const _EmptyTripsState({required this.onFilterTap, required this.months});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = months.isEmpty
        ? 'No months selected'
        : months.map((m) => DateFormat('MMM yyyy').format(m)).join(', ');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route_rounded,
              size: 72,
              color: theme.colorScheme.primary.withOpacity(0.2),
            ),
            const SizedBox(height: 20),
            Text(
              'No trips found',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We couldn’t find trips for $label. Try adjusting your month filter or add a new trip.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onFilterTap,
              icon: const Icon(Icons.filter_alt_rounded),
              label: const Text('Adjust filter'),
            ),
          ],
        ),
      ),
    );
  }
}
