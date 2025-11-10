import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../models/truck_model.dart';
import 'truck_details_screen.dart';
import 'add_truck_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final service = FirestoreService();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      drawer: Drawer(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data?.data() ?? {};
            final theme = Theme.of(context);
            final owner = data['ownerName'] as String? ?? '';
            final company = data['companyName'] as String? ?? '';
            final phone = data['phone'] as String? ?? '';
            final email = data['email'] as String? ?? '';
            final avatarUrl = data['avatarUrl'] as String?;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primaryContainer,
                            theme.colorScheme.surface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.35,
                                ),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.18,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 38,
                              backgroundColor: theme.colorScheme.surface,
                              backgroundImage: avatarUrl != null
                                  ? NetworkImage(avatarUrl)
                                  : const AssetImage('assets/avatar_truck.png')
                                        as ImageProvider,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            company.isEmpty ? 'TruckMate' : company,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(
                                0.12,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              owner.isEmpty
                                  ? 'Owner information pending'
                                  : 'Owner · $owner',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _DrawerInfoTile(
                      icon: Icons.phone,
                      label: 'Phone',
                      value: phone,
                    ),
                    if (email.isNotEmpty)
                      _DrawerInfoTile(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: email,
                      ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.12),
                        foregroundColor: Colors.red,
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Logout'),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 115,
        titleSpacing: 0,
        flexibleSpace: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer.withOpacity(0.65),
                  colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        leadingWidth: 74,
        leading: Builder(
          builder: (ctx) =>
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snap) {
                  final avatarUrl = snap.data?.data()?['avatarUrl'] as String?;
                  return IconButton(
                    padding: const EdgeInsets.only(left: 16, top: 24),
                    tooltip: 'Account & Settings',
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    iconSize: 52,
                    splashRadius: 28,
                    icon: CircleAvatar(
                      radius: 24,
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : const AssetImage('assets/avatar_truck.png')
                                as ImageProvider,
                    ),
                  );
                },
              ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 4, right: 20, top: 28),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data() ?? {};
              final company = data['companyName'] as String? ?? 'TruckMate';
              final owner = (data['ownerName'] as String? ?? '').trim();
              final ownerFirst = owner.isEmpty
                  ? 'there'
                  : owner.split(' ').first;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hello, $ownerFirst 👋',
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer.withOpacity(0.72),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    company,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Let’s manage your fleet efficiently today.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<TruckModel>>(
          stream: service.getTrucks(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final trucks = snapshot.data ?? [];
            if (trucks.isEmpty) {
              return _EmptyTrucksState(
                onAddPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddTruckScreen()),
                  );
                },
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
              itemCount: trucks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final truck = trucks[index];
                return _TruckCard(
                  truck: truck,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TruckDetailsScreen(truck: truck),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddTruckScreen()),
            );
          },
          icon: const Icon(Icons.local_shipping_rounded),
          label: const Text('Add Truck'),
        ),
      ),
    );
  }
}

class _DrawerInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DrawerInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasValue ? value : 'Not provided',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TruckCard extends StatelessWidget {
  final TruckModel truck;
  final VoidCallback onTap;

  const _TruckCard({required this.truck, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      truck.truckNumber,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Driver · ${truck.driverName}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[500]),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTrucksState extends StatelessWidget {
  final VoidCallback onAddPressed;

  const _EmptyTrucksState({required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 72,
              color: theme.colorScheme.primary.withOpacity(0.35),
            ),
            const SizedBox(height: 24),
            Text(
              'No trucks yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first truck to start tracking trips, finances and summaries.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a truck'),
            ),
          ],
        ),
      ),
    );
  }
}
