import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Storage & Data — see how much space each chat uses.
class StorageDataScreen extends ConsumerStatefulWidget {
  const StorageDataScreen({super.key});

  @override
  ConsumerState<StorageDataScreen> createState() =>
      _StorageDataScreenState();
}

class _StorageDataScreenState extends ConsumerState<StorageDataScreen> {
  final _stats = <_ChatStats>[];
  bool _loading = true;
  int _totalMessages = 0;
  int _totalMedia = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final uid = ref.read(authServiceProvider).effectiveUid;
    final db = FirebaseFirestore.instance;

    try {
      final chats = await db
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();

      final List<_ChatStats> stats = [];
      int totalMsg = 0;
      int totalMedia = 0;

      for (final chatDoc in chats.docs) {
        final data = chatDoc.data();
        final participants =
            List<String>.from(data['participants'] as List? ?? []);
        final peerId = participants.firstWhere((p) => p != uid,
            orElse: () => '');

        final msgs = await db
            .collection('chats')
            .doc(chatDoc.id)
            .collection('messages')
            .get();

        int mediaCount = 0;
        for (final m in msgs.docs) {
          final mData = m.data();
          final type = mData['type'] as String?;
          if (type == 'image' || type == 'video' || type == 'voice') {
            mediaCount++;
          }
        }

        totalMsg += msgs.docs.length;
        totalMedia += mediaCount;

        // Fetch peer name
        final userDoc = await db.collection('users').doc(peerId).get();
        final peerName =
            userDoc.data()?['displayName'] as String? ??
                userDoc.data()?['phoneNumber'] as String? ??
                peerId;

        stats.add(_ChatStats(
          chatId: chatDoc.id,
          peerName: peerName,
          messageCount: msgs.docs.length,
          mediaCount: mediaCount,
        ));
      }

      stats.sort((a, b) => b.messageCount.compareTo(a.messageCount));

      if (mounted) {
        setState(() {
          _stats.addAll(stats);
          _totalMessages = totalMsg;
          _totalMedia = totalMedia;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              title: const Text('Данные и хранилище',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.message_rounded,
                        label: 'Сообщений',
                        value: '$_totalMessages',
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.photo_library_rounded,
                        label: 'Медиа',
                        value: '$_totalMedia',
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.chat_rounded,
                        label: 'Чатов',
                        value: '${_stats.length}',
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Text('По чатам',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            AppColors.accent.withValues(alpha: 0.7))),
                const SizedBox(height: 8),

                ..._stats.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: VCard(
                        enableDragStretch: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(s.peerName,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color:
                                              AppColors.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${s.messageCount} сообщ. • ${s.mediaCount} медиа',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textHint
                                            .withValues(alpha: 0.6)),
                                  ),
                                ],
                              ),
                            ),
                            // Proportional bar
                            SizedBox(
                              width: 60,
                              height: 6,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: _totalMessages > 0
                                      ? s.messageCount /
                                          _totalMessages
                                      : 0,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.06),
                                  valueColor:
                                      const AlwaysStoppedAnimation(
                                          AppColors.accent),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
    );
  }
}

class _ChatStats {
  const _ChatStats({
    required this.chatId,
    required this.peerName,
    required this.messageCount,
    required this.mediaCount,
  });
  final String chatId;
  final String peerName;
  final int messageCount;
  final int mediaCount;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}
