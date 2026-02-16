import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'chat_screen.dart';

/// Archived chats — chats the user has archived.
class ArchivedChatsScreen extends ConsumerWidget {
  const ArchivedChatsScreen({super.key});

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
              title: const Text('Архив',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: uid)
            .where('archivedBy', arrayContains: uid)
            .snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.archive_outlined,
                      size: 56,
                      color: AppColors.textHint.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text('Архив пуст',
                      style: TextStyle(
                          fontSize: 15,
                          color:
                              AppColors.textHint.withValues(alpha: 0.6))),
                  const SizedBox(height: 4),
                  Text('Проведите влево по чату для архивации',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              AppColors.textHint.withValues(alpha: 0.4))),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final chatId = docs[i].id;
              final participants =
                  List<String>.from(data['participants'] as List? ?? []);
              final peerId = participants.firstWhere((p) => p != uid,
                  orElse: () => '');
              final lastMsg = data['lastMessage'] as String? ?? '';

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(peerId)
                    .get(),
                builder: (_, userSnap) {
                  final userData =
                      userSnap.data?.data() as Map<String, dynamic>?;
                  final peerName =
                      userData?['displayName'] as String? ??
                          userData?['phoneNumber'] as String? ??
                          peerId;
                  final peerAvatar =
                      userData?['avatarBase64'] as String?;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: VCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            peerId: peerId,
                            peerName: peerName,
                          ),
                        ),
                      ),
                      onLongPress: () async {
                        // Unarchive
                        await FirebaseFirestore.instance
                            .collection('chats')
                            .doc(chatId)
                            .update({
                          'archivedBy': FieldValue.arrayRemove([uid]),
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Чат разархивирован')),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          VAvatar(
                            name: peerName,
                            imageUrl: peerAvatar,
                            radius: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(peerName,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 2),
                                Text(lastMsg,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.7))),
                              ],
                            ),
                          ),
                          Icon(Icons.unarchive_rounded,
                              size: 20,
                              color:
                                  AppColors.textHint.withValues(alpha: 0.5)),
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
