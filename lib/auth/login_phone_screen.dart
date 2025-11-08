import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'verify_otp_screen.dart';

class LoginPhoneScreen extends StatefulWidget {
  const LoginPhoneScreen({super.key});

  @override
  State<LoginPhoneScreen> createState() => _LoginPhoneScreenState();
}

class _LoginPhoneScreenState extends State<LoginPhoneScreen> {
  final _phoneCtrl = TextEditingController();
  bool _busy = false;

  String? _validatePhone(String v) {
    final n = v.replaceAll(RegExp(r'\D'), '');
    if (n.length != 10) return 'Enter 10-digit mobile number';
    return null;
  }

  Future<void> _sendOtp() async {
    final err = _validatePhone(_phoneCtrl.text);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final number = '+91${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}';

    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: number,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential cred) async {
          // Android auto-retrieval / instant verification path:
          try {
            await FirebaseAuth.instance.signInWithCredential(cred);
          } catch (_) {}
        },
        verificationFailed: (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'Verification failed')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VerifyOtpScreen(
                verificationId: verificationId,
                phoneE164: number,
                resendToken: resendToken,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Enter your mobile number (India)',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                prefixText: '+91 ',
                border: OutlineInputBorder(),
                labelText: '10-digit number',
              ),
              maxLength: 10,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _sendOtp,
                icon: const Icon(Icons.sms),
                label: _busy
                    ? const Text('Sending…')
                    : const Text('Send OTP'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Standard SMS charges may apply.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
