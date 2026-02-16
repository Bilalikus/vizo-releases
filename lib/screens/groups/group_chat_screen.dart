import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/constants/constants.dart';
import '../../models/group_model.dart';
import '../../models/sticker_model.dart';
import '../../providers/providers.dart';
import 'create_poll_screen.dart';

/// Group / community / channel chat screen — unified design matching personal chat.
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

  // Reply / Edit state
  Map<String, dynamic>? _replyTo;
  String? _editingMsgId;
  bool _showStickerPicker = false;

  // Voice recording state
  bool _isRecording = false;
  bool _recordingLocked = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  final AudioRecorder _audioRecorder = AudioRecorder();

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
    _showScrollFab.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    _showScrollFab.value = _scrollCtrl.offset > 300;
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  // ─── Send text message ──────────────────

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();
    setState(() => _hasText = false);

    if (_editingMsgId != null) {
      await _db.collection('groups').doc(widget.group.id).collection('messages')
          .doc(_editingMsgId).update({'text': text, 'isEdited': true});
      setState(() => _editingMsgId = null);
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    final senderName = currentUser.displayName.isNotEmpty
        ? currentUser.displayName : currentUser.phoneNumber;

    await _db.collection('groups').doc(widget.group.id).update({
      'lastMessage': '$senderName: $text',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final msgData = <String, dynamic>{
      'chatId': widget.group.id,
      'senderId': _myUid,
      'senderName': senderName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'isEdited': false,
      'isDeleted': false,
    };

    if (_replyTo != null) {
      msgData['replyToId'] = _replyTo!['id'];
      msgData['replyToText'] = _replyTo!['text'];
      msgData['replyToSender'] = _replyTo!['senderName'];
    }

    await _db.collection('groups').doc(widget.group.id).collection('messages').add(msgData);
    setState(() => _replyTo = null);
  }

  // ─── Voice recording ──────────────────

  void _startRecording() async {
    if (_isRecording) return;
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/vizo_grp_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 32000, sampleRate: 16000, numChannels: 1),
          path: path,
        );
        setState(() { _isRecording = true; _recordSeconds = 0; });
        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _recordSeconds++);
            if (_recordSeconds >= 60) _stopRecording(send: true);
          }
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нет доступа к микрофону')));
      }
    } catch (e) { debugPrint('Recording error: $e'); }
  }

  Future<void> _stopRecording({bool send = true}) async {
    _recordTimer?.cancel();
    _recordTimer = null;
    if (!_isRecording) return;
    final duration = _recordSeconds;
    setState(() { _isRecording = false; _recordSeconds = 0; _recordingLocked = false; });

    String? path;
    try { path = await _audioRecorder.stop(); } catch (e) { debugPrint('Stop recording error: $e'); }
    if (!send || duration < 1 || path == null) return;

    try {
      final file = File(path);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 700000) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Голосовое слишком длинное. Макс ~60 сек.')));
        try { await file.delete(); } catch (_) {}
        return;
      }

      final base64Audio = base64Encode(bytes);
      final currentUser = ref.read(currentUserProvider);
      final senderName = currentUser.displayName.isNotEmpty ? currentUser.displayName : currentUser.phoneNumber;
      final durStr = '${(duration ~/ 60).toString().padLeft(2, '0')}:${(duration % 60).toString().padLeft(2, '0')}';

      await _db.collection('groups').doc(widget.group.id).update({
        'lastMessage': '$senderName: 🎤 Голосовое ($durStr)',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('groups').doc(widget.group.id).collection('messages').add({
        'chatId': widget.group.id, 'senderId': _myUid, 'senderName': senderName,
        'text': '🎤 Голосовое сообщение ($durStr)', 'mediaType': 'voice',
        'mediaUrl': base64Audio, 'mediaName': 'voice_message.m4a', 'mediaSize': duration,
        'createdAt': FieldValue.serverTimestamp(), 'isRead': false, 'isEdited': false, 'isDeleted': false,
      });
      try { await file.delete(); } catch (_) {}
    } catch (e) {
      debugPrint('Voice send error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка отправки: $e')));
    }
  }

  void _cancelRecording() {
    _recordTimer?.cancel(); _recordTimer = null;
    try { _audioRecorder.stop(); } catch (_) {}
    setState(() { _isRecording = false; _recordSeconds = 0; _recordingLocked = false; });
  }

  // ─── Send sticker ─────────────────────

  Future<void> _sendSticker(String emoji) async {
    final currentUser = ref.read(currentUserProvider);
    final senderName = currentUser.displayName.isNotEmpty ? currentUser.displayName : currentUser.phoneNumber;
    await _db.collection('groups').doc(widget.group.id).update({
      'lastMessage': '$senderName: $emoji', 'lastMessageAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('groups').doc(widget.group.id).collection('messages').add({
      'chatId': widget.group.id, 'senderId': _myUid, 'senderName': senderName,
      'text': emoji, 'mediaType': 'sticker',
      'createdAt': FieldValue.serverTimestamp(), 'isRead': false, 'isEdited': false, 'isDeleted': false,
    });
    setState(() => _showStickerPicker = false);
  }

  // ─── Message actions ──────────────────

  void _showMessageActions(Map<String, dynamic> data, String docId) {
    final isMine = (data['senderId'] as String? ?? '') == _myUid;
    final isDeleted = data['isDeleted'] as bool? ?? false;
    if (isDeleted) return;
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [const Color(0xFF1A1028).withValues(alpha: 0.95), AppColors.surfaceLight.withValues(alpha: 0.98)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: AppColors.accent.withValues(alpha: 0.2))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['❤️', '👍', '😂', '😮', '😢', '🔥', '🎉', '👏'].map((e) {
                    return GestureDetector(
                      onTap: () { Navigator.pop(context); _addReaction(docId, e); },
                      child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
                        child: Center(child: Text(e, style: const TextStyle(fontSize: 20)))),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _ActionTile(icon: Icons.reply_rounded, label: 'Ответить', onTap: () {
                  Navigator.pop(context); setState(() => _replyTo = {...data, 'id': docId});
                }),
                _ActionTile(icon: Icons.content_copy_rounded, label: 'Копировать', onTap: () {
                  Navigator.pop(context); Clipboard.setData(ClipboardData(text: data['text'] as String? ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано')));
                }),
                if (isMine) ...[
                  _ActionTile(icon: Icons.edit_rounded, label: 'Редактировать', onTap: () {
                    Navigator.pop(context); setState(() { _editingMsgId = docId; _msgCtrl.text = data['text'] as String? ?? ''; });
                  }),
                  _ActionTile(icon: Icons.delete_outline_rounded, label: 'Удалить', color: AppColors.error, onTap: () async {
                    Navigator.pop(context);
                    await _db.collection('groups').doc(widget.group.id).collection('messages').doc(docId).update({'isDeleted': true, 'text': ''});
                  }),
                ],
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addReaction(String docId, String emoji) async {
    final msgRef = _db.collection('groups').doc(widget.group.id).collection('messages').doc(docId);
    final snap = await msgRef.get();
    final data = snap.data() ?? {};
    final reactions = Map<String, dynamic>.from(data['reactions'] as Map? ?? {});
    final list = List<String>.from(reactions[emoji] as List? ?? []);
    if (list.contains(_myUid)) { list.remove(_myUid); if (list.isEmpty) reactions.remove(emoji); else reactions[emoji] = list; }
    else { list.add(_myUid); reactions[emoji] = list; }
    await msgRef.update({'reactions': reactions, 'reaction': emoji});
  }

  // ─── Send image ───────────────────────

  Future<void> _sendImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1024);
    if (picked == null) return;
    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    final ext = picked.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

    final currentUser = ref.read(currentUserProvider);
    final senderName = currentUser.displayName.isNotEmpty ? currentUser.displayName : currentUser.phoneNumber;
    await _db.collection('groups').doc(widget.group.id).update({
      'lastMessage': '$senderName: 📷 Фото', 'lastMessageAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('groups').doc(widget.group.id).collection('messages').add({
      'chatId': widget.group.id, 'senderId': _myUid, 'senderName': senderName,
      'text': '📷 Фото', 'mediaUrl': dataUri, 'mediaType': 'image', 'mediaName': picked.name,
      'createdAt': FieldValue.serverTimestamp(), 'isRead': false, 'isEdited': false, 'isDeleted': false,
    });
  }

  // ─── Group icon widget ────────────────

  Widget _buildGroupAvatar({double size = 38}) {
    final group = widget.group;
    if (group.avatarBase64 != null && group.avatarBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(group.avatarBase64!);
        return ClipRRect(borderRadius: BorderRadius.circular(size * 0.32),
          child: Image.memory(bytes, width: size, height: size, fit: BoxFit.cover));
      } catch (_) {}
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: group.isCommunity
            ? [Colors.blue.withValues(alpha: 0.3), Colors.blue.withValues(alpha: 0.15)]
            : [AppColors.accent.withValues(alpha: 0.3), AppColors.accent.withValues(alpha: 0.15)]),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: (group.isCommunity ? Colors.blue : AppColors.accent).withValues(alpha: 0.2), width: 0.5),
      ),
      child: Icon(
        group.isCommunity ? Icons.public_rounded : group.type == 'channel' ? Icons.campaign_rounded : Icons.group_rounded,
        color: group.isCommunity ? Colors.blue : AppColors.accent, size: size * 0.5),
    );
  }

  // ─── Edit group info ──────────────────

  Future<void> _editGroupInfo() async {
    final nameCtrl = TextEditingController(text: widget.group.name);
    final descCtrl = TextEditingController(text: widget.group.description);
    String? newAvatarBase64;

    final result = await showModalBottomSheet<bool>(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [const Color(0xFF1A1028).withValues(alpha: 0.95), AppColors.surfaceLight.withValues(alpha: 0.98)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 20),
                    const Text('Редактировать', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () async {
                        final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 60, maxWidth: 256);
                        if (picked == null) return;
                        final bytes = await File(picked.path).readAsBytes();
                        setSheetState(() => newAvatarBase64 = base64Encode(bytes));
                      },
                      child: Stack(
                        children: [
                          if (newAvatarBase64 != null)
                            ClipRRect(borderRadius: BorderRadius.circular(20),
                              child: Image.memory(base64Decode(newAvatarBase64!), width: 80, height: 80, fit: BoxFit.cover))
                          else _buildGroupAvatar(size: 80),
                          Positioned(bottom: 0, right: 0, child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surfaceLight, width: 2)),
                            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(controller: nameCtrl, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                      decoration: InputDecoration(labelText: 'Название', labelStyle: const TextStyle(color: AppColors.textHint),
                        filled: true, fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent)))),
                    const SizedBox(height: 12),
                    TextField(controller: descCtrl, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14), maxLines: 3,
                      decoration: InputDecoration(labelText: 'Описание', labelStyle: const TextStyle(color: AppColors.textHint),
                        filled: true, fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent)))),
                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text('Сохранить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (result != true) return;
    final updates = <String, dynamic>{};
    final newName = nameCtrl.text.trim();
    if (newName.isNotEmpty && newName != widget.group.name) updates['name'] = newName;
    final newDesc = descCtrl.text.trim();
    if (newDesc != widget.group.description) updates['description'] = newDesc;
    if (newAvatarBase64 != null) updates['avatarBase64'] = newAvatarBase64;
    if (updates.isNotEmpty) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _db.collection('groups').doc(widget.group.id).update(updates);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Информация обновлена')));
    }
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
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 12, right: 12, bottom: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [const Color(0xFF1A1028).withValues(alpha: 0.8), Colors.white.withValues(alpha: 0.03)]),
                  border: Border(bottom: BorderSide(color: AppColors.accent.withValues(alpha: 0.1))),
                ),
                child: Row(
                  children: [
                    GestureDetector(onTap: () => Navigator.pop(context),
                      child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20))),
                    const SizedBox(width: 8),
                    _buildGroupAvatar(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: isAdmin ? _editGroupInfo : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(group.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('${group.members.length} участников', style: TextStyle(fontSize: 12, color: AppColors.textHint.withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                    ),
                    if (isAdmin) ...[
                      GestureDetector(onTap: _editGroupInfo,
                        child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.edit_rounded, color: AppColors.accent.withValues(alpha: 0.7), size: 20))),
                      GestureDetector(onTap: () => _showGroupSettings(context),
                        child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.settings_rounded, color: AppColors.textHint, size: 22))),
                    ],
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
                  stream: _db.collection('groups').doc(group.id).collection('messages').orderBy('createdAt', descending: true).limit(100).snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          _buildGroupAvatar(size: 64),
                          const SizedBox(height: 16),
                          Text('Нет сообщений', style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.6), fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('Будьте первым!', style: TextStyle(color: AppColors.textHint.withValues(alpha: 0.4), fontSize: 13)),
                        ]),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollCtrl, reverse: true,
                      padding: const EdgeInsets.all(AppSizes.md), cacheExtent: 1000,
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final docId = docs[i].id;
                        return _GroupMessageBubble(
                          data: data, docId: docId,
                          isMe: (data['senderId'] as String? ?? '') == _myUid,
                          onLongPress: () => _showMessageActions(data, docId),
                          onDoubleTap: () => _addReaction(docId, '❤️'),
                          onReply: () => setState(() => _replyTo = {...data, 'id': docId}),
                        );
                      },
                    );
                  },
                ),
                Positioned(bottom: 8, right: 12,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _showScrollFab,
                    builder: (_, show, __) {
                      if (!show) return const SizedBox.shrink();
                      return FloatingActionButton.small(backgroundColor: AppColors.accent.withValues(alpha: 0.8),
                        onPressed: _scrollToBottom, child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white));
                    },
                  ),
                ),
              ],
            ),
          ),

          // ─── Reply / Edit preview bar ────
          if (_replyTo != null || _editingMsgId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1028).withValues(alpha: 0.9),
                border: Border(top: BorderSide(color: AppColors.accent.withValues(alpha: 0.3)), left: const BorderSide(color: AppColors.accentLight, width: 3)),
              ),
              child: Row(
                children: [
                  Icon(_editingMsgId != null ? Icons.edit_rounded : Icons.reply_rounded, color: AppColors.accentLight, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(_editingMsgId != null ? 'Редактирование' : (_replyTo?['senderName'] as String? ?? ''),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentLight)),
                    Text(_editingMsgId != null ? _msgCtrl.text : (_replyTo?['text'] as String? ?? '📷 Фото'),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.6))),
                  ])),
                  GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() {
                    _replyTo = null; if (_editingMsgId != null) { _editingMsgId = null; _msgCtrl.clear(); }
                  }), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close_rounded, color: AppColors.textHint, size: 18))),
                ],
              ),
            ),

          // ─── Recording Indicator ────
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1),
                border: Border(top: BorderSide(color: AppColors.error.withValues(alpha: 0.3)))),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text('Запись  ${(_recordSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(onTap: _cancelRecording,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
                    child: const Text('Отмена', style: TextStyle(color: AppColors.textHint, fontSize: 13)))),
                const SizedBox(width: 8),
                GestureDetector(onTap: () => _stopRecording(send: true),
                  child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18))),
              ]),
            ),

          // ─── Sticker Picker ────
          if (_showStickerPicker) Container(height: 200, color: AppColors.surfaceLight, child: _buildStickerGrid()),

          // ─── Input Bar ─────────────
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding: EdgeInsets.only(left: 6, right: 6, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.white.withValues(alpha: 0.04), const Color(0xFF0D0A14).withValues(alpha: 0.6)]),
                  border: Border(top: BorderSide(color: AppColors.accent.withValues(alpha: 0.08))),
                ),
                child: Row(children: [
                  GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => _showStickerPicker = !_showStickerPicker),
                    child: Padding(padding: const EdgeInsets.all(6), child: Icon(
                      _showStickerPicker ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                      color: _showStickerPicker ? AppColors.accent : AppColors.textHint, size: 22))),
                  GestureDetector(behavior: HitTestBehavior.opaque, onTap: _sendImage,
                    child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.image_rounded, color: AppColors.textHint, size: 22))),
                  GestureDetector(behavior: HitTestBehavior.opaque, onTap: _attachFile,
                    child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.attach_file_rounded, color: AppColors.textHint, size: 22))),
                  GestureDetector(behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePollScreen(groupId: widget.group.id))),
                    child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.poll_rounded, color: AppColors.textHint, size: 22))),
                  Expanded(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                    child: TextField(controller: _msgCtrl, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(hintText: 'Сообщение...', hintStyle: TextStyle(color: AppColors.textHint),
                        border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10)),
                      maxLines: 3, minLines: 1, onSubmitted: (_) => _send(),
                      onTap: () { if (_showStickerPicker) setState(() => _showStickerPicker = false); }),
                  )),
                  const SizedBox(width: 4),
                  if (_hasText || _editingMsgId != null)
                    GestureDetector(behavior: HitTestBehavior.opaque, onTap: _send,
                      child: Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [AppColors.accent, AppColors.accentLight.withValues(alpha: 0.5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5)),
                        child: Icon(_editingMsgId != null ? Icons.check_rounded : Icons.send_rounded, color: Colors.white, size: 20)))
                  else
                    GestureDetector(behavior: HitTestBehavior.opaque,
                      onLongPressStart: (_) => _startRecording(),
                      onLongPressEnd: (_) { if (_isRecording && !_recordingLocked) _stopRecording(send: true); },
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Зажмите для записи голосового'), duration: Duration(seconds: 1))),
                      child: Container(width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [AppColors.error.withValues(alpha: 0.6), AppColors.error.withValues(alpha: 0.4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5)),
                        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22))),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────

  Future<void> _attachFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    final f = File(file.path!);
    final bytes = await f.readAsBytes();
    final b64 = 'data:application/octet-stream;base64,${base64Encode(bytes)}';

    final currentUser = ref.read(currentUserProvider);
    final senderName = currentUser.displayName.isNotEmpty ? currentUser.displayName : currentUser.phoneNumber;
    await _db.collection('groups').doc(widget.group.id).collection('messages').add({
      'senderId': _myUid, 'senderName': senderName, 'text': '📎 ${file.name}',
      'mediaUrl': b64, 'mediaType': 'file', 'createdAt': FieldValue.serverTimestamp(), 'isDeleted': false,
    });
    await _db.collection('groups').doc(widget.group.id).update({
      'lastMessage': '📎 ${file.name}', 'lastMessageAt': FieldValue.serverTimestamp(),
    });
  }

  void _showGroupSettings(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [const Color(0xFF1A1028).withValues(alpha: 0.95), AppColors.surfaceLight.withValues(alpha: 0.98)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              _buildGroupAvatar(size: 56),
              const SizedBox(height: 12),
              Text(widget.group.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('${widget.group.members.length} участников', style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
              if (widget.group.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(widget.group.description, style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 13), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              if (isAdmin) _SettingsItem(icon: Icons.edit_rounded, label: 'Редактировать информацию', onTap: () { Navigator.pop(ctx); _editGroupInfo(); }),
              _SettingsItem(icon: Icons.person_add_rounded, label: 'Добавить участника', onTap: () { Navigator.pop(ctx); _addMember(context); }),
              _SettingsItem(icon: Icons.exit_to_app_rounded, label: 'Покинуть группу', color: AppColors.error, onTap: () async { Navigator.pop(ctx); await _leaveGroup(); }),
              if (widget.group.creatorUid == _myUid) _SettingsItem(icon: Icons.delete_forever_rounded, label: 'Удалить группу', color: AppColors.error, onTap: () async { Navigator.pop(ctx); await _deleteGroup(); }),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ]),
          ),
        ),
      ),
    );
  }

  bool get isAdmin => widget.group.admins.contains(_myUid);

  Future<void> _addMember(BuildContext context) async {
    final contacts = ref.read(contactsProvider);
    final currentMembers = widget.group.members;
    final eligible = contacts.where((c) { final uid = c.linkedUserId ?? ''; return uid.isNotEmpty && !currentMembers.contains(uid); }).toList();

    final selectedUid = await showModalBottomSheet<String>(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 12),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              const Text('Добавить участника', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Material(color: Colors.transparent, child: InkWell(
                onTap: () async { Navigator.pop(context); _addMemberByPhone(context); },
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), child: Row(children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.dialpad_rounded, color: AppColors.accent, size: 20)),
                  const SizedBox(width: 12),
                  const Text('Ввести номер телефона', style: TextStyle(fontSize: 15, color: AppColors.accent, fontWeight: FontWeight.w500)),
                ])),
              )),
              if (eligible.isEmpty)
                const Padding(padding: EdgeInsets.all(20), child: Text('Все контакты уже в группе', style: TextStyle(color: AppColors.textHint)))
              else Flexible(child: ListView.builder(shrinkWrap: true, itemCount: eligible.length, itemBuilder: (_, i) {
                final c = eligible[i];
                return Material(color: Colors.transparent, child: InkWell(
                  onTap: () => Navigator.pop(context, c.linkedUserId),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Row(children: [
                    CircleAvatar(radius: 20, backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                      child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                      Text(c.phoneNumber, style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.6))),
                    ])),
                    const Icon(Icons.person_add_rounded, size: 18, color: AppColors.accent),
                  ])),
                ));
              })),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ]),
          ),
        ),
      ),
    );
    if (selectedUid == null || selectedUid.isEmpty || !mounted) return;
    await _db.collection('groups').doc(widget.group.id).update({'members': FieldValue.arrayUnion([selectedUid])});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Участник добавлен')));
  }

  Future<void> _addMemberByPhone(BuildContext context) async {
    final phoneCtrl = TextEditingController();
    final phone = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Добавить по номеру', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      content: TextField(controller: phoneCtrl, style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(hintText: 'Номер телефона', hintStyle: TextStyle(color: AppColors.textHint)), keyboardType: TextInputType.phone),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: AppColors.textHint))),
        TextButton(onPressed: () => Navigator.pop(ctx, phoneCtrl.text.trim()), child: const Text('Добавить', style: TextStyle(color: AppColors.accent))),
      ],
    ));
    if (phone == null || phone.isEmpty) return;
    final snap = await _db.collection('users').where('phoneNumber', isEqualTo: phone).limit(1).get();
    if (snap.docs.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пользователь не найден'))); return; }
    final userId = snap.docs.first.id;
    await _db.collection('groups').doc(widget.group.id).update({'members': FieldValue.arrayUnion([userId])});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Участник добавлен')));
  }

  Future<void> _leaveGroup() async {
    await _db.collection('groups').doc(widget.group.id).update({'members': FieldValue.arrayRemove([_myUid])});
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteGroup() async {
    final msgs = await _db.collection('groups').doc(widget.group.id).collection('messages').get();
    final batch = _db.batch();
    for (final doc in msgs.docs) batch.delete(doc.reference);
    await batch.commit();
    await _db.collection('groups').doc(widget.group.id).delete();
    if (mounted) Navigator.pop(context);
  }

  Widget _buildStickerGrid() {
    final packs = StickerPack.builtInPacks;
    return DefaultTabController(length: packs.length, child: Column(children: [
      TabBar(isScrollable: true, labelColor: AppColors.accent, unselectedLabelColor: AppColors.textHint, indicatorColor: AppColors.accent,
        tabs: packs.map((p) => Tab(text: '${p.stickers.isNotEmpty ? p.stickers.first.emoji : "📦"} ${p.name}')).toList()),
      Expanded(child: TabBarView(children: packs.map((pack) => GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 4, crossAxisSpacing: 4),
        itemCount: pack.stickers.length,
        itemBuilder: (_, i) => GestureDetector(onTap: () => _sendSticker(pack.stickers[i].emoji),
          child: Center(child: Text(pack.stickers[i].emoji, style: const TextStyle(fontSize: 28)))),
      )).toList())),
    ]));
  }
}

// ─── Group Message Bubble — unified style ────────────────

class _GroupMessageBubble extends StatefulWidget {
  const _GroupMessageBubble({required this.data, required this.docId, required this.isMe, required this.onLongPress, required this.onDoubleTap, required this.onReply});
  final Map<String, dynamic> data;
  final String docId;
  final bool isMe;
  final VoidCallback onLongPress;
  final VoidCallback onDoubleTap;
  final VoidCallback onReply;

  @override
  State<_GroupMessageBubble> createState() => _GroupMessageBubbleState();
}

class _GroupMessageBubbleState extends State<_GroupMessageBubble> {
  bool _isPlayingVoice = false;
  Timer? _voiceTimer;
  int _voiceProgress = 0;
  AudioPlayer? _voicePlayer;

  @override
  void dispose() { _voiceTimer?.cancel(); _voicePlayer?.dispose(); super.dispose(); }

  void _toggleVoicePlay() async {
    if (_isPlayingVoice) {
      _voiceTimer?.cancel(); _voicePlayer?.stop();
      setState(() { _isPlayingVoice = false; _voiceProgress = 0; });
    } else {
      final totalSec = widget.data['mediaSize'] as int? ?? 5;
      final audioData = widget.data['mediaUrl'] as String?;
      if (audioData == null || audioData.isEmpty) return;
      try {
        _voicePlayer?.dispose(); _voicePlayer = AudioPlayer();
        final bytes = base64Decode(audioData);
        final dir = await getTemporaryDirectory();
        final tmpFile = File('${dir.path}/vizo_grp_play_${widget.docId}.m4a');
        await tmpFile.writeAsBytes(bytes);
        await _voicePlayer!.play(DeviceFileSource(tmpFile.path));
        setState(() { _isPlayingVoice = true; _voiceProgress = 0; });
        _voiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) { timer.cancel(); return; }
          setState(() => _voiceProgress++);
          if (_voiceProgress >= totalSec) { timer.cancel(); setState(() { _isPlayingVoice = false; _voiceProgress = 0; }); }
        });
        _voicePlayer!.onPlayerComplete.listen((_) { if (mounted) { _voiceTimer?.cancel(); setState(() { _isPlayingVoice = false; _voiceProgress = 0; }); } });
      } catch (e) { debugPrint('Voice play error: $e'); setState(() { _isPlayingVoice = false; _voiceProgress = 0; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isMe = widget.isMe;
    final senderName = data['senderName'] as String? ?? '';
    final text = data['text'] as String? ?? '';
    final mediaUrl = data['mediaUrl'] as String?;
    final mediaType = data['mediaType'] as String?;
    final isDeleted = data['isDeleted'] as bool? ?? false;
    final isEdited = data['isEdited'] as bool? ?? false;
    final replyToText = data['replyToText'] as String?;
    final replyToSender = data['replyToSender'] as String?;
    final ts = (data['createdAt'] as Timestamp?)?.toDate();
    final timeStr = ts != null ? '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}' : '';

    final reactionsRaw = data['reactions'] as Map?;
    final reactions = <String, List<String>>{};
    if (reactionsRaw != null) { for (final e in reactionsRaw.entries) reactions[e.key.toString()] = List<String>.from(e.value as List? ?? []); }
    final hasReactions = reactions.isNotEmpty;

    return GestureDetector(
      onLongPress: widget.onLongPress, onDoubleTap: widget.onDoubleTap,
      child: Dismissible(
        key: Key('swipe_grp_${widget.docId}'), direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async { widget.onReply(); return false; },
        background: Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.reply_rounded, color: AppColors.accent.withValues(alpha: 0.6), size: 24))),
        child: Padding(
          padding: EdgeInsets.only(bottom: hasReactions ? 22 : 6),
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(colors: [AppColors.accent.withValues(alpha: 0.25), AppColors.accent.withValues(alpha: 0.15)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : LinearGradient(colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.04)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16)),
                  border: Border.all(color: isMe ? AppColors.accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!isMe) Padding(padding: const EdgeInsets.only(bottom: 4),
                    child: Text(senderName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentLight.withValues(alpha: 0.9)))),
                  if (replyToText != null) ...[
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8),
                        border: Border(left: BorderSide(color: AppColors.accentLight.withValues(alpha: 0.6), width: 2))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (replyToSender != null) Text(replyToSender, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentLight.withValues(alpha: 0.8))),
                        Text(replyToText, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.6))),
                      ])),
                  ],
                  if (isDeleted) Text('Сообщение удалено', style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textHint.withValues(alpha: 0.5)))
                  else ...[
                    if (mediaType == 'sticker') Center(child: Text(text, style: const TextStyle(fontSize: 48)))
                    else if (mediaType == 'image' && mediaUrl != null) ...[
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: _buildImage(mediaUrl)),
                      const SizedBox(height: 4),
                    ] else if (mediaType == 'voice') ...[
                      GestureDetector(onTap: _toggleVoicePlay, child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle,
                            color: isMe ? Colors.white.withValues(alpha: 0.15) : AppColors.accent.withValues(alpha: 0.15)),
                            child: Icon(_isPlayingVoice ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 22,
                              color: isMe ? Colors.white : AppColors.accent)),
                          const SizedBox(width: 10),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Row(mainAxisSize: MainAxisSize.min, children: List.generate(16, (j) {
                              final totalSec = data['mediaSize'] as int? ?? 5;
                              final filled = totalSec > 0 ? (_voiceProgress / totalSec * 16).floor() : 0;
                              return Container(width: 3, height: 6.0 + (j % 4) * 4, margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(color: j < filled ? AppColors.accent : Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)));
                            })),
                            const SizedBox(height: 4),
                            Text(data['mediaName'] as String? ?? 'Голосовое', style: TextStyle(fontSize: 11, color: AppColors.textHint.withValues(alpha: 0.5))),
                          ]),
                        ]),
                      )),
                    ] else if (mediaType == 'file' && mediaUrl != null) ...[
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.insert_drive_file_rounded, size: 28, color: AppColors.accent.withValues(alpha: 0.8)),
                          const SizedBox(width: 10),
                          Flexible(child: Text(data['mediaName'] as String? ?? text, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isMe ? Colors.white : AppColors.textPrimary))),
                        ])),
                    ] else if (text.isNotEmpty && !text.startsWith('📷'))
                      Text(text, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  ],
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(timeStr, style: TextStyle(fontSize: 10, color: AppColors.textHint.withValues(alpha: 0.5))),
                    if (isEdited) ...[const SizedBox(width: 4), Text('ред.', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.textHint.withValues(alpha: 0.4)))],
                  ]),
                ]),
              ),
              if (reactions.isNotEmpty)
                Positioned(bottom: -14, right: isMe ? 8 : null, left: isMe ? null : 8,
                  child: Row(mainAxisSize: MainAxisSize.min, children: reactions.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(entry.key, style: const TextStyle(fontSize: 14)),
                        if (entry.value.length > 1) ...[const SizedBox(width: 3),
                          Text('${entry.value.length}', style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w600))],
                      ])),
                  )).toList())),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String url) {
    if (url.startsWith('data:')) {
      try { final commaIdx = url.indexOf(','); if (commaIdx > 0) { final bytes = base64Decode(url.substring(commaIdx + 1));
        return Image.memory(bytes, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imagePlaceholder()); } } catch (_) {}
    }
    if (url.startsWith('/') || url.startsWith('file:')) { final file = File(url.replaceFirst('file://', '')); if (file.existsSync()) return Image.file(file, width: double.infinity, fit: BoxFit.cover); }
    if (url.startsWith('http')) return Image.network(url, width: double.infinity, fit: BoxFit.cover);
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() => Container(height: 120, color: Colors.white.withValues(alpha: 0.05),
    child: const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.textHint, size: 32)));
}

// ─── Settings Item ───────────────────────

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({required this.icon, required this.label, required this.onTap, this.color});
  final IconData icon; final String label; final VoidCallback onTap; final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(leading: Icon(icon, color: c, size: 22), title: Text(label, style: TextStyle(color: c, fontSize: 14)), onTap: onTap);
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.color});
  final IconData icon; final String label; final VoidCallback onTap; final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(leading: Icon(icon, color: c, size: 22), title: Text(label, style: TextStyle(color: c, fontSize: 14)), onTap: onTap, dense: true);
  }
}
