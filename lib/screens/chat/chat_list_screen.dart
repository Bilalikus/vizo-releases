import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'chat_screen.dart';

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

    return Scaffold(
      backgroundColor: AppColors.black,
      body: CustomScrollView(
        slivers: [
          // ─── Header ─────────────────────────
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.sm),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Чаты',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _onlyUnread = !_onlyUnread),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _onlyUnread
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _onlyUnread
                                ? AppColors.accent.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _onlyUnread
                                  ? Icons.mark_email_unread_rounded
                                  : Icons.email_outlined,
                              size: 16,
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

          // ─── Chat list ──────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: uid)
                .orderBy('lastMessageAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 56,
                            color: AppColors.textHint.withValues(alpha: 0.4)),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          'Нет чатов',
                          style: TextStyle(
                            color: AppColors.textHint.withValues(alpha: 0.6),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                sliver: SliverList.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final participants =
                        List<String>.from(data['participants'] as List? ?? []);
                    final peerId =
                        participants.firstWhere((p) => p != uid, orElse: () => '');
                    final lastMsg = data['lastMessage'] as String? ?? '';
                    final lastAt = (data['lastMessageAt'] as Timestamp?)?.toDate();

                    return _ChatTile(
                      chatId: docs[i].id,
                      peerId: peerId,
                      lastMessage: lastMsg,
                      lastTime: lastAt,
                      currentUid: uid,
                      onlyUnread: _onlyUnread,
                    );
                  },
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSizes.xxl)),
        ],
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

        // Count unread messages
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

            // Filter: only unread
            if (onlyUnread && unreadCount == 0) {
              return const SizedBox.shrink();
            }

            return Dismissible(
              key: ValueKey(chatId),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                margin: const EdgeInsets.only(bottom: AppSizes.xs),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.archive_outlined,
                    color: AppColors.error, size: 24),
              ),
              confirmDismiss: (_) async {
                // Toggle mute as swipe action
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
                      const SnackBar(content: Text('Чат на беззвучном')),
                    );
                  }
                }
                return false;
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.xs),
                child: VCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        peerId: peerId,
                        peerName: peerName,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    VAvatar(
                      imageUrl: peerAvatar,
                      name: peerName,
                      radius: 24,
                    ),
                    const SizedBox(width: AppSizes.md),
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
                          const SizedBox(height: 4),
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
              ), // VCard
            ), // Padding
            ); // Dismissible
          },
        );
      },
    );
  }
}
