import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../models/message_model.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'chat_screen.dart';

/// Global search — search messages across ALL chats.
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() =>
      _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _ctrl = TextEditingController();
  List<_SearchResult> _results = [];
  bool _searching = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _lastQuery = '';
      });
      return;
    }
    if (query == _lastQuery) return;
    _lastQuery = query;

    setState(() => _searching = true);

    final uid = ref.read(authServiceProvider).effectiveUid;
    final db = FirebaseFirestore.instance;

    // Get all chats the user participates in
    final chats = await db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();

    final results = <_SearchResult>[];
    final q = query.toLowerCase();

    for (final chat in chats.docs) {
      final participants =
          List<String>.from(chat.data()['participants'] as List? ?? []);
      final peerId = participants.firstWhere((p) => p != uid, orElse: () => '');

      // Get peer name
      String peerName = peerId;
      try {
        final peerDoc = await db.collection('users').doc(peerId).get();
        if (peerDoc.exists) {
          final pd = peerDoc.data() ?? {};
          peerName = pd['displayName'] as String? ??
              pd['phoneNumber'] as String? ??
              peerId;
        }
      } catch (_) {}

      // Search messages in this chat
      final msgs = await db
          .collection('chats')
          .doc(chat.id)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();

      for (final msgDoc in msgs.docs) {
        final m = MessageModel.fromFirestore(msgDoc);
        if (!m.isDeleted && m.text.toLowerCase().contains(q)) {
          results.add(_SearchResult(
            msg: m,
            chatId: chat.id,
            peerId: peerId,
            peerName: peerName,
          ));
        }
      }
    }

    if (mounted && query == _lastQuery) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: AppBar(
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    size: 20, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Поиск по всем чатам...',
                  hintStyle: TextStyle(
                      color: AppColors.textHint.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                ),
                onChanged: _search,
              ),
            ),
          ),
        ),
      ),
      body: _searching
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
          : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 56,
                          color: AppColors.textHint.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        _ctrl.text.isEmpty
                            ? 'Поиск сообщений во всех чатах'
                            : 'Ничего не найдено',
                        style: TextStyle(
                          color: AppColors.textHint.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    final t =
                        '${r.msg.createdAt.day}.${r.msg.createdAt.month.toString().padLeft(2, '0')} ${r.msg.createdAt.hour.toString().padLeft(2, '0')}:${r.msg.createdAt.minute.toString().padLeft(2, '0')}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: VCard(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                peerId: r.peerId,
                                peerName: r.peerName,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.chat_rounded,
                                    size: 14,
                                    color: AppColors.accent
                                        .withValues(alpha: 0.7)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(r.peerName,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accentLight)),
                                ),
                                Text(t,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textHint
                                            .withValues(alpha: 0.5))),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(r.msg.senderName,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.6))),
                            const SizedBox(height: 4),
                            Text(r.msg.text,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _SearchResult {
  final MessageModel msg;
  final String chatId;
  final String peerId;
  final String peerName;

  _SearchResult({
    required this.msg,
    required this.chatId,
    required this.peerId,
    required this.peerName,
  });
}
