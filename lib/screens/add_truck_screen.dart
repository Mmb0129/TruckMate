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
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _truckNumberController.dispose();
    _driverNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: colorScheme.surfaceVariant.withOpacity(0.25),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Add Truck')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 28,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer.withOpacity(0.92),
                            colorScheme.surface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.16),
                            blurRadius: 32,
                            offset: const Offset(0, 18),
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
                              Icons.local_shipping_rounded,
                              color: colorScheme.primary,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Create a new truck profile',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Keep your fleet organised by adding the truck number and driver name. This helps link trips, finances and summaries effortlessly.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              _QuickTip(label: 'Use uppercase letters'),
                              _QuickTip(label: 'Double-check registration'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: -18,
                      child: Container(
                        height: 72,
                        width: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withOpacity(0.12),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.28),
                          ),
                        ),
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _truckNumberController,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Truck Number',
                              hintText: 'TN01AB1234',
                              prefixIcon: Icon(
                                Icons.confirmation_number_outlined,
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Truck number is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: _driverNameController,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Driver Name',
                              hintText: 'Enter driver full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Driver name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : () async {
                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }
                                      FocusScope.of(context).unfocus();
                                      setState(() => _isSubmitting = true);
                                      try {
                                        await _service.addTruck(
                                          _truckNumberController.text.trim(),
                                          _driverNameController.text.trim(),
                                        );
                                        if (mounted) Navigator.pop(context);
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isSubmitting = false);
                                        }
                                      }
                                    },
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: _isSubmitting
                                    ? SizedBox(
                                        key: const ValueKey('loader'),
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            colorScheme.onPrimary,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.check_rounded,
                                        key: ValueKey('icon'),
                                      ),
                              ),
                              label: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Text(
                                  _isSubmitting ? 'Saving…' : 'Save Truck',
                                  key: ValueKey(_isSubmitting),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _isSubmitting
                                ? null
                                : () {
                                    _formKey.currentState?.reset();
                                    _truckNumberController.clear();
                                    _driverNameController.clear();
                                  },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Clear form'),
                          ),
                        ],
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

class _QuickTip extends StatelessWidget {
  final String label;

  const _QuickTip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.primary.withOpacity(0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
