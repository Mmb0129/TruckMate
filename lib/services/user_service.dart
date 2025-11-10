import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<void> uploadAvatar(String uid, File file) async {
    final ref = _storage.ref().child('avatars/$uid.jpg');

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await _db.collection('users').doc(uid).update({
      'avatarUrl': url,
    });
  }

  Future<void> removeAvatar(String uid) async {
    await _db.collection('users').doc(uid).update({
      'avatarUrl': null,
    });
  }
}
