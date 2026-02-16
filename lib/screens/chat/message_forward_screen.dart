import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Forward message to another chat or group.
class MessageForwardScreen extends ConsumerStatefulWidget {
  const MessageForwardScreen({
    super.key,
    required this.messageText,
    required this.senderName,
  });

  final String messageText;
  final String senderName;

  @override
  ConsumerState<MessageForwardScreen> createState() =>
      _MessageForwardScreenState();
}

class _MessageForwardScreenState extends ConsumerState<MessageForwardScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _sending = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _forwardToChat(String peerId, String peerName) async {
    if (_sending) return;
    setState(() => _sending = true);

    try {
      final uid = ref.read(authServiceProvider).effectiveUid;
      final user = ref.read(currentUserProvider);
      final sorted = [uid, peerId]..sort();
      final chatId = '${sorted[0]}_${sorted[1]}';
      final db = FirebaseFirestore.instance;

      await db.collection('chats').doc(chatId).collection('messages').add({
        'senderId': uid,
        'senderName': user.displayName,
        'text': '↪ Пересланное от ${widget.senderName}:\n${widget.messageText}',
        'type': 'text',
        'isRead': false,
        'isDeleted': false,
        'reactions': {},
        'createdAt': FieldValue.serverTimestamp(),
      });

      await db.collection('chats').doc(chatId).set({
        'participants': [uid, peerId],
        'lastMessage':
            '↪ ${widget.messageText.length > 30 ? '${widget.messageText.substring(0, 30)}...' : widget.messageText}',
        'lastMessageAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Переслано → $peerName')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _forwardToGroup(String groupId, String groupName) async {
    if (_sending) return;
    setState(() => _sending = true);

    try {
      final uid = ref.read(authServiceProvider).effectiveUid;
      final user = ref.read(currentUserProvider);
      final db = FirebaseFirestore.instance;

      await db.collection('groups').doc(groupId).collection('messages').add({
        'senderId': uid,
        'senderName': user.displayName,
        'text': '↪ Пересланное от ${widget.senderName}:\n${widget.messageText}',
        'type': 'text',
        'isDeleted': false,
        'reactions': {},
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Переслано → $groupName')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.read(authServiceProvider).effectiveUid;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              size: 22, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Переслать',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(12),
            child: VTextField(
              controller: _searchCtrl,
              hint: 'Поиск...',
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 20, color: AppColors.textHint),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),

          // Preview of forwarded message
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.forward_rounded,
                    size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.messageText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Chats section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Личные чаты',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent.withValues(alpha: 0.7))),
            ),
          ),
          const SizedBox(height: 4),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: uid)
                  .orderBy('lastMessageAt', descending: true)
                  .snapshots(),
              builder: (_, snap) {
                final chatDocs = snap.data?.docs ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: chatDocs.length,
                  itemBuilder: (_, i) {
                    final data =
                        chatDocs[i].data() as Map<String, dynamic>;
                    final participants = List<String>.from(
                        data['participants'] as List? ?? []);
                    final peerId = participants.firstWhere(
                        (p) => p != uid,
                        orElse: () => '');

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(peerId)
                          .get(),
                      builder: (_, userSnap) {
                        final userData = userSnap.data?.data()
                            as Map<String, dynamic>?;
                        final peerName =
                            userData?['displayName'] as String? ??
                                userData?['phoneNumber'] as String? ??
                                peerId;

                        if (_query.isNotEmpty &&
                            !peerName.toLowerCase().contains(_query)) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: VCard(
                            enableDragStretch: false,
                            onTap: () =>
                                _forwardToChat(peerId, peerName),
                            child: Row(
                              children: [
                                VAvatar(
                                  name: peerName,
                                  imageUrl: userData?['avatarBase64']
                                      as String?,
                                  radius: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(peerName,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          color:
                                              AppColors.textPrimary)),
                                ),
                                if (_sending)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.accent),
                                  )
                                else
                                  const Icon(
                                      Icons.send_rounded,
                                      size: 18,
                                      color: AppColors.textHint),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
