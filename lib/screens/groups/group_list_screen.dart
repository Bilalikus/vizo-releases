import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../models/group_model.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';

/// List of groups the user belongs to.
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
                          'Создайте группу нажав +',
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

          SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
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
