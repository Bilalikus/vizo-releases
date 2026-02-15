import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/constants.dart';
import '../../models/group_model.dart';
import '../../providers/providers.dart';

/// Group / community chat screen.
class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key, required this.group});
  final GroupModel group;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _db = FirebaseFirestore.instance;

  late final String _myUid;
  final _showScrollFab = ValueNotifier<bool>(false);
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _myUid = ref.read(authServiceProvider).effectiveUid;
    _scrollCtrl.addListener(_onScroll);
    _msgCtrl.addListener(() {
      final has = _msgCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    _showScrollFab.value = _scrollCtrl.offset > 300;
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();
    setState(() => _hasText = false);

    final currentUser = ref.read(currentUserProvider);
    final senderName = currentUser.displayName.isNotEmpty
        ? currentUser.displayName
        : currentUser.phoneNumber;

    // Update group last message
    await _db.collection('groups').doc(widget.group.id).update({
      'lastMessage': '$senderName: $text',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _db
        .collection('groups')
        .doc(widget.group.id)
        .collection('messages')
        .add({
      'chatId': widget.group.id,
      'senderId': _myUid,
      'senderName': senderName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'isEdited': false,
      'isDeleted': false,
    });
  }

  Future<void> _sendImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    final ext = picked.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final b64 = base64Encode(bytes);
    final dataUri = 'data:$mime;base64,$b64';

    final currentUser = ref.read(currentUserProvider);
    final senderName = currentUser.displayName.isNotEmpty
        ? currentUser.displayName
        : currentUser.phoneNumber;

    await _db.collection('groups').doc(widget.group.id).update({
      'lastMessage': '$senderName: 📷 Фото',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _db
        .collection('groups')
        .doc(widget.group.id)
        .collection('messages')
        .add({
      'chatId': widget.group.id,
      'senderId': _myUid,
      'senderName': senderName,
      'text': '📷 Фото',
      'mediaUrl': dataUri,
      'mediaType': 'image',
      'mediaName': picked.name,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'isEdited': false,
      'isDeleted': false,
    });
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final isAdmin = group.admins.contains(_myUid);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Column(
        children: [
          // ─── App Bar ────────────────
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  right: 12,
                  bottom: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: group.isCommunity
                            ? Colors.blue.withValues(alpha: 0.15)
                            : AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        group.isCommunity
                            ? Icons.public_rounded
                            : Icons.group_rounded,
                        color: group.isCommunity
                            ? Colors.blue
                            : AppColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${group.members.length} участников',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      GestureDetector(
                        onTap: () => _showGroupSettings(context),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.settings_rounded,
                              color: AppColors.textHint, size: 22),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Messages ──────────────
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _db
                      .collection('groups')
                      .doc(group.id)
                      .collection('messages')
                      .orderBy('createdAt', descending: true)
                      .limit(100)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              group.isCommunity
                                  ? Icons.public_rounded
                                  : Icons.group_rounded,
                              size: 56,
                              color: AppColors.textHint
                                  .withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Нет сообщений',
                              style: TextStyle(
                                color: AppColors.textHint
                                    .withValues(alpha: 0.6),
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Будьте первым!',
                              style: TextStyle(
                                color: AppColors.textHint
                                    .withValues(alpha: 0.4),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true,
                      padding: const EdgeInsets.all(AppSizes.md),
                      cacheExtent: 1000,
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final data =
                            docs[i].data() as Map<String, dynamic>;
                        final senderId =
                            data['senderId'] as String? ?? '';
                        final senderName =
                            data['senderName'] as String? ?? '';
                        final text = data['text'] as String? ?? '';
                        final mediaUrl = data['mediaUrl'] as String?;
                        final mediaType = data['mediaType'] as String?;
                        final isMe = senderId == _myUid;
                        final isDeleted =
                            data['isDeleted'] as bool? ?? false;
                        final ts =
                            (data['createdAt'] as Timestamp?)?.toDate();
                        final timeStr = ts != null
                            ? '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                            : '';

                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 6),
                          child: Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context)
                                        .size
                                        .width *
                                    0.75,
                              ),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppColors.accent
                                        .withValues(alpha: 0.2)
                                    : Colors.white
                                        .withValues(alpha: 0.06),
                                borderRadius: BorderRadius.only(
                                  topLeft:
                                      const Radius.circular(14),
                                  topRight:
                                      const Radius.circular(14),
                                  bottomLeft: Radius.circular(
                                      isMe ? 14 : 4),
                                  bottomRight: Radius.circular(
                                      isMe ? 4 : 14),
                                ),
                                border: Border.all(
                                  color: isMe
                                      ? AppColors.accent
                                          .withValues(alpha: 0.15)
                                      : Colors.white
                                          .withValues(alpha: 0.05),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(
                                              bottom: 4),
                                      child: Text(
                                        senderName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w600,
                                          color: AppColors.accent
                                              .withValues(
                                                  alpha: 0.8),
                                        ),
                                      ),
                                    ),
                                  if (isDeleted)
                                    Text(
                                      'Сообщение удалено',
                                      style: TextStyle(
                                        fontStyle:
                                            FontStyle.italic,
                                        color: AppColors.textHint
                                            .withValues(
                                                alpha: 0.5),
                                      ),
                                    )
                                  else ...[
                                    if (mediaType == 'image' &&
                                        mediaUrl != null) ...[
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(
                                                8),
                                        child:
                                            _buildImage(mediaUrl),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    if (text.isNotEmpty &&
                                        !text.startsWith('📷'))
                                      Text(
                                        text,
                                        style: const TextStyle(
                                          color: AppColors
                                              .textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textHint
                                          .withValues(
                                              alpha: 0.5),
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
                ),

                // ─── Scroll FAB ────
                Positioned(
                  bottom: 8,
                  right: 12,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _showScrollFab,
                    builder: (_, show, __) {
                      if (!show) return const SizedBox.shrink();
                      return FloatingActionButton.small(
                        backgroundColor:
                            AppColors.accent.withValues(alpha: 0.8),
                        onPressed: _scrollToBottom,
                        child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ─── Input Bar ─────────────
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: EdgeInsets.only(
                  left: 10,
                  right: 10,
                  top: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _sendImage,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.image_rounded,
                            color: AppColors.textHint, size: 24),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14),
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white
                                .withValues(alpha: 0.08),
                          ),
                        ),
                        child: TextField(
                          controller: _msgCtrl,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Сообщение...',
                            hintStyle: TextStyle(
                                color: AppColors.textHint),
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 10),
                          ),
                          maxLines: 3,
                          minLines: 1,
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _hasText ? _send : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _hasText
                              ? AppColors.accent
                              : Colors.white
                                  .withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          color: _hasText
                              ? Colors.white
                              : AppColors.textHint,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String url) {
    if (url.startsWith('data:')) {
      try {
        final commaIdx = url.indexOf(',');
        if (commaIdx > 0) {
          final bytes = base64Decode(url.substring(commaIdx + 1));
          return Image.memory(
            bytes,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imagePlaceholder(),
          );
        }
      } catch (_) {}
    }
    if (url.startsWith('/') || url.startsWith('file:')) {
      final file = File(url.replaceFirst('file://', ''));
      if (file.existsSync()) {
        return Image.file(file, width: double.infinity, fit: BoxFit.cover);
      }
    }
    if (url.startsWith('http')) {
      return Image.network(url, width: double.infinity, fit: BoxFit.cover);
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 120,
      color: Colors.white.withValues(alpha: 0.05),
      child: const Center(
        child: Icon(Icons.broken_image_rounded,
            color: AppColors.textHint, size: 32),
      ),
    );
  }

  void _showGroupSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.group.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.group.members.length} участников',
                  style: const TextStyle(
                      color: AppColors.textHint, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _SettingsItem(
                  icon: Icons.person_add_rounded,
                  label: 'Добавить участника',
                  onTap: () {
                    Navigator.pop(ctx);
                    _addMember(context);
                  },
                ),
                _SettingsItem(
                  icon: Icons.exit_to_app_rounded,
                  label: 'Покинуть группу',
                  color: AppColors.error,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _leaveGroup();
                  },
                ),
                if (widget.group.creatorUid == _myUid)
                  _SettingsItem(
                    icon: Icons.delete_forever_rounded,
                    label: 'Удалить группу',
                    color: AppColors.error,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _deleteGroup();
                    },
                  ),
                SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addMember(BuildContext context) async {
    final phoneCtrl = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Добавить участника',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600)),
        content: TextField(
          controller: phoneCtrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Номер телефона',
            hintStyle: TextStyle(color: AppColors.textHint),
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, phoneCtrl.text.trim()),
            child: const Text('Добавить',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );

    if (phone == null || phone.isEmpty) return;

    // Find user by phone
    final snap = await _db
        .collection('users')
        .where('phoneNumber', isEqualTo: phone)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь не найден')),
        );
      }
      return;
    }

    final userId = snap.docs.first.id;
    await _db.collection('groups').doc(widget.group.id).update({
      'members': FieldValue.arrayUnion([userId]),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Участник добавлен')),
      );
    }
  }

  Future<void> _leaveGroup() async {
    await _db.collection('groups').doc(widget.group.id).update({
      'members': FieldValue.arrayRemove([_myUid]),
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteGroup() async {
    // Delete all messages
    final msgs = await _db
        .collection('groups')
        .doc(widget.group.id)
        .collection('messages')
        .get();
    final batch = _db.batch();
    for (final doc in msgs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    // Delete group
    await _db.collection('groups').doc(widget.group.id).delete();
    if (mounted) Navigator.pop(context);
  }
}

// ─── Settings Item ───────────────────────

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(label, style: TextStyle(color: c, fontSize: 14)),
      onTap: onTap,
    );
  }
}
