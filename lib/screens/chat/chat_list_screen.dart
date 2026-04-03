import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'chat_screen.dart';
import 'archived_chats_screen.dart';
import '../stories/stories_screen.dart';

/// Chat list — shows all conversations for the current user.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  bool _onlyUnread = false;

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

            // Filter archived chats out
            final filtered = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final archived = List<String>.from(data['archivedBy'] ?? []);
              return !archived.contains(uid);
            }).toList();

            return CustomScrollView(
              slivers: [
              // ─── Top bar ─────────────────────
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        _TopBarBtn(
                          icon: Icons.auto_awesome_rounded,
                          color: AppColors.accent,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const StoriesScreen()),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _TopBarBtn(
                          icon: Icons.archive_outlined,
                          color: AppColors.textHint,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ArchivedChatsScreen()),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _onlyUnread = !_onlyUnread),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _onlyUnread
                                  ? AppColors.accent
                                      .withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _onlyUnread
                                    ? AppColors.accent
                                        .withValues(alpha: 0.3)
                                    : Colors.white
                                        .withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _onlyUnread
                                      ? Icons.mark_email_unread_rounded
                                      : Icons.filter_list_rounded,
                                  size: 14,
                                  color: _onlyUnread
                                      ? AppColors.accent
                                      : AppColors.textHint,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _onlyUnread ? 'Непрочит.' : 'Все',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _onlyUnread
                                        ? AppColors.accent
                                        : AppColors.textHint,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Loading ──────────────────────
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

              // ─── Empty state ──────────────────
              if (!isLoading && filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: AppColors.textHint
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'Нет чатов',
                          style: TextStyle(
                            color: AppColors.textHint
                                .withValues(alpha: 0.6),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ─── Chat list ──────────────────
              if (!isLoading && filtered.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final data = filtered[i].data()
                          as Map<String, dynamic>;
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

                      return _ChatTile(
                        chatId: filtered[i].id,
                        peerId: peerId,
                        lastMessage: lastMsg,
                        lastTime: lastAt,
                        currentUid: uid,
                        onlyUnread: _onlyUnread,
                      );
                    },
                  ),
                ),

              // Fill remaining space with black so no grey shows
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(color: AppColors.black),
              ),

              // Bottom padding for floating nav bar
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

// ─── Top Bar Button ──────────────────────────────────────

class _TopBarBtn extends StatelessWidget {
  const _TopBarBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─── Chat Tile ───────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chatId,
    required this.peerId,
    required this.lastMessage,
    required this.currentUid,
    this.lastTime,
    this.onlyUnread = false,
  });

  final String chatId;
  final String peerId;
  final String lastMessage;
  final DateTime? lastTime;
  final String currentUid;
  final bool onlyUnread;

  @override
  Widget build(BuildContext context) {
    final timeStr = lastTime != null
        ? '${lastTime!.hour.toString().padLeft(2, '0')}:${lastTime!.minute.toString().padLeft(2, '0')}'
        : '';

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('users').doc(peerId).get(),
      builder: (context, snapshot) {
        final peerData = snapshot.data?.data() as Map<String, dynamic>?;
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

            if (onlyUnread && unreadCount == 0) {
              return const SizedBox.shrink();
            }

            return Dismissible(
              key: ValueKey(chatId),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.volume_off_rounded,
                    color: AppColors.error, size: 24),
              ),
              confirmDismiss: (_) async {
                final ref = FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId);
                final doc = await ref.get();
                final data = doc.data() ?? {};
                final mutedBy =
                    List<String>.from(data['mutedBy'] ?? []);
                if (mutedBy.contains(currentUid)) {
                  await ref.update({
                    'mutedBy': FieldValue.arrayRemove([currentUid])
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Звук включён')),
                    );
                  }
                } else {
                  await ref.set({
                    'mutedBy': FieldValue.arrayUnion([currentUid])
                  }, SetOptions(merge: true));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Чат на беззвучном')),
                    );
                  }
                }
                return false;
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: VCard(
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
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          VAvatar(
                            imageUrl: peerAvatar,
                            name: peerName,
                            radius: 24,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(peerId)
                                  .snapshots(),
                              builder: (_, presenceSnap) {
                                final pData = presenceSnap.data?.data()
                                    as Map<String, dynamic>?;
                                final isOnline =
                                    pData?['isOnline'] as bool? ??
                                        false;
                                if (!isOnline) {
                                  return const SizedBox.shrink();
                                }
                                return Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.black,
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    peerName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('chats')
                                      .doc(chatId)
                                      .snapshots(),
                                  builder: (_, chatSnap) {
                                    final chatData =
                                        chatSnap.data?.data()
                                            as Map<String, dynamic>?;
                                    final muted = List<String>.from(
                                        chatData?['mutedBy'] ?? []);
                                    if (muted.contains(currentUid)) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 4),
                                        child: Icon(
                                            Icons.volume_off_rounded,
                                            size: 14,
                                            color: AppColors.textHint
                                                .withValues(alpha: 0.5)),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    lastMessage,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.7),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: const BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
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
            );
          },
        );
      },
    );
  }
}
