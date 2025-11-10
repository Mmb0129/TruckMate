import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _ownerCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _busy = false;

  Future<void> _save() async {
    final owner = _ownerCtrl.text.trim();
    final company = _companyCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (owner.isEmpty || company.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Owner & Company are required')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser!;
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'ownerName': owner,
        'companyName': company,
        'email': email,
        'phone': user.phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context); // go back to AuthGate

      }
      // back to AuthGate -> Home
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _ownerCtrl.dispose();
    _companyCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Setup')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Phone: $phone', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: _ownerCtrl,
              decoration: const InputDecoration(
                labelText: 'Owner Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _companyCtrl,
              decoration: const InputDecoration(
                labelText: 'Company Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_busy ? 'Saving…' : 'Save & Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
