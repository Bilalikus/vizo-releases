import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../models/message_model.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Chat info — shared media count, mute, pin, clear, block.
class ChatInfoScreen extends ConsumerStatefulWidget {
  const ChatInfoScreen({
    super.key,
    required this.chatId,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
  });

  final String chatId;
  final String peerId;
  final String peerName;
  final String? peerAvatar;

  @override
  ConsumerState<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends ConsumerState<ChatInfoScreen> {
  bool _muted = false;
  bool _pinned = false;

  @override
  void initState() {
    super.initState();
    _loadChatMeta();
  }

  Future<void> _loadChatMeta() async {
    final uid = ref.read(authServiceProvider).effectiveUid;
    final doc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .get();
    if (!doc.exists) return;
    final data = doc.data() ?? {};
    final mutedBy = List<String>.from(data['mutedBy'] ?? []);
    final pinnedBy = List<String>.from(data['pinnedBy'] ?? []);
    if (mounted) {
      setState(() {
        _muted = mutedBy.contains(uid);
        _pinned = pinnedBy.contains(uid);
      });
    }
  }

  Future<void> _toggleMute() async {
    final uid = ref.read(authServiceProvider).effectiveUid;
    final ref2 = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId);
    if (_muted) {
      await ref2.update({
        'mutedBy': FieldValue.arrayRemove([uid])
      });
    } else {
      await ref2.set({
        'mutedBy': FieldValue.arrayUnion([uid])
      }, SetOptions(merge: true));
    }
    setState(() => _muted = !_muted);
  }

  Future<void> _togglePin() async {
    final uid = ref.read(authServiceProvider).effectiveUid;
    final ref2 = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId);
    if (_pinned) {
      await ref2.update({
        'pinnedBy': FieldValue.arrayRemove([uid])
      });
    } else {
      await ref2.set({
        'pinnedBy': FieldValue.arrayUnion([uid])
      }, SetOptions(merge: true));
    }
    setState(() => _pinned = !_pinned);
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: const Text('Очистить историю?',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: const Text('Все сообщения будут удалены.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Очистить',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final msgs = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in msgs.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('История очищена')),
      );
    }
  }

  Future<void> _blockUser() async {
    final uid = ref.read(authServiceProvider).effectiveUid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'blockedUsers': FieldValue.arrayUnion([widget.peerId]),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.peerName} заблокирован')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _exportChat() async {
    // Collect all messages and show in a share-ready dialog
    final msgs = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('createdAt')
        .get();

    final buf = StringBuffer('Чат с ${widget.peerName}\n');
    buf.writeln('=' * 30);
    for (final doc in msgs.docs) {
      final m = MessageModel.fromFirestore(doc);
      if (m.isDeleted) continue;
      final t =
          '${m.createdAt.day}.${m.createdAt.month.toString().padLeft(2, '0')} ${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}';
      buf.writeln('[$t] ${m.senderName}: ${m.text}');
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: const Text('Экспорт чата',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              buf.toString(),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Закрыть', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
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
              title: const Text('Информация',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Avatar + Name ──
          Center(
            child: Column(
              children: [
                VAvatar(
                  name: widget.peerName,
                  imageUrl: widget.peerAvatar,
                  radius: 44,
                  showGlow: true,
                ),
                const SizedBox(height: 12),
                Text(widget.peerName,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.peerId)
                      .snapshots(),
                  builder: (_, snap) {
                    final d =
                        snap.data?.data() as Map<String, dynamic>? ?? {};
                    final online = d['isOnline'] as bool? ?? false;
                    return Text(
                      online ? 'в сети' : 'не в сети',
                      style: TextStyle(
                        fontSize: 14,
                        color: online
                            ? AppColors.success
                            : AppColors.textHint.withValues(alpha: 0.6),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Actions grid ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _QuickAction(
                icon: _muted
                    ? Icons.notifications_off_rounded
                    : Icons.notifications_rounded,
                label: _muted ? 'Вкл звук' : 'Без звука',
                onTap: _toggleMute,
              ),
              _QuickAction(
                icon: _pinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                label: _pinned ? 'Открепить' : 'Закрепить',
                onTap: _togglePin,
              ),
              _QuickAction(
                icon: Icons.search_rounded,
                label: 'Поиск',
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ChatSearchScreen(
                            chatId: widget.chatId,
                            peerName: widget.peerName))),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Media count ──
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .doc(widget.chatId)
                .collection('messages')
                .snapshots(),
            builder: (_, snap) {
              final total = snap.data?.docs.length ?? 0;
              return VCard(
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text('Всего сообщений: $total',
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.textPrimary)),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // ── Pinned messages ──
          VCard(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => _PinnedMessagesScreen(
                        chatId: widget.chatId,
                        peerName: widget.peerName))),
            child: const Row(
              children: [
                Icon(Icons.push_pin_rounded,
                    size: 20, color: AppColors.accent),
                SizedBox(width: 12),
                Text('Закреплённые сообщения',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.textPrimary)),
                Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.textHint),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Starred messages ──
          VCard(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => StarredMessagesScreen(
                        chatId: widget.chatId,
                        peerName: widget.peerName))),
            child: const Row(
              children: [
                Icon(Icons.star_rounded,
                    size: 20, color: AppColors.warning),
                SizedBox(width: 12),
                Text('Избранные сообщения',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.textPrimary)),
                Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: AppColors.textHint),
              ],
            ),
          ),

          const SizedBox(height: 8),
          VCard(
            onTap: _exportChat,
            child: const Row(
              children: [
                Icon(Icons.download_rounded,
                    size: 20, color: AppColors.textSecondary),
                SizedBox(width: 12),
                Text('Экспорт чата',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.textPrimary)),
              ],
            ),
          ),

          const SizedBox(height: 8),
          VCard(
            onTap: _clearHistory,
            child: const Row(
              children: [
                Icon(Icons.delete_sweep_rounded,
                    size: 20, color: AppColors.error),
                SizedBox(width: 12),
                Text('Очистить историю',
                    style: TextStyle(fontSize: 15, color: AppColors.error)),
              ],
            ),
          ),

          const SizedBox(height: 8),
          VCard(
            onTap: _blockUser,
            child: Row(
              children: [
                const Icon(Icons.block_rounded,
                    size: 20, color: AppColors.error),
                const SizedBox(width: 12),
                Text('Заблокировать ${widget.peerName}',
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Action Button ─────────────────────────────────

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Icon(icon, color: AppColors.accentLight, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

// ─── Chat Search ─────────────────────────────────────────

class ChatSearchScreen extends StatefulWidget {
  const ChatSearchScreen({
    super.key,
    required this.chatId,
    required this.peerName,
  });
  final String chatId;
  final String peerName;

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final _ctrl = TextEditingController();
  List<MessageModel> _results = [];
  bool _searching = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);

    final snap = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .get();

    final q = query.toLowerCase();
    final filtered = snap.docs
        .map((d) => MessageModel.fromFirestore(d))
        .where((m) => !m.isDeleted && m.text.toLowerCase().contains(q))
        .toList();

    setState(() {
      _results = filtered;
      _searching = false;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
              title: TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Поиск в чате...',
                  hintStyle: TextStyle(
                      color: AppColors.textHint.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                ),
                onChanged: _search,
              ),
            ),
          ),
        ),
      ),
      body: _searching
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
          : _results.isEmpty
              ? Center(
                  child: Text(
                    _ctrl.text.isEmpty
                        ? 'Введите текст для поиска'
                        : 'Ничего не найдено',
                    style: TextStyle(
                      color: AppColors.textHint.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final m = _results[i];
                    final t =
                        '${m.createdAt.day}.${m.createdAt.month.toString().padLeft(2, '0')} ${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: VCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(m.senderName,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accentLight)),
                                ),
                                Text(t,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textHint
                                            .withValues(alpha: 0.5))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(m.text,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ─── Starred Messages ────────────────────────────────────

class StarredMessagesScreen extends StatelessWidget {
  const StarredMessagesScreen({
    super.key,
    required this.chatId,
    required this.peerName,
  });
  final String chatId;
  final String peerName;

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
              title: const Text('Избранные',
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
            .doc(chatId)
            .collection('messages')
            .where('isStarred', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_outline_rounded,
                      size: 56,
                      color: AppColors.textHint.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text('Нет избранных сообщений',
                      style: TextStyle(
                          color:
                              AppColors.textHint.withValues(alpha: 0.6),
                          fontSize: 15)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final m = MessageModel.fromFirestore(docs[i]);
              final t =
                  '${m.createdAt.day}.${m.createdAt.month.toString().padLeft(2, '0')} ${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: VCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(m.senderName,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accentLight)),
                          ),
                          Text(t,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textHint
                                      .withValues(alpha: 0.5))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(m.text,
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary)),
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

// ─── Pinned Messages ─────────────────────────────────────

class _PinnedMessagesScreen extends StatelessWidget {
  const _PinnedMessagesScreen({
    required this.chatId,
    required this.peerName,
  });
  final String chatId;
  final String peerName;

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
              title: const Text('Закреплённые',
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
            .doc(chatId)
            .collection('messages')
            .where('isPinned', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.push_pin_outlined,
                      size: 56,
                      color: AppColors.textHint.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text('Нет закреплённых сообщений',
                      style: TextStyle(
                          color: AppColors.textHint.withValues(alpha: 0.6),
                          fontSize: 15)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final m = MessageModel.fromFirestore(docs[i]);
              final t =
                  '${m.createdAt.day}.${m.createdAt.month.toString().padLeft(2, '0')} ${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: VCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.push_pin_rounded,
                              size: 14, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(m.senderName,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accentLight)),
                          ),
                          Text(t,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textHint
                                      .withValues(alpha: 0.5))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(m.text,
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary)),
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
