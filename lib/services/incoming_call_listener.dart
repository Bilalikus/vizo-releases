import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../screens/call/incoming_call_screen.dart';

/// Listens for incoming calls in Firestore and shows the IncomingCallScreen.
class IncomingCallListener {
  StreamSubscription? _subscription;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Set<String> _handledCallIds = {};

  /// Start listening for incoming calls directed at [uid].
  void startListening({
    required String uid,
    required GlobalKey<NavigatorState> navigatorKey,
  }) {
    _subscription?.cancel();
    _handledCallIds.clear();

    _subscription = _db
        .collection('calls')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: CallStatus.ringing.name)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final call = CallModel.fromMap(change.doc.id, data);

          // Skip if WE are the caller (prevents self-ring)
          if (call.callerId == uid) continue;

          // Skip if already handled this call
          if (_handledCallIds.contains(call.id)) continue;
          _handledCallIds.add(call.id);

          // Show incoming call screen
          final navigator = navigatorKey.currentState;
          if (navigator != null) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => IncomingCallScreen(call: call),
              ),
            );
          }
        }
      }
    });
  }

  /// Stop listening.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stopListening();
  }
}
