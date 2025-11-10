import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip_model.dart';
import '../services/firestore_service.dart';
import 'edit_trip_screen.dart';

class TripDetailsScreen extends StatelessWidget {
  final TripModel trip;
  final String truckId;

  const TripDetailsScreen({
    super.key,
    required this.truckId,
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFmt = DateFormat('dd MMM yyyy');

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
                  content: const Text(
                    "Are you sure you want to delete this trip?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        "Delete",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trip.source} → ${trip.destination}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            icon: Icons.calendar_month_rounded,
                            label:
                                'Loading · ${dateFmt.format(trip.loadingDate)}',
                            foreground: colorScheme.primary,
                          ),
                          _InfoChip(
                            icon: Icons.event_available_rounded,
                            label:
                                'Unloading · ${dateFmt.format(trip.unloadingDate)}',
                            foreground: colorScheme.secondary,
                          ),
                          if (trip.partyName.trim().isNotEmpty)
                            _InfoChip(
                              icon: Icons.business_center_outlined,
                              label: 'Party · ${trip.partyName}',
                              foreground: colorScheme.tertiary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Financials',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Hire Amount',
                        value: _currency(trip.hireAmount),
                        icon: Icons.attach_money_rounded,
                        color: colorScheme.primary,
                      ),
                      const Divider(height: 28),
                      _DetailRow(
                        label: 'Advance From Office',
                        value: _currency(trip.advanceFromOffice),
                        icon: Icons.account_balance_wallet_rounded,
                        color: colorScheme.secondary,
                      ),
                      const Divider(height: 28),
                      _DetailRow(
                        label: 'Payment to Driver',
                        value: _currency(trip.paymentToDriver),
                        icon: Icons.payments_rounded,
                        color: colorScheme.tertiary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Other Details',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Extra Height / Weight',
                        value: trip.extraHeightWeight.isEmpty
                            ? 'Not specified'
                            : trip.extraHeightWeight,
                        icon: Icons.height_rounded,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 18),
                      _DetailRow(
                        label: 'Loading Mamul',
                        value: _currency(trip.loadingMamul),
                        icon: Icons.upload_rounded,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(height: 18),
                      _DetailRow(
                        label: 'Unloading Mamul',
                        value: _currency(trip.unloadingMamul),
                        icon: Icons.download_rounded,
                        color: colorScheme.tertiary,
                      ),
                      const SizedBox(height: 18),
                      _DetailRow(
                        label: 'Weighment Charge',
                        value: _currency(trip.weighmentCharge),
                        icon: Icons.scale_rounded,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 18),
                      _DetailRow(
                        label: 'Halting Days',
                        value: '${trip.haltingDays}',
                        icon: Icons.more_time_rounded,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(height: 18),
                      _DetailRow(
                        label: 'Extra Payment to Driver',
                        value: _currency(trip.extraPaymentToDriver),
                        icon: Icons.wallet_giftcard_rounded,
                        color: colorScheme.tertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _currency(num value) => NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  ).format(value);
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foreground;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: foreground.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
