import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

/// Firestore service for user profile and contacts CRUD.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── User Profile ────────────────────────────────────

  /// Get a user document by UID.
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Stream the current user's profile.
  Stream<UserModel?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  /// Update user profile fields.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('users').doc(uid).update(data);
  }

  // ─── Contacts CRUD ───────────────────────────────────

  /// Add a new contact.
  Future<ContactModel> addContact(ContactModel contact) async {
    final ref = _db
        .collection('users')
        .doc(contact.ownerUid)
        .collection('contacts')
        .doc();

    final newContact = contact.copyWith(
      id: ref.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ref.set(newContact.toFirestore());
    return newContact;
  }

  /// Update an existing contact.
  Future<void> updateContact(ContactModel contact) async {
    final data = contact.toFirestore();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db
        .collection('users')
        .doc(contact.ownerUid)
        .collection('contacts')
        .doc(contact.id)
        .update(data);
  }

  /// Delete a contact.
  Future<void> deleteContact(String ownerUid, String contactId) async {
    await _db
        .collection('users')
        .doc(ownerUid)
        .collection('contacts')
        .doc(contactId)
        .delete();
  }

  /// Stream all contacts for a user, ordered by name.
  Stream<List<ContactModel>> contactsStream(String ownerUid) {
    return _db
        .collection('users')
        .doc(ownerUid)
        .collection('contacts')
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContactModel.fromFirestore(doc))
            .toList());
  }

  /// Get a single contact.
  Future<ContactModel?> getContact(String ownerUid, String contactId) async {
    final doc = await _db
        .collection('users')
        .doc(ownerUid)
        .collection('contacts')
        .doc(contactId)
        .get();
    if (!doc.exists) return null;
    return ContactModel.fromFirestore(doc);
  }

  // ─── Calls / Signaling ──────────────────────────────

  /// Create a new call document for WebRTC signaling.
  Future<void> createCall(CallModel call) async {
    await _db.collection('calls').doc(call.id).set(call.toFirestore());
  }

  /// Update call status / data.
  Future<void> updateCall(String callId, Map<String, dynamic> data) async {
    await _db.collection('calls').doc(callId).update(data);
  }

  /// Stream a call document.
  Stream<CallModel?> callStream(String callId) {
    return _db.collection('calls').doc(callId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CallModel.fromMap(doc.id, doc.data()!);
    });
  }

  /// Delete a call document.
  Future<void> deleteCall(String callId) async {
    // Also clean up ICE candidates sub-collections
    final callerCandidates = await _db
        .collection('calls')
        .doc(callId)
        .collection('callerCandidates')
        .get();
    for (final doc in callerCandidates.docs) {
      await doc.reference.delete();
    }

    final receiverCandidates = await _db
        .collection('calls')
        .doc(callId)
        .collection('receiverCandidates')
        .get();
    for (final doc in receiverCandidates.docs) {
      await doc.reference.delete();
    }

    await _db.collection('calls').doc(callId).delete();
  }

  /// Add an ICE candidate for signaling.
  Future<void> addIceCandidate({
    required String callId,
    required String collection, // 'callerCandidates' or 'receiverCandidates'
    required Map<String, dynamic> candidate,
  }) async {
    await _db
        .collection('calls')
        .doc(callId)
        .collection(collection)
        .add(candidate);
  }

  /// Stream ICE candidates.
  Stream<QuerySnapshot> iceCandidatesStream({
    required String callId,
    required String collection,
  }) {
    return _db
        .collection('calls')
        .doc(callId)
        .collection(collection)
        .snapshots();
  }

  /// Delete all user data (for account deletion).
  Future<void> deleteUserData(String uid) async {
    // Delete contacts sub-collection
    final contacts = await _db
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .get();
    final batch = _db.batch();
    for (final doc in contacts.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Delete saved_messages sub-collection
    final saved = await _db
        .collection('users')
        .doc(uid)
        .collection('saved_messages')
        .get();
    final batch2 = _db.batch();
    for (final doc in saved.docs) {
      batch2.delete(doc.reference);
    }
    await batch2.commit();

    // Delete user document
    await _db.collection('users').doc(uid).delete();
  }

  /// Archive/unarchive a chat.
  Future<void> toggleArchiveChat(String chatId, String uid) async {
    final doc = await _db.collection('chats').doc(chatId).get();
    final data = doc.data() ?? {};
    final archived = List<String>.from(data['archivedBy'] ?? []);
    if (archived.contains(uid)) {
      await _db.collection('chats').doc(chatId).update({
        'archivedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      await _db.collection('chats').doc(chatId).set({
        'archivedBy': FieldValue.arrayUnion([uid]),
      }, SetOptions(merge: true));
    }
  }

  /// Find a user by phone number.
  Future<UserModel?> findUserByPhone(String phoneNumber) async {
    final query = await _db
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return UserModel.fromFirestore(query.docs.first);
  }

  // ─── Chat Folders ────────────────────────────────────

  /// Get chat folders for a user.
  Stream<List<Map<String, dynamic>>> chatFoldersStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('chat_folders')
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// Add a chat folder.
  Future<void> addChatFolder(String uid, String name, String icon) async {
    final count = (await _db
            .collection('users')
            .doc(uid)
            .collection('chat_folders')
            .get())
        .docs
        .length;
    await _db
        .collection('users')
        .doc(uid)
        .collection('chat_folders')
        .add({
      'name': name,
      'icon': icon,
      'chatIds': <String>[],
      'order': count,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a chat folder.
  Future<void> deleteChatFolder(String uid, String folderId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('chat_folders')
        .doc(folderId)
        .delete();
  }

  /// Add/remove chat from folder.
  Future<void> toggleChatInFolder(
      String uid, String folderId, String chatId) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('chat_folders')
        .doc(folderId)
        .get();
    final ids = List<String>.from(doc.data()?['chatIds'] ?? []);
    if (ids.contains(chatId)) {
      ids.remove(chatId);
    } else {
      ids.add(chatId);
    }
    await doc.reference.update({'chatIds': ids});
  }

  // ─── Quick Replies ────────────────────────────────────

  /// Stream quick replies.
  Stream<List<Map<String, dynamic>>> quickRepliesStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('quick_replies')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  /// Add quick reply.
  Future<void> addQuickReply(
      String uid, String label, String text) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('quick_replies')
        .add({
      'label': label,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete quick reply.
  Future<void> deleteQuickReply(String uid, String replyId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('quick_replies')
        .doc(replyId)
        .delete();
  }

  // ─── Pin message ──────────────────────────────────────

  /// Toggle pin on a message.
  Future<void> togglePinMessage(
      String chatId, String messageId, bool currentlyPinned) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'isPinned': !currentlyPinned});
  }

  // ─── Bulk delete messages ─────────────────────────────

  /// Delete multiple messages at once.
  Future<void> bulkDeleteMessages(
      String chatId, List<String> messageIds) async {
    final batch = _db.batch();
    for (final id in messageIds) {
      batch.update(
        _db
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(id),
        {'isDeleted': true, 'text': ''},
      );
    }
    await batch.commit();
  }
}
