import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Typing indicator service — shows "typing..." in real-time.
class TypingService {
  final _db = FirebaseFirestore.instance;

  /// Set user typing status in a chat.
  Future<void> setTyping(String chatId, String uid, bool isTyping) async {
    try {
      await _db.collection('chats').doc(chatId).set({
        'typing_$uid': isTyping,
        'typingAt_$uid': isTyping ? FieldValue.serverTimestamp() : null,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Typing error: $e');
    }
  }

  /// Check if peer is typing.
  Stream<bool> isTypingStream(String chatId, String peerUid) {
    return _db.collection('chats').doc(chatId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return false;
      final isTyping = data['typing_$peerUid'] as bool? ?? false;
      if (!isTyping) return false;
      // Expire after 10 seconds
      final ts = (data['typingAt_$peerUid'] as Timestamp?)?.toDate();
      if (ts == null) return false;
      return DateTime.now().difference(ts).inSeconds < 10;
    });
  }
}

/// Read receipts service — track when messages are read.
class ReadReceiptService {
  final _db = FirebaseFirestore.instance;

  /// Mark all messages as read for a user in a chat.
  Future<void> markAllRead(String chatId, String myUid) async {
    try {
      final unread = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: myUid)
          .where('isRead', isEqualTo: false)
          .get();

      if (unread.docs.isEmpty) return;

      final batch = _db.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('ReadReceipt error: $e');
    }
  }
}

/// Online presence service — track last seen.
class PresenceService {
  final _db = FirebaseFirestore.instance;

  Future<void> setOnline(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> setOffline(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Stream<Map<String, dynamic>> presenceStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final data = snap.data() ?? {};
      return {
        'isOnline': data['isOnline'] as bool? ?? false,
        'lastSeen': (data['lastSeen'] as Timestamp?)?.toDate(),
      };
    });
  }
}

/// Message scheduling service.
class ScheduledMessageService {
  final _db = FirebaseFirestore.instance;

  Future<void> scheduleMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    required DateTime scheduledAt,
  }) async {
    await _db.collection('chats').doc(chatId).collection('scheduled_messages').add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'isSent': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> scheduledStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('scheduled_messages')
        .where('isSent', isEqualTo: false)
        .orderBy('scheduledAt')
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }
}

/// Save messages (bookmarks).
class SavedMessagesService {
  final _db = FirebaseFirestore.instance;

  Future<void> saveMessage(String uid, Map<String, dynamic> msg) async {
    await _db.collection('users').doc(uid).collection('saved_messages').add({
      ...msg,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unsaveMessage(String uid, String savedId) async {
    await _db.collection('users').doc(uid).collection('saved_messages').doc(savedId).delete();
  }

  Stream<List<Map<String, dynamic>>> savedStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('saved_messages')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }
}

/// User status / bio service.
class StatusService {
  final _db = FirebaseFirestore.instance;

  Future<void> setStatus(String uid, String status) async {
    await _db.collection('users').doc(uid).update({'status': status});
  }

  Future<String> getStatus(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['status'] as String? ?? '';
  }
}

/// Chat themes per conversation.
class ChatThemeService {
  final _db = FirebaseFirestore.instance;

  Future<void> setTheme(String chatId, String theme) async {
    await _db.collection('chats').doc(chatId).set({
      'theme': theme,
    }, SetOptions(merge: true));
  }

  Stream<String> themeStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots().map((snap) {
      return snap.data()?['theme'] as String? ?? 'default';
    });
  }
}

/// Auto-delete messages (disappearing).
class DisappearingService {
  final _db = FirebaseFirestore.instance;

  Future<void> setDisappearTimer(String chatId, int seconds) async {
    await _db.collection('chats').doc(chatId).set({
      'disappearTimer': seconds,
    }, SetOptions(merge: true));
  }

  Future<int> getDisappearTimer(String chatId) async {
    final doc = await _db.collection('chats').doc(chatId).get();
    return doc.data()?['disappearTimer'] as int? ?? 0;
  }
}

/// Polls service for group chats.
class PollService {
  final _db = FirebaseFirestore.instance;

  Future<void> createPoll({
    required String groupId,
    required String question,
    required List<String> options,
    required String creatorUid,
  }) async {
    await _db.collection('groups').doc(groupId).collection('messages').add({
      'senderId': creatorUid,
      'senderName': 'Опрос',
      'text': question,
      'type': 'poll',
      'pollOptions': options,
      'pollVotes': {},
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    });
  }

  Future<void> vote(String groupId, String messageId, String uid, int optionIndex) async {
    await _db.collection('groups').doc(groupId).collection('messages').doc(messageId).update({
      'pollVotes.$uid': optionIndex,
    });
  }
}

/// Message translation service (simple client-side dictionary, or placeholder for API).
class TranslationService {
  // Simple placeholder — in production you'd use an API.
  static String detectLanguage(String text) {
    final hasRussian = RegExp(r'[а-яА-ЯёЁ]').hasMatch(text);
    final hasEnglish = RegExp(r'[a-zA-Z]').hasMatch(text);
    if (hasRussian && !hasEnglish) return 'ru';
    if (hasEnglish && !hasRussian) return 'en';
    return 'unknown';
  }
}

/// Link preview metadata.
class LinkPreviewService {
  static final _urlRegex = RegExp(
    r'https?://[^\s<]+',
    caseSensitive: false,
  );

  static String? extractUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    return match?.group(0);
  }

  static bool hasLink(String text) => _urlRegex.hasMatch(text);
}
