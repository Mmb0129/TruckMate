import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

    return Scaffold(
      body: SafeArea(
        child: Container(
          height: size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primaryContainer.withOpacity(.3),
                cs.surface,
                cs.surface,
              ],
              stops: const [0, .45, 1],
            ),
          ),
          child: Column(
            children: [
              // HERO TOP
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 4, 32, 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary.withOpacity(.12),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withOpacity(.2),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 64,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        "Profile Setup",
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        "Phone: $phone",
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              // FORM CARD + scroll
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      )
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                    child: Column(
                      children: [
                        _input(tt, cs, "Owner Name *", _ownerCtrl),
                        const SizedBox(height: 16),
                        _input(tt, cs, "Company Name *", _companyCtrl),
                        const SizedBox(height: 16),
                        _input(tt, cs, "Email (optional)", _emailCtrl, emailMode: true),
                        const SizedBox(height: 28),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _save,
                            icon: _busy
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(cs.onPrimary),
                                    ),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(
                              _busy ? "Saving…" : "Save & Continue",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(TextTheme tt, ColorScheme cs, String label,
      TextEditingController ctrl,
      {bool emailMode = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: tt.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outline.withOpacity(.3),
            ),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType:
                emailMode ? TextInputType.emailAddress : TextInputType.text,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
