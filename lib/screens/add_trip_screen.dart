import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  final _formKey = GlobalKey<FormState>();
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
  bool _isSubmitting = false;

  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void dispose() {
    _src.dispose();
    _dest.dispose();
    _party.dispose();
    _hire.dispose();
    _advOffice.dispose();
    _payDriver.dispose();
    _extraHW.dispose();
    _loadingMamul.dispose();
    _unloadingMamul.dispose();
    _weighmentCharge.dispose();
    _haltingDays.dispose();
    _extraPayDriver.dispose();
    super.dispose();
  }

  Future<void> pickDate(bool isLoading) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isLoading
          ? (loadingDate ?? DateTime.now())
          : (unloadingDate ?? loadingDate ?? DateTime.now()),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (loadingDate == null || unloadingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both loading and unloading dates'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final trip = TripModel(
        id: "",
        loadingDate: loadingDate!,
        unloadingDate: unloadingDate!,
        source: _src.text.trim(),
        destination: _dest.text.trim(),
        partyName: _party.text.trim(),
        hireAmount: double.tryParse(_hire.text) ?? 0,
        advanceFromOffice: double.tryParse(_advOffice.text) ?? 0,
        paymentToDriver: double.tryParse(_payDriver.text) ?? 0,
        extraHeightWeight: _extraHW.text.trim(),
        loadingMamul: double.tryParse(_loadingMamul.text) ?? 0,
        unloadingMamul: double.tryParse(_unloadingMamul.text) ?? 0,
        weighmentCharge: double.tryParse(_weighmentCharge.text) ?? 0,
        haltingDays: int.tryParse(_haltingDays.text) ?? 0,
        extraPaymentToDriver: double.tryParse(_extraPayDriver.text) ?? 0,
      );

      await _service.addTrip(widget.truckId, trip);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Trip')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer.withOpacity(0.9),
                        colorScheme.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.1),
                        blurRadius: 26,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: colorScheme.onPrimary.withOpacity(
                          0.08,
                        ),
                        child: Icon(
                          Icons.route_rounded,
                          color: colorScheme.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Create a new trip',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Record trip details, financials, and other information.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Dates Section
                _SectionHeader(
                  icon: Icons.calendar_today_rounded,
                  title: 'Dates',
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DatePickerButton(
                          label: 'Loading Date',
                          date: loadingDate,
                          dateFmt: _dateFmt,
                          icon: Icons.upload_rounded,
                          color: colorScheme.primary,
                          onTap: () => pickDate(true),
                        ),
                        const SizedBox(height: 12),
                        _DatePickerButton(
                          label: 'Unloading Date',
                          date: unloadingDate,
                          dateFmt: _dateFmt,
                          icon: Icons.download_rounded,
                          color: colorScheme.secondary,
                          onTap: () => pickDate(false),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Route Information
                _SectionHeader(
                  icon: Icons.map_rounded,
                  title: 'Route Information',
                  color: colorScheme.tertiary,
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _src,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Source',
                            hintText: 'Enter source location',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Source is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _dest,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Destination',
                            hintText: 'Enter destination location',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Destination is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _party,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Party Name',
                            hintText: 'Enter party/customer name',
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Financials
                _SectionHeader(
                  icon: Icons.currency_rupee_rounded,
                  title: 'Financials',
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _hire,
                          textInputAction: TextInputAction.next,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Hire Amount',
                            hintText: '0',
                            prefixIcon: Icon(Icons.payments_outlined),
                            prefixText: '₹ ',
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _advOffice,
                          textInputAction: TextInputAction.next,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Advance From Office',
                            hintText: '0',
                            prefixIcon: Icon(
                              Icons.account_balance_wallet_outlined,
                            ),
                            prefixText: '₹ ',
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _payDriver,
                          textInputAction: TextInputAction.next,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Payment to Driver',
                            hintText: '0',
                            prefixIcon: Icon(Icons.person_outline),
                            prefixText: '₹ ',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Other Details
                _SectionHeader(
                  icon: Icons.info_outline_rounded,
                  title: 'Other Details',
                  color: colorScheme.secondary,
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _extraHW,
                          textInputAction: TextInputAction.next,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Extra Height / Weight',
                            hintText: 'Enter details if any',
                            prefixIcon: Icon(Icons.height_outlined),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _loadingMamul,
                                textInputAction: TextInputAction.next,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Loading Mamul',
                                  hintText: '0',
                                  prefixText: '₹ ',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _unloadingMamul,
                                textInputAction: TextInputAction.next,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Unloading Mamul',
                                  hintText: '0',
                                  prefixText: '₹ ',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _weighmentCharge,
                          textInputAction: TextInputAction.next,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Weighment Charge',
                            hintText: '0',
                            prefixIcon: Icon(Icons.scale_outlined),
                            prefixText: '₹ ',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _haltingDays,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Halting Days',
                                  hintText: '0',
                                  prefixIcon: Icon(Icons.hotel_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _extraPayDriver,
                                textInputAction: TextInputAction.done,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Extra Payment to Driver',
                                  hintText: '0',
                                  prefixText: '₹ ',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _isSubmitting ? 'Saving Trip…' : 'Save Trip',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final DateFormat dateFmt;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DatePickerButton({
    required this.label,
    required this.date,
    required this.dateFmt,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: date != null
                ? color.withOpacity(0.3)
                : theme.colorScheme.outline.withOpacity(0.2),
          ),
          borderRadius: BorderRadius.circular(16),
          color: date != null ? color.withOpacity(0.08) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date != null ? dateFmt.format(date!) : 'Select date',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: date != null
                          ? color
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.calendar_today_rounded,
              color: color.withOpacity(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
