import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../models/todo.dart';

class FirestoreService {
  static final FirestoreService instance = FirestoreService._init();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirestoreService._init();

  String? get uid => _auth.currentUser?.uid;

  /// Syncs a todo to Firestore.
  /// Only syncs if it has a reminderTime to save on quota.
  Future<void> syncTodo(Todo todo) async {
    if (uid == null) return;

    final missionRef = _db
        .collection('users')
        .doc(uid)
        .collection('missions')
        .doc(todo.id.toString());

    if (todo.isCompleted || todo.reminderTime == null) {
      // If completed or no reminder, remove from cloud to stop triggers
      await missionRef.delete();
      debugPrint('FIRESTORE: Mission ${todo.id} deleted/omitted from cloud');
    } else {
      await missionRef.set({
        'id': todo.id,
        'title': todo.title,
        'reminderTime': todo.reminderTime!.toIso8601String(),
        'userId': uid,
        'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
        'FIRESTORE: Mission ${todo.id} synced to cloud for ${todo.reminderTime}',
      );
    }
  }

  /// Saves the current device token to Firestore.
  /// Required for the Cloud Function to know where to send the push.
  Future<void> updateDeviceToken() async {
    if (uid == null) return;

    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db.collection('users').doc(uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        debugPrint('FIRESTORE: FCM Token updated');
      }
    } catch (e) {
      debugPrint('FIRESTORE ERROR: Failed to update token: $e');
    }
  }
}
