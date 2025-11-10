import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TruckMateApp());
}

class TruckMateApp extends StatelessWidget {
  const TruckMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TruckMate',
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}
