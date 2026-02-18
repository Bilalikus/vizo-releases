import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../models/group_model.dart';
import '../../models/channel_model.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';
import 'channel_chat_screen.dart';

/// List of groups and communities the user belongs to.
class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                        'Группы',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateGroupScreen(isChannel: true),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: Colors.deepPurple, size: 20),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateGroupScreen(
                              isCommunity: false,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(Icons.group_add_rounded,
                            color: AppColors.accent, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Community Banner ────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateGroupScreen(
                        isCommunity: true,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent.withValues(alpha: 0.15),
                            Colors.blue.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.public_rounded,
                                color: AppColors.accent, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Создать сообщество',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Открытая группа для всех',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              color: AppColors.textHint, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ─── Discover Communities ──────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              child: Text(
                'Сообщества',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHint.withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ─── Public communities ──────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .where('isPublic', isEqualTo: true)
                .limit(30)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Communities error: ${snapshot.error}');
              }
              final docs = snapshot.data?.docs ?? []
                ..sort((a, b) {
                  final aT = (a.data() as Map<String, dynamic>)['updatedAt'] as Timestamp?;
                  final bT = (b.data() as Map<String, dynamic>)['updatedAt'] as Timestamp?;
                  if (aT == null && bT == null) return 0;
                  if (aT == null) return 1;
                  if (bT == null) return -1;
                  return bT.compareTo(aT);
                });
              if (docs.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.md),
                    child: Center(
                      child: Text('Нет сообществ',
                          style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                    ),
                  ),
                );
              }
              return SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final group = GroupModel.fromFirestore(docs[i]);
                      final isMember = group.members.contains(uid);
                      return GestureDetector(
                        onTap: () {
                          if (isMember) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupChatScreen(group: group),
                              ),
                            );
                          } else {
                            _joinCommunity(context, group, uid);
                          }
                        },
                        child: Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isMember
                                  ? AppColors.accent.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.public_rounded,
                                      color: AppColors.accent, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      group.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${group.members.length} участников',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textHint),
                              ),
                              const Spacer(),
                              if (!isMember)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Вступить',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ─── My Groups Label ──────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              child: Text(
                'Мои группы',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHint.withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ─── Groups list ────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .where('members', arrayContains: uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Groups error: ${snapshot.error}');
              }
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

              final docs = snapshot.data?.docs ?? []
                ..sort((a, b) {
                  final aT = (a.data() as Map<String, dynamic>)['updatedAt'] as Timestamp?;
                  final bT = (b.data() as Map<String, dynamic>)['updatedAt'] as Timestamp?;
                  if (aT == null && bT == null) return 0;
                  if (aT == null) return 1;
                  if (bT == null) return -1;
                  return bT.compareTo(aT);
                });

              if (docs.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group_outlined,
                            size: 56,
                            color:
                                AppColors.textHint.withValues(alpha: 0.4)),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          'Нет групп',
                          style: TextStyle(
                            color:
                                AppColors.textHint.withValues(alpha: 0.6),
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Создайте группу или вступите в сообщество',
                          style: TextStyle(
                            color:
                                AppColors.textHint.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSizes.md),
                sliver: SliverList.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final group = GroupModel.fromFirestore(docs[i]);
                    return _GroupTile(group: group, uid: uid);
                  },
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ─── Channels Label ──────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              child: Text(
                'Мои каналы',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHint.withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ─── Channels list ──────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('channels')
                .where('subscribers', arrayContains: uid)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: 8),
                    child: Text('Нет каналов', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                sliver: SliverList.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final channel = ChannelModel.fromFirestore(docs[i]);
                    return _ChannelTile(channel: channel, uid: uid);
                  },
                ),
              );
            },
          ),

          SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  void _joinCommunity(
      BuildContext context, GroupModel group, String uid) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(group.id)
        .update({
      'members': FieldValue.arrayUnion([uid]),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Вы вступили в «${group.name}»')),
      );
    }
  }
}

// ─── Group Tile ──────────────────────────

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.uid});
  final GroupModel group;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.xs),
      child: VCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupChatScreen(group: group),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: group.isCommunity
                    ? Colors.blue.withValues(alpha: 0.15)
                    : AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                group.isCommunity
                    ? Icons.public_rounded
                    : Icons.group_rounded,
                color: group.isCommunity ? Colors.blue : AppColors.accent,
                size: 24,
              ),
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
                          group.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (group.lastMessageAt != null)
                        Text(
                          '${group.lastMessageAt!.hour.toString().padLeft(2, '0')}:${group.lastMessageAt!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                AppColors.textHint.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (group.isCommunity)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.public,
                              size: 12,
                              color: AppColors.textHint
                                  .withValues(alpha: 0.5)),
                        ),
                      Expanded(
                        child: Text(
                          group.lastMessage ??
                              '${group.members.length} участников',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}

// ─── Channel Tile ────────────────────────

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.channel, required this.uid});
  final ChannelModel channel;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.xs),
      child: VCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChannelChatScreen(channel: channel),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.campaign_rounded, color: Colors.deepPurple, size: 24),
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
                          channel.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (channel.lastMessageAt != null)
                        Text(
                          '${channel.lastMessageAt!.hour.toString().padLeft(2, '0')}:${channel.lastMessageAt!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 12, color: AppColors.textHint.withValues(alpha: 0.6)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.campaign, size: 12, color: Colors.deepPurple),
                      ),
                      Expanded(
                        child: Text(
                          channel.lastMessage ?? '${channel.subscribers.length} подписчиков',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.7)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}
