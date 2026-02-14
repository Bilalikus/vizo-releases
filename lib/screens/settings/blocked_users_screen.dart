import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Manage blocked users — unblock from here.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.read(authServiceProvider).effectiveUid;

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
              title: const Text('Заблокированные',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() as Map<String, dynamic>? ?? {};
          final blocked = List<String>.from(data['blockedUsers'] ?? []);

          if (blocked.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 56,
                      color: AppColors.textHint.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text(
                    'Нет заблокированных',
                    style: TextStyle(
                      color: AppColors.textHint.withValues(alpha: 0.6),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: blocked.length,
            itemBuilder: (_, i) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(blocked[i])
                    .get(),
                builder: (_, userSnap) {
                  final ud =
                      userSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final name = ud['displayName'] as String? ??
                      ud['phoneNumber'] as String? ??
                      blocked[i];
                  final avatar = ud['avatarBase64'] as String? ??
                      ud['avatarUrl'] as String?;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: VCard(
                      child: Row(
                        children: [
                          VAvatar(name: name, imageUrl: avatar, radius: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textPrimary)),
                          ),
                          TextButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .update({
                                'blockedUsers':
                                    FieldValue.arrayRemove([blocked[i]])
                              });
                            },
                            child: const Text('Разблокировать',
                                style: TextStyle(
                                    color: AppColors.accent, fontSize: 13)),
                          ),
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
    );
  }
}
