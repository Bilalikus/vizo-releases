import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Role hierarchy: Admin > Moderator > User
enum UserRole { user, moderator, admin }

/// Admin & Moderator service — 58 management capabilities.
///
/// ADMIN can do everything.
/// MODERATOR can ban users (MUST provide reason), ban groups, manage reports,
///   but CANNOT: promote to admin, access system settings, delete accounts,
///   manage moderators, view system logs.
class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Set<String> adminPhones = {'+79939127074', '79939127074', '+7 993-912-70-74'};

  static bool isAdminPhone(String phone) {
    final n = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    return n.contains('9939127074') || n == '79939127074' || n == '89939127074';
  }

  Future<bool> isAdminUid(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final phone = doc.data()?['phoneNumber'] as String? ?? '';
      if (isAdminPhone(phone)) return true;
      return (doc.data()?['role'] as String?) == 'admin';
    } catch (e) { debugPrint('isAdminUid error: $e'); return false; }
  }

  Future<bool> isModeratorUid(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final role = doc.data()?['role'] as String? ?? 'user';
      return role == 'moderator' || role == 'admin' || isAdminPhone(doc.data()?['phoneNumber'] ?? '');
    } catch (_) { return false; }
  }

  Future<UserRole> getUserRole(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return UserRole.user;
      final phone = doc.data()?['phoneNumber'] as String? ?? '';
      if (isAdminPhone(phone)) return UserRole.admin;
      final role = doc.data()?['role'] as String? ?? 'user';
      if (role == 'admin') return UserRole.admin;
      if (role == 'moderator') return UserRole.moderator;
      return UserRole.user;
    } catch (_) { return UserRole.user; }
  }

  // ═══ 1. STATISTICS (10) ═══
  Future<int> getTotalUsers() async => (await _db.collection('users').get()).docs.length;
  Future<int> getOnlineUsers() async => (await _db.collection('users').where('isOnline', isEqualTo: true).get()).docs.length;
  Stream<int> onlineUsersStream() => _db.collection('users').where('isOnline', isEqualTo: true).snapshots().map((s) => s.docs.length);
  Future<int> getTotalChats() async => (await _db.collection('chats').get()).docs.length;
  Future<int> getTotalGroups() async => (await _db.collection('groups').where('isPublic', isEqualTo: false).get()).docs.length;
  Future<int> getTotalCommunities() async => (await _db.collection('groups').where('isPublic', isEqualTo: true).get()).docs.length;
  Future<int> getTotalChannels() async => (await _db.collection('channels').get()).docs.length;
  Future<int> getTotalInstalls() async => (await _db.collection('app_installs').get()).docs.length;
  Future<int> getNewUsersToday() async {
    final y = DateTime.now().subtract(const Duration(hours: 24));
    return (await _db.collection('users').where('createdAt', isGreaterThan: Timestamp.fromDate(y)).get()).docs.length;
  }
  Future<int> getTotalBanned() async => (await _db.collection('banned_users').get()).docs.length;

  // ═══ 2. USER MANAGEMENT (12) ═══
  Future<List<Map<String, dynamic>>> getAllUsers({int limit = 100}) async {
    final snap = await _db.collection('users').orderBy('createdAt', descending: true).limit(limit).get();
    return snap.docs.map((d) { final data = d.data(); data['uid'] = d.id; return data; }).toList();
  }
  Stream<List<Map<String, dynamic>>> allUsersStream() => _db.collection('users').orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map((d) { final data = d.data(); data['uid'] = d.id; return data; }).toList());

  Future<void> banUser(String uid, {required String reason}) async {
    await _db.collection('banned_users').doc(uid).set({'uid': uid, 'reason': reason, 'bannedAt': FieldValue.serverTimestamp()});
    await _db.collection('users').doc(uid).update({'isBanned': true, 'banReason': reason});
    await _logAction('ban_user', 'Banned $uid: $reason');
  }
  Future<void> unbanUser(String uid) async {
    await _db.collection('banned_users').doc(uid).delete();
    await _db.collection('users').doc(uid).update({'isBanned': false, 'banReason': ''});
    await _logAction('unban_user', 'Unbanned $uid');
  }
  Future<bool> isUserBanned(String uid) async => (await _db.collection('banned_users').doc(uid).get()).exists;
  Stream<List<Map<String, dynamic>>> bannedUsersStream() => _db.collection('banned_users').orderBy('bannedAt', descending: true).snapshots().map((s) => s.docs.map((d) { final data = d.data(); data['uid'] = d.id; return data; }).toList());

  Future<void> setUserDisplayName(String uid, String name) async { await _db.collection('users').doc(uid).update({'displayName': name}); await _logAction('set_name', 'Set $uid name=$name'); }
  Future<void> resetUserAvatar(String uid) async { await _db.collection('users').doc(uid).update({'avatarBase64': null, 'avatarUrl': null}); await _logAction('reset_avatar', '$uid'); }
  Future<void> deleteUserAccount(String uid) async {
    final contacts = await _db.collection('users').doc(uid).collection('contacts').get();
    for (final c in contacts.docs) await c.reference.delete();
    await _db.collection('users').doc(uid).delete();
    await _db.collection('banned_users').doc(uid).delete();
    await _logAction('delete_account', '$uid');
  }
  Future<void> forceSignOut(String uid) async { await _db.collection('users').doc(uid).update({'isOnline': false}); await _logAction('force_signout', '$uid'); }
  Future<void> warnUser(String uid, String message) async {
    await _db.collection('users').doc(uid).collection('warnings').add({'message': message, 'createdAt': FieldValue.serverTimestamp()});
    await _db.collection('users').doc(uid).update({'warningCount': FieldValue.increment(1)});
    await _logAction('warn_user', '$uid: $message');
  }
  Future<List<Map<String, dynamic>>> getUserWarnings(String uid) async => (await _db.collection('users').doc(uid).collection('warnings').orderBy('createdAt', descending: true).get()).docs.map((d) => d.data()).toList();

  // ═══ 3. ROLE MANAGEMENT (6) ═══
  Future<void> promoteToModerator(String uid) async { await _db.collection('users').doc(uid).update({'role': 'moderator'}); await _logAction('promote_mod', '$uid'); }
  Future<void> demoteToUser(String uid) async { await _db.collection('users').doc(uid).update({'role': 'user'}); await _logAction('demote', '$uid'); }
  Future<void> promoteToAdmin(String uid) async { await _db.collection('users').doc(uid).update({'role': 'admin'}); await _logAction('promote_admin', '$uid'); }
  Stream<List<Map<String, dynamic>>> moderatorsStream() => _db.collection('users').where('role', isEqualTo: 'moderator').snapshots().map((s) => s.docs.map((d) { final data = d.data(); data['uid'] = d.id; return data; }).toList());
  Stream<List<Map<String, dynamic>>> adminsStream() => _db.collection('users').where('role', isEqualTo: 'admin').snapshots().map((s) => s.docs.map((d) { final data = d.data(); data['uid'] = d.id; return data; }).toList());
  Future<int> getModeratorCount() async => (await _db.collection('users').where('role', isEqualTo: 'moderator').get()).docs.length;

  // ═══ 4. GROUP/COMMUNITY BAN (8) ═══
  Future<void> banGroup(String groupId, {required String reason, bool banAllMembers = false}) async {
    await _db.collection('banned_groups').doc(groupId).set({'groupId': groupId, 'reason': reason, 'bannedAt': FieldValue.serverTimestamp(), 'banAllMembers': banAllMembers});
    await _db.collection('groups').doc(groupId).update({'isBanned': true, 'banReason': reason});
    if (banAllMembers) {
      final g = await _db.collection('groups').doc(groupId).get();
      final members = List<String>.from(g.data()?['members'] ?? []);
      for (final uid in members) {
        final role = await getUserRole(uid);
        if (role != UserRole.admin && role != UserRole.moderator) {
          await banUser(uid, reason: 'Участник забаненной группы: $reason');
        }
      }
    }
    await _logAction('ban_group', '$groupId: $reason (banAll=$banAllMembers)');
  }
  Future<void> unbanGroup(String groupId) async { await _db.collection('banned_groups').doc(groupId).delete(); await _db.collection('groups').doc(groupId).update({'isBanned': false, 'banReason': ''}); await _logAction('unban_group', '$groupId'); }
  Future<bool> isGroupBanned(String groupId) async => (await _db.collection('banned_groups').doc(groupId).get()).exists;
  Stream<List<Map<String, dynamic>>> bannedGroupsStream() => _db.collection('banned_groups').orderBy('bannedAt', descending: true).snapshots().map((s) => s.docs.map((d) { final data = d.data(); data['groupId'] = d.id; return data; }).toList());
  Future<void> deleteGroup(String groupId) async {
    final msgs = await _db.collection('groups').doc(groupId).collection('messages').get();
    final batch = _db.batch(); for (final m in msgs.docs) batch.delete(m.reference); await batch.commit();
    await _db.collection('groups').doc(groupId).delete();
    await _logAction('delete_group', '$groupId');
  }
  Future<void> removeGroupMember(String groupId, String uid) async { await _db.collection('groups').doc(groupId).update({'members': FieldValue.arrayRemove([uid]), 'admins': FieldValue.arrayRemove([uid])}); await _logAction('remove_member', '$uid from $groupId'); }
  Stream<List<Map<String, dynamic>>> allGroupsStream() => _db.collection('groups').snapshots().map((s) => s.docs.map((d) { final data = d.data(); data['id'] = d.id; return data; }).toList());
  Future<void> freezeGroup(String groupId) async { await _db.collection('groups').doc(groupId).update({'isFrozen': true}); await _logAction('freeze', '$groupId'); }

  // ═══ 5. CHANNEL MANAGEMENT (4) ═══
  Future<void> banChannel(String channelId, {required String reason}) async { await _db.collection('channels').doc(channelId).update({'isBanned': true, 'banReason': reason}); await _logAction('ban_channel', '$channelId'); }
  Future<void> unbanChannel(String channelId) async { await _db.collection('channels').doc(channelId).update({'isBanned': false, 'banReason': ''}); }
  Future<void> deleteChannel(String channelId) async {
    final msgs = await _db.collection('channels').doc(channelId).collection('messages').get();
    final batch = _db.batch(); for (final m in msgs.docs) batch.delete(m.reference); await batch.commit();
    await _db.collection('channels').doc(channelId).delete();
    await _logAction('delete_channel', '$channelId');
  }
  Stream<List<Map<String, dynamic>>> allChannelsStream() => _db.collection('channels').snapshots().map((s) => s.docs.map((d) { final data = d.data(); data['id'] = d.id; return data; }).toList());

  // ═══ 6. CONTENT MODERATION (6) ═══
  Future<void> deleteMessage(String chatId, String messageId, {bool isGroup = false}) async {
    final col = isGroup ? 'groups' : 'chats';
    await _db.collection(col).doc(chatId).collection('messages').doc(messageId).update({'isDeleted': true, 'text': '', 'deletedByAdmin': true});
    await _logAction('delete_msg', '$messageId in $col/$chatId');
  }
  Future<void> clearChat(String chatId, {bool isGroup = false}) async {
    final col = isGroup ? 'groups' : 'chats';
    final msgs = await _db.collection(col).doc(chatId).collection('messages').get();
    final batch = _db.batch(); for (final m in msgs.docs) batch.delete(m.reference); await batch.commit();
    await _logAction('clear_chat', '$col/$chatId');
  }
  Future<void> pinAnnouncement(String text) async { await _db.collection('announcements').add({'text': text, 'createdAt': FieldValue.serverTimestamp(), 'isPinned': true}); }
  Future<void> removeAnnouncement(String id) async { await _db.collection('announcements').doc(id).delete(); }
  Stream<List<Map<String, dynamic>>> announcementsStream() => _db.collection('announcements').orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map((d) { final data = d.data(); data['id'] = d.id; return data; }).toList());
  Future<void> sendSystemMessage(String uid, String text) async { await _db.collection('users').doc(uid).collection('system_messages').add({'text': text, 'createdAt': FieldValue.serverTimestamp(), 'isRead': false}); }

  // ═══ 7. REPORTS & AUDIT (6) ═══
  Future<void> submitReport({required String reporterUid, required String targetUid, required String reason, String? messageId, String? groupId}) async {
    await _db.collection('reports').add({'reporterUid': reporterUid, 'targetUid': targetUid, 'reason': reason, 'messageId': messageId, 'groupId': groupId, 'status': 'pending', 'createdAt': FieldValue.serverTimestamp()});
  }
  Stream<List<Map<String, dynamic>>> pendingReportsStream() => _db.collection('reports').where('status', isEqualTo: 'pending').orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map((d) { final data = d.data(); data['id'] = d.id; return data; }).toList());
  Future<void> resolveReport(String reportId, String resolution) async { await _db.collection('reports').doc(reportId).update({'status': 'resolved', 'resolution': resolution, 'resolvedAt': FieldValue.serverTimestamp()}); }
  Future<void> dismissReport(String reportId) async { await _db.collection('reports').doc(reportId).update({'status': 'dismissed'}); }
  Stream<List<Map<String, dynamic>>> auditLogStream({int limit = 50}) => _db.collection('admin_logs').orderBy('timestamp', descending: true).limit(limit).snapshots().map((s) => s.docs.map((d) { final data = d.data(); data['id'] = d.id; return data; }).toList());
  Future<Map<String, int>> getReportStats() async {
    final all = await _db.collection('reports').get();
    int p = 0, r = 0, d = 0;
    for (final doc in all.docs) { final s = doc.data()['status'] ?? 'pending'; if (s == 'pending') p++; else if (s == 'resolved') r++; else d++; }
    return {'pending': p, 'resolved': r, 'dismissed': d};
  }

  // ═══ 8. SYSTEM (6) ═══
  Future<void> recordInstall(String uid, String platform) async { await _db.collection('app_installs').doc(uid).set({'uid': uid, 'platform': platform, 'installedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)); }
  Future<void> setMaintenanceMode(bool on) async { await _db.collection('system').doc('config').set({'maintenance': on, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)); }
  Future<bool> isMaintenanceMode() async => (await _db.collection('system').doc('config').get()).data()?['maintenance'] as bool? ?? false;
  Future<void> setMinVersion(String v) async { await _db.collection('system').doc('config').set({'minVersion': v, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)); }
  Future<void> broadcastMessage(String text) async {
    final users = await _db.collection('users').get();
    final batch = _db.batch();
    for (final u in users.docs) { batch.set(_db.collection('users').doc(u.id).collection('system_messages').doc(), {'text': text, 'createdAt': FieldValue.serverTimestamp(), 'isRead': false, 'isBroadcast': true}); }
    await batch.commit();
    await _logAction('broadcast', text);
  }
  Future<Map<String, dynamic>> getFeatureFlags() async => (await _db.collection('system').doc('features').get()).data() ?? {};

  // ═══ INTERNAL ═══
  Future<void> _logAction(String action, String details) async { try { await _db.collection('admin_logs').add({'action': action, 'details': details, 'timestamp': FieldValue.serverTimestamp()}); } catch (_) {} }
}
