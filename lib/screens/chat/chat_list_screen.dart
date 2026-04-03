import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'chat_screen.dart';
import 'archived_chats_screen.dart';
import 'user_search_screen.dart';

/// Telegram-style chat list — the main home screen.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.read(authServiceProvider).effectiveUid;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Container(
        color: AppColors.black,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: uid)
              .orderBy('lastMessageAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            final docs = snapshot.data?.docs ?? [];

            // Filter archived + search
            final filtered = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final archived =
                  List<String>.from(data['archivedBy'] ?? []);
              if (archived.contains(uid)) return false;
              if (_query.isNotEmpty) {
                final lastMsg =
                    (data['lastMessage'] as String? ?? '').toLowerCase();
                return lastMsg.contains(_query.toLowerCase());
              }
              return true;
            }).toList();

            return CustomScrollView(
              slivers: [
                // ─── Top bar ───────────────────
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          const Text(
                            'Vizo',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          _HeaderBtn(
                            icon: Icons.search_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const UserSearchScreen()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _HeaderBtn(
                            icon: Icons.archive_outlined,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ArchivedChatsScreen()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── Search bar ────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Поиск...',
                          hintStyle: TextStyle(
                              color: AppColors.textHint.withValues(alpha: 0.6),
                              fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 18,
                              color:
                                  AppColors.textHint.withValues(alpha: 0.5)),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 8),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                ),

                // ─── Loading ───────────────────
                if (isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2,
                      ),
                    ),
                  ),

                // ─── Empty state ───────────────
                if (!isLoading && filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 56,
                              color:
                                  AppColors.textHint.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            _query.isNotEmpty
                                ? 'Ничего не найдено'
                                : 'Нет чатов',
                            style: TextStyle(
                              color:
                                  AppColors.textHint.withValues(alpha: 0.5),
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ─── Chat list (Telegram-style) ─
                if (!isLoading && filtered.isNotEmpty)
                  SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final data =
                          filtered[i].data() as Map<String, dynamic>;
                      final participants = List<String>.from(
                          data['participants'] as List? ?? []);
                      final peerId = participants.firstWhere(
                          (p) => p != uid,
                          orElse: () => '');
                      final lastMsg =
                          data['lastMessage'] as String? ?? '';
                      final lastAt =
                          (data['lastMessageAt'] as Timestamp?)
                              ?.toDate();

                      return _TelegramChatTile(
                        chatId: filtered[i].id,
                        peerId: peerId,
                        lastMessage: lastMsg,
                        lastTime: lastAt,
                        currentUid: uid,
                      );
                    },
                  ),

                // Fill remaining
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(color: AppColors.black),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(height: bottomPad + 72),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Header Button ───────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.textHint),
      ),
    );
  }
}

// ─── Telegram-style Chat Tile ────────────────────────────

class _TelegramChatTile extends StatelessWidget {
  const _TelegramChatTile({
    required this.chatId,
    required this.peerId,
    required this.lastMessage,
    required this.currentUid,
    this.lastTime,
  });

  final String chatId;
  final String peerId;
  final String lastMessage;
  final DateTime? lastTime;
  final String currentUid;

  String _formatTime(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inDays == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Вчера';
    } else if (diff.inDays < 7) {
      const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      return days[t.weekday - 1];
    } else {
      return '${t.day}.${t.month.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(peerId).get(),
      builder: (context, snapshot) {
        final peerData =
            snapshot.data?.data() as Map<String, dynamic>?;
        final peerName = peerData?['displayName'] as String? ??
            peerData?['phoneNumber'] as String? ??
            peerId;
        final peerAvatar = peerData?['avatarBase64'] as String?;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .where('senderId', isNotEqualTo: currentUid)
              .where('isRead', isEqualTo: false)
              .snapshots(),
          builder: (context, unreadSnap) {
            final unreadCount = unreadSnap.data?.docs.length ?? 0;

            return Dismissible(
              key: ValueKey(chatId),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                color: AppColors.error.withValues(alpha: 0.15),
                child: const Icon(Icons.archive_rounded,
                    color: AppColors.error, size: 24),
              ),
              confirmDismiss: (_) async {
                await FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .set({
                  'archivedBy': FieldValue.arrayUnion([currentUid])
                }, SetOptions(merge: true));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Чат в архиве')),
                  );
                }
                return false;
              },
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            peerId: peerId,
                            peerName: peerName,
                            peerAvatarUrl: peerAvatar,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          // Avatar + online dot
                          Stack(
                            children: [
                              VAvatar(
                                imageUrl: peerAvatar,
                                name: peerName,
                                radius: 26,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(peerId)
                                      .snapshots(),
                                  builder: (_, presSnap) {
                                    final pData = presSnap.data?.data()
                                        as Map<String, dynamic>?;
                                    final online =
                                        pData?['isOnline'] as bool? ??
                                            false;
                                    if (!online) {
                                      return const SizedBox.shrink();
                                    }
                                    return Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppColors.black,
                                            width: 2.5),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Name + message
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        peerName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: unreadCount > 0
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Mute icon
                                    StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('chats')
                                          .doc(chatId)
                                          .snapshots(),
                                      builder: (_, chatSnap) {
                                        final cd =
                                            chatSnap.data?.data()
                                                as Map<String,
                                                    dynamic>?;
                                        final muted =
                                            List<String>.from(
                                                cd?['mutedBy'] ?? []);
                                        if (muted
                                            .contains(currentUid)) {
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(
                                                    right: 4),
                                            child: Icon(
                                              Icons
                                                  .volume_off_rounded,
                                              size: 14,
                                              color: AppColors.textHint
                                                  .withValues(
                                                      alpha: 0.5),
                                            ),
                                          );
                                        }
                                        return const SizedBox
                                            .shrink();
                                      },
                                    ),
                                    Text(
                                      _formatTime(lastTime),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: unreadCount > 0
                                            ? AppColors.accent
                                            : AppColors.textHint
                                                .withValues(
                                                    alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lastMessage,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: unreadCount > 0
                                              ? AppColors
                                                  .textSecondary
                                              : AppColors
                                                  .textSecondary
                                                  .withValues(
                                                      alpha: 0.6),
                                        ),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (unreadCount > 0)
                                      Container(
                                        margin:
                                            const EdgeInsets.only(
                                                left: 8),
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 7,
                                            vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent,
                                          borderRadius:
                                              BorderRadius.circular(
                                                  12),
                                        ),
                                        child: Text(
                                          '$unreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight:
                                                FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Telegram-style divider
                  Padding(
                    padding: const EdgeInsets.only(left: 72),
                    child: Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: AppColors.divider,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
