import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Admin service — manages admin privileges, bans, stats.
/// Admin phone: +7 993-912-70-74 (normalized: +79939127074)
class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// The admin phone numbers (normalized).
  static const Set<String> adminPhones = {
    '+79939127074',
    '79939127074',
    '+7 993-912-70-74',
  };

  /// Check if a phone number belongs to an admin.
  static bool isAdminPhone(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return adminPhones.contains(normalized) ||
        adminPhones.contains('+$normalized') ||
        normalized.contains('9939127074');
  }

  /// Check if a UID belongs to an admin user.
  Future<bool> isAdminUid(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final phone = doc.data()?['phoneNumber'] as String? ?? '';
      return isAdminPhone(phone);
    } catch (e) {
      debugPrint('isAdminUid error: $e');
      return false;
    }
  }

  // ─── Stats ─────────────────────────────────────

  /// Get total registered users count.
  Future<int> getTotalUsers() async {
    final snap = await _db.collection('users').count().get();
    return snap.count ?? 0;
  }

  /// Get online users count.
  Future<int> getOnlineUsers() async {
    final snap = await _db
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// Stream online users count (real-time).
  Stream<int> onlineUsersStream() {
    return _db
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Get total chats count.
  Future<int> getTotalChats() async {
    final snap = await _db.collection('chats').count().get();
    return snap.count ?? 0;
  }

  /// Get total groups count.
  Future<int> getTotalGroups() async {
    final snap = await _db.collection('groups').count().get();
    return snap.count ?? 0;
  }

  /// Get total messages count (approximate — counts chat docs).
  Future<int> getTotalMessages() async {
    // collectionGroup would require index, so approximate from chats
    final chats = await _db.collection('chats').get();
    int total = 0;
    for (final chat in chats.docs) {
      final count = await chat.reference
          .collection('messages')
          .count()
          .get();
      total += count.count ?? 0;
    }
    return total;
  }

  // ─── User Management ──────────────────────────

  /// Get all users (paginated).
  Future<List<Map<String, dynamic>>> getAllUsers({int limit = 50}) async {
    final snap = await _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      data['uid'] = d.id;
      return data;
    }).toList();
  }

  /// Stream all users.
  Stream<List<Map<String, dynamic>>> allUsersStream() {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['uid'] = d.id;
              return data;
            }).toList());
  }

  /// Ban a user (add to global banned list + update user doc).
  Future<void> banUser(String uid, {String reason = ''}) async {
    await _db.collection('banned_users').doc(uid).set({
      'uid': uid,
      'reason': reason,
      'bannedAt': FieldValue.serverTimestamp(),
    });
    // Also mark in user doc
    await _db.collection('users').doc(uid).update({
      'isBanned': true,
      'banReason': reason,
    });
  }

  /// Unban a user.
  Future<void> unbanUser(String uid) async {
    await _db.collection('banned_users').doc(uid).delete();
    await _db.collection('users').doc(uid).update({
      'isBanned': false,
      'banReason': '',
    });
  }

  /// Check if user is banned.
  Future<bool> isUserBanned(String uid) async {
    final doc = await _db.collection('banned_users').doc(uid).get();
    return doc.exists;
  }

  /// Stream banned users.
  Stream<List<Map<String, dynamic>>> bannedUsersStream() {
    return _db
        .collection('banned_users')
        .orderBy('bannedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['uid'] = d.id;
              return data;
            }).toList());
  }

  /// Record app download/install event.
  Future<void> recordInstall(String uid, String platform) async {
    await _db.collection('app_installs').doc(uid).set({
      'uid': uid,
      'platform': platform,
      'installedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get total installs count.
  Future<int> getTotalInstalls() async {
    final snap = await _db.collection('app_installs').count().get();
    return snap.count ?? 0;
  }

  /// Get new users in last 24h.
  Future<int> getNewUsersToday() async {
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    final snap = await _db
        .collection('users')
        .where('createdAt',
            isGreaterThan: Timestamp.fromDate(yesterday))
        .count()
        .get();
    return snap.count ?? 0;
  }
}
