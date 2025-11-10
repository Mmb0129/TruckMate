import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../models/truck_model.dart';
import 'truck_details_screen.dart';
import 'add_truck_screen.dart';

class _AvatarSourceSheet extends StatelessWidget {
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  const _AvatarSourceSheet({required this.onGallery, required this.onCamera});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Pick from gallery'),
            onTap: () {
              Navigator.pop(context);
              onGallery();
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take photo'),
            onTap: () {
              Navigator.pop(context);
              onCamera();
            },
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _pickAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final service = UserService();

    showModalBottomSheet(
      context: context,
      builder: (_) => _AvatarSourceSheet(
        onGallery: () async {
          final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
          if (x != null) await service.uploadAvatar(uid, File(x.path));
        },
        onCamera: () async {
          final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
          if (x != null) await service.uploadAvatar(uid, File(x.path));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final service = FirestoreService();

    return Scaffold(
      drawer: Drawer(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final data = snap.data!.data() as Map<String, dynamic>? ?? {};

            final owner = data['ownerName'] ?? '';
            final company = data['companyName'] ?? '';
            final phone = data['phone'] ?? '';
            final email = data['email'] ?? '';
            final avatarUrl = data['avatarUrl'];

            return SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : const AssetImage('assets/avatar_truck.png') as ImageProvider,
                  ),
                  const SizedBox(height: 10),
                  Text(company, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Owner: $owner"),
                  Text("Phone: $phone"),
                  if (email.isNotEmpty) Text("Email: $email"),
                  const Divider(height: 30),

                  // ListTile(
                  //   leading: const Icon(Icons.photo_camera),
                  //   title: const Text("Change photo"),
                  //   onTap: () => _pickAvatar(context),
                  // ),

                  // ListTile(
                  //   leading: const Icon(Icons.delete),
                  //   title: const Text("Remove photo"),
                  //   onTap: () {
                  //     FirebaseFirestore.instance.collection('users').doc(uid).update({
                  //       'avatarUrl': null,
                  //     });
                  //     Navigator.pop(context);
                  //   },
                  // ),

                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text("Logout", style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pop(context); // close drawer
                    },
                  ),

                ],
              ),
            );
          },
        ),
      ),

      appBar: AppBar(
        leading: Builder( // <-- important fix
          builder: (ctx) => GestureDetector(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const CircleAvatar();
                  final data = snap.data!.data() as Map<String, dynamic>? ?? {};
                  final avatarUrl = data['avatarUrl'];
                  return CircleAvatar(
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : const AssetImage('assets/avatar_truck.png') as ImageProvider,
                  );
                },
              ),
            ),
          ),
        ),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Text("...");
            final data = snap.data!.data() as Map<String, dynamic>? ?? {};
            final company = data['companyName'] ?? "TruckMate";
            return Text(company);
          },
        ),
      ),
      body: StreamBuilder<List<TruckModel>>(
        stream: service.getTrucks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final trucks = snapshot.data!;
          return ListView.builder(
            itemCount: trucks.length,
            itemBuilder: (context, index) {
              final truck = trucks[index];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TruckDetailsScreen(truck: truck),
                      ),
                    );
                  },
                  child: ListTile(
                    title: Text(truck.truckNumber),
                    subtitle: Text("Driver: ${truck.driverName}"),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AddTruckScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
