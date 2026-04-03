import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'chat_screen.dart';
import 'archived_chats_screen.dart';
import 'user_search_screen.dart';

/// Telegram-style chat list with glass-morphism — main home screen.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _searchOpen = false;

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

            final filtered = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final archived = List<String>.from(data['archivedBy'] ?? []);
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
                // ── Header: "Чаты" + icons ──
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Чаты',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const Spacer(),
                          _GlassIconBtn(
                            icon: Icons.search_rounded,
                            onTap: () => setState(
                                () => _searchOpen = !_searchOpen),
                          ),
                          const SizedBox(width: 8),
                          _GlassIconBtn(
                            icon: Icons.person_add_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const UserSearchScreen()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _GlassIconBtn(
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

                // ── Search bar (glass, collapsible) ──
                if (_searchOpen)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              onChanged: (v) =>
                                  setState(() => _query = v),
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Поиск чатов...',
                                hintStyle: TextStyle(
                                    color: AppColors.textHint
                                        .withValues(alpha: 0.5),
                                    fontSize: 15),
                                prefixIcon: Icon(Icons.search_rounded,
                                    size: 20,
                                    color: AppColors.textHint
                                        .withValues(alpha: 0.5)),
                                suffixIcon: _query.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          _searchCtrl.clear();
                                          setState(() => _query = '');
                                        },
                                        child: Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: AppColors.textHint
                                                .withValues(alpha: 0.5)),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Loading ──
                if (isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2),
                    ),
                  ),

                // ── Empty ──
                if (!isLoading && filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 56,
                              color: AppColors.textHint
                                  .withValues(alpha: 0.25)),
                          const SizedBox(height: 14),
                          Text(
                            _query.isNotEmpty
                                ? 'Ничего не найдено'
                                : 'Нет чатов',
                            style: TextStyle(
                              color: AppColors.textHint
                                  .withValues(alpha: 0.5),
                              fontSize: 16,
                            ),
                          ),
                          if (_query.isEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Нажмите + чтобы начать',
                              style: TextStyle(
                                color: AppColors.textHint
                                    .withValues(alpha: 0.3),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // ── Chat list ──
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

                      return _GlassChatTile(
                        chatId: filtered[i].id,
                        peerId: peerId,
                        lastMessage: lastMsg,
                        lastTime: lastAt,
                        currentUid: uid,
                      );
                    },
                  ),

                // Fill remaining with black
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(color: AppColors.black),
                ),
                SliverToBoxAdapter(
                    child: SizedBox(height: bottomPad + 72)),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ━━━ Glass Icon Button ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _GlassIconBtn extends StatelessWidget {
  const _GlassIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Icon(icon, size: 18, color: AppColors.textHint),
          ),
        ),
      ),
    );
  }
}

// ━━━ Glass Chat Tile (Telegram-style) ━━━━━━━━━━━━━━━━━━━

class _GlassChatTile extends StatelessWidget {
  const _GlassChatTile({
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

  String _fmt(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inDays == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Вчера';
    } else if (diff.inDays < 7) {
      const d = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      return d[t.weekday - 1];
    }
    return '${t.day}.${t.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(peerId)
          .get(),
      builder: (context, snap) {
        final pd = snap.data?.data() as Map<String, dynamic>?;
        final name = pd?['displayName'] as String? ??
            pd?['phoneNumber'] as String? ??
            peerId;
        final avatar = pd?['avatarBase64'] as String?;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .where('senderId', isNotEqualTo: currentUid)
              .where('isRead', isEqualTo: false)
              .snapshots(),
          builder: (context, unreadSnap) {
            final uc = unreadSnap.data?.docs.length ?? 0;

            return Dismissible(
              key: ValueKey(chatId),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 28),
                color: AppColors.error.withValues(alpha: 0.12),
                child: const Icon(Icons.archive_rounded,
                    color: AppColors.error, size: 22),
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
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      peerId: peerId,
                      peerName: name,
                      peerAvatarUrl: avatar,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          // ── Avatar 52px + online dot ──
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: Stack(
                              children: [
                                VAvatar(
                                  imageUrl: avatar,
                                  name: name,
                                  radius: 26,
                                ),
                                Positioned(
                                  bottom: 1,
                                  right: 1,
                                  child:
                                      StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(peerId)
                                        .snapshots(),
                                    builder: (_, ps) {
                                      final d = ps.data?.data()
                                          as Map<String, dynamic>?;
                                      final on =
                                          d?['isOnline'] as bool? ??
                                              false;
                                      if (!on) {
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
                          ),
                          const SizedBox(width: 12),

                          // ── Name + Message ──
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                // Row 1: name, mute, time
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: uc > 0
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Mute
                                    StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('chats')
                                          .doc(chatId)
                                          .snapshots(),
                                      builder: (_, cs) {
                                        final cd = cs.data?.data()
                                            as Map<String, dynamic>?;
                                        final m = List<String>.from(
                                            cd?['mutedBy'] ?? []);
                                        if (!m.contains(currentUid)) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(
                                                  right: 4),
                                          child: Icon(
                                              Icons.volume_off_rounded,
                                              size: 14,
                                              color: AppColors.textHint
                                                  .withValues(
                                                      alpha: 0.45)),
                                        );
                                      },
                                    ),
                                    Text(
                                      _fmt(lastTime),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: uc > 0
                                            ? AppColors.accent
                                            : AppColors.textHint
                                                .withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                // Row 2: message + badge
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        lastMessage,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: uc > 0
                                              ? AppColors.textSecondary
                                                  .withValues(alpha: 0.85)
                                              : AppColors.textHint
                                                  .withValues(alpha: 0.55),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (uc > 0)
                                      Container(
                                        margin: const EdgeInsets.only(
                                            left: 8),
                                        constraints: const BoxConstraints(
                                            minWidth: 22),
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 6,
                                            vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent,
                                          borderRadius:
                                              BorderRadius.circular(11),
                                        ),
                                        child: Text(
                                          '$uc',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
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
                    // Telegram-style divider (starts after avatar)
                    Padding(
                      padding: const EdgeInsets.only(left: 84),
                      child: Container(
                        height: 0.5,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
