import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';

/// Media gallery — grid view of all images/videos in a chat.
class MediaGalleryScreen extends StatelessWidget {
  const MediaGalleryScreen({
    super.key,
    required this.chatId,
    required this.peerName,
    this.isGroup = false,
  });

  final String chatId;
  final String peerName;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final collection = isGroup ? 'groups' : 'chats';

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
              title: Text('Медиа • $peerName',
                  style: const TextStyle(
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
            .collection(collection)
            .doc(chatId)
            .collection('messages')
            .where('type', whereIn: ['image', 'video'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 56,
                      color: AppColors.textHint.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text('Нет медиафайлов',
                      style: TextStyle(
                          fontSize: 15,
                          color:
                              AppColors.textHint.withValues(alpha: 0.6))),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final type = data['type'] as String? ?? 'image';
              final mediaBase64 = data['mediaBase64'] as String? ?? '';

              Widget thumbnail;
              if (mediaBase64.isNotEmpty) {
                try {
                  thumbnail = Image.memory(
                    base64Decode(mediaBase64),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  );
                } catch (_) {
                  thumbnail = Container(
                    color: Colors.white.withValues(alpha: 0.06),
                    child: const Icon(Icons.broken_image_rounded,
                        color: AppColors.textHint),
                  );
                }
              } else {
                thumbnail = Container(
                  color: Colors.white.withValues(alpha: 0.06),
                  child: Icon(
                    type == 'video'
                        ? Icons.videocam_rounded
                        : Icons.image_rounded,
                    color: AppColors.textHint,
                  ),
                );
              }

              return GestureDetector(
                onTap: () {
                  // Full-screen preview
                  showDialog(
                    context: context,
                    builder: (ctx) => Dialog(
                      backgroundColor: Colors.transparent,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: thumbnail,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      thumbnail,
                      if (type == 'video')
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.play_arrow_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
