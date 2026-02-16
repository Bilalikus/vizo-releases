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
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/constants/constants.dart';
import '../../models/channel_model.dart';
import '../../providers/providers.dart';

/// Channel chat — unified design matching personal & group chat.
class ChannelChatScreen extends ConsumerStatefulWidget {
  const ChannelChatScreen({super.key, required this.channel});
  final ChannelModel channel;

  @override
  ConsumerState<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends ConsumerState<ChannelChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _db = FirebaseFirestore.instance;
  late final String _myUid;
  late ChannelModel _channel;
  bool _hasText = false;

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
    _channel = widget.channel;
    _msgCtrl.addListener(() {
      final has = _msgCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  bool get _canWrite => _channel.canWrite(_myUid);

  // ─── Send text message ─────────────────
  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || !_canWrite) return;

    final currentUser = ref.read(currentUserProvider);
    final senderName = currentUser.displayName.isNotEmpty
        ? currentUser.displayName
        : currentUser.phoneNumber;

    _msgCtrl.clear();

    await _db.collection('channels').doc(_channel.id).set({
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db
        .collection('channels')
        .doc(_channel.id)
        .collection('messages')
        .add({
      'channelId': _channel.id,
      'senderId': _myUid,
      'senderName': senderName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    });
  }

  // ─── Send image ────────────────────────
  Future<void> _sendImage() async {
    if (!_canWrite) return;
    final picker = ImagePicker();
    final img = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 70);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (bytes.length > 700000) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Изображение слишком большое')),
        );
      }
      return;
    }
    final b64 = base64Encode(bytes);

    final currentUser = ref.read(currentUserProvider);
    final senderName = currentUser.displayName.isNotEmpty
        ? currentUser.displayName
        : currentUser.phoneNumber;

    await _db.collection('channels').doc(_channel.id).set({
      'lastMessage': '📷 Фото',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db
        .collection('channels')
        .doc(_channel.id)
        .collection('messages')
        .add({
      'channelId': _channel.id,
      'senderId': _myUid,
      'senderName': senderName,
      'text': '📷 Фото',
      'mediaUrl': b64,
      'mediaType': 'image',
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    });
  }

  // ─── Voice recording ───────────────────
  Future<void> _startRecording() async {
    if (!_canWrite) return;
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) return;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/channel_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordSeconds++);
      if (_recordSeconds >= 60) _stopRecording(send: true);
    });
  }

  Future<void> _stopRecording({bool send = false}) async {
    _recordTimer?.cancel();
    _recordTimer = null;

    final path = await _audioRecorder.stop();
    final wasSending = send || _recordingLocked;

    setState(() {
      _isRecording = false;
      _recordingLocked = false;
      _recordSeconds = 0;
    });

    if (!wasSending || path == null) return;

    final file = File(path);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    if (bytes.length > 700000) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Голосовое сообщение слишком длинное')),
        );
      }
      return;
    }
    final b64 = base64Encode(bytes);

    final currentUser = ref.read(currentUserProvider);
    final senderName = currentUser.displayName.isNotEmpty
        ? currentUser.displayName
        : currentUser.phoneNumber;

    await _db.collection('channels').doc(_channel.id).set({
      'lastMessage': '🎙 Голосовое',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db
        .collection('channels')
        .doc(_channel.id)
        .collection('messages')
        .add({
      'channelId': _channel.id,
      'senderId': _myUid,
      'senderName': senderName,
      'text': '🎙 Голосовое',
      'voiceBase64': b64,
      'voiceDuration': _recordSeconds,
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    });
  }

  // ─── Channel settings / edit ───────────
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ChannelSettingsSheet(
        channel: _channel,
        myUid: _myUid,
        db: _db,
        onUpdated: (updated) {
          setState(() => _channel = updated);
        },
        onLeft: () => Navigator.pop(context),
      ),
    );
  }

  // ─── Delete message ────────────────────
  Future<void> _deleteMessage(String docId) async {
    await _db
        .collection('channels')
        .doc(_channel.id)
        .collection('messages')
        .doc(docId)
        .update({'isDeleted': true});
  }

  // ─── Show message actions ──────────────
  void _showMessageActions(Map<String, dynamic> data, String docId) {
    final isMine = data['senderId'] == _myUid;
    final text = data['text'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).padding.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick reactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️', '👍', '😂', '😮', '😢', '🔥', '👏', '🎉']
                  .map((e) => GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _toggleReaction(docId, e);
                        },
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            if (text.isNotEmpty)
              ListTile(
                leading:
                    const Icon(Icons.copy_rounded, color: AppColors.textHint),
                title: const Text('Копировать',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Скопировано')),
                  );
                },
              ),
            if (isMine || _channel.creatorUid == _myUid)
              ListTile(
                leading: Icon(Icons.delete_rounded, color: AppColors.error),
                title:
                    Text('Удалить', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(docId);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ─── Toggle reaction ───────────────────
  Future<void> _toggleReaction(String docId, String emoji) async {
    final ref = _db
        .collection('channels')
        .doc(_channel.id)
        .collection('messages')
        .doc(docId);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
    final users = List<String>.from(reactions[emoji] ?? []);

    if (users.contains(_myUid)) {
      users.remove(_myUid);
    } else {
      users.add(_myUid);
    }

    if (users.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = users;
    }

    await ref.update({'reactions': reactions});
  }

  // ─── Format duration ──────────────────
  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Column(
        children: [
          // ─── App Bar ───────────────────
          _buildAppBar(),

          Container(
              height: 0.5, color: Colors.white.withValues(alpha: 0.06)),

          // ─── Messages ──────────────────
          Expanded(child: _buildMessages()),

          // ─── Recording indicator ───────
          if (_isRecording && _recordingLocked) _buildRecordingBar(),

          // ─── Input Bar ─────────────────
          _buildInputBar(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // App bar
  // ═══════════════════════════════════════════════════
  Widget _buildAppBar() {
    final hasAvatar =
        _channel.avatarBase64 != null && _channel.avatarBase64!.isNotEmpty;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary, size: 20),
              ),
            ),
            // Channel avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasAvatar
                  ? Image.memory(
                      base64Decode(_channel.avatarBase64!),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.accent.withValues(alpha: 0.3),
                            Colors.deepPurple.withValues(alpha: 0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.campaign_rounded,
                          color: AppColors.accent, size: 22),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_channel.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('${_channel.subscribers.length} подписчиков',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textHint)),
                ],
              ),
            ),
            if (_channel.creatorUid == _myUid)
              GestureDetector(
                onTap: _showSettings,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: AppColors.accent, size: 18),
                ),
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showSettings,
              child: const Icon(Icons.more_vert_rounded,
                  color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // Messages list
  // ═══════════════════════════════════════════════════
  Widget _buildMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('channels')
          .doc(_channel.id)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2));
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.campaign_rounded,
                    size: 56,
                    color: AppColors.accent.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                const Text('Нет сообщений',
                    style: TextStyle(color: AppColors.textHint)),
              ],
            ),
          );
        }
        return ListView.builder(
          controller: _scrollCtrl,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _ChannelMessageBubble(
              data: data,
              docId: doc.id,
              isMine: data['senderId'] == _myUid,
              onLongPress: () => _showMessageActions(data, doc.id),
              onReaction: (emoji) => _toggleReaction(doc.id, emoji),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════
  // Recording indicator bar
  // ═══════════════════════════════════════════════════
  Widget _buildRecordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        border: Border(
            top: BorderSide(color: AppColors.error.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
                color: AppColors.error, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(_fmt(_recordSeconds),
              style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 15)),
          const Spacer(),
          GestureDetector(
            onTap: () => _stopRecording(send: false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Отмена',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _stopRecording(send: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Отправить',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // Input bar
  // ═══════════════════════════════════════════════════
  Widget _buildInputBar() {
    if (!_canWrite) {
      return Container(
        padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: const Center(
          child: Text('Только авторы могут писать',
              style: TextStyle(color: AppColors.textHint, fontSize: 13)),
        ),
      );
    }

    if (_isRecording && !_recordingLocked) {
      return Container(
        padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  color: AppColors.error, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(_fmt(_recordSeconds),
                style: const TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
            const Spacer(),
            const Text('← Свайп для отмены',
                style: TextStyle(color: AppColors.textHint, fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 8,
          bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _sendImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.image_rounded,
                  color: AppColors.textHint, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 15),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Написать в канал...',
                hintStyle: TextStyle(
                    color: AppColors.textHint.withValues(alpha: 0.5)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_hasText)
            GestureDetector(
              onTap: _send,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            )
          else
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) {
                if (_isRecording && !_recordingLocked) {
                  _stopRecording(send: true);
                }
              },
              onTap: () => _startRecording().then((_) {
                setState(() => _recordingLocked = true);
              }),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.mic_rounded,
                    color: AppColors.accent, size: 22),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Channel message bubble — unified design
// ═══════════════════════════════════════════════════════
class _ChannelMessageBubble extends StatefulWidget {
  const _ChannelMessageBubble({
    required this.data,
    required this.docId,
    required this.isMine,
    required this.onLongPress,
    required this.onReaction,
  });

  final Map<String, dynamic> data;
  final String docId;
  final bool isMine;
  final VoidCallback onLongPress;
  final void Function(String emoji) onReaction;

  @override
  State<_ChannelMessageBubble> createState() => _ChannelMessageBubbleState();
}

class _ChannelMessageBubbleState extends State<_ChannelMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleVoicePlay(String b64) async {
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
      return;
    }

    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/ch_voice_${widget.docId.hashCode}.m4a');
    if (!await file.exists()) {
      await file.writeAsBytes(base64Decode(b64));
    }

    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    await _player.play(DeviceFileSource(file.path));
    setState(() => _isPlaying = true);
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final text = data['text'] as String? ?? '';
    final sender = data['senderName'] as String? ?? '';
    final isDeleted = data['isDeleted'] as bool? ?? false;
    final mediaUrl = data['mediaUrl'] as String?;
    final mediaType = data['mediaType'] as String?;
    final voiceB64 = data['voiceBase64'] as String?;
    final voiceDur = data['voiceDuration'] as int? ?? 0;
    final ts = (data['createdAt'] as Timestamp?)?.toDate();
    final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
    final isMine = widget.isMine;

    if (isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Center(
            child: Text('Удалено',
                style: TextStyle(
                    color: AppColors.textHint.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontStyle: FontStyle.italic))),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: widget.onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMine
                        ? LinearGradient(
                            colors: [
                              AppColors.accent.withValues(alpha: 0.25),
                              AppColors.accent.withValues(alpha: 0.12),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.08),
                              Colors.white.withValues(alpha: 0.04),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isMine
                          ? AppColors.accent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sender name
                      if (!isMine)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(sender,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accent)),
                        ),

                      // Image
                      if (mediaType == 'image' && mediaUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(base64Decode(mediaUrl),
                              width: 220, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Voice
                      if (voiceB64 != null) ...[
                        _buildVoiceBubble(voiceB64, voiceDur),
                      ] else if (mediaType != 'image') ...[
                        // Text
                        Text(text,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14.5)),
                      ],

                      // Time
                      if (ts != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                                '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textHint
                                        .withValues(alpha: 0.5))),
                          ),
                        ),
                    ],
                  ),
                ),

                // Reactions
                if (reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      spacing: 4,
                      children: reactions.entries.map((e) {
                        final users = List<String>.from(e.value);
                        return GestureDetector(
                          onTap: () => widget.onReaction(e.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('${e.key} ${users.length}',
                                style: const TextStyle(fontSize: 13)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceBubble(String b64, int dur) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _toggleVoicePlay(b64),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AppColors.accent,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Waveform bars
        SizedBox(
          width: 120,
          height: 28,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(16, (i) {
              final fraction = i / 16;
              final active = fraction < progress;
              final h =
                  8.0 + (i % 3 == 0 ? 12 : (i % 2 == 0 ? 8 : 4));
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  height: h,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.accent
                        : AppColors.textHint.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _isPlaying ? _fmt(_position.inSeconds) : _fmt(dur),
          style: const TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// Channel Settings Bottom Sheet
// ═══════════════════════════════════════════════════════
class _ChannelSettingsSheet extends StatefulWidget {
  const _ChannelSettingsSheet({
    required this.channel,
    required this.myUid,
    required this.db,
    required this.onUpdated,
    required this.onLeft,
  });

  final ChannelModel channel;
  final String myUid;
  final FirebaseFirestore db;
  final void Function(ChannelModel) onUpdated;
  final VoidCallback onLeft;

  @override
  State<_ChannelSettingsSheet> createState() => _ChannelSettingsSheetState();
}

class _ChannelSettingsSheetState extends State<_ChannelSettingsSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  String? _newAvatarBase64;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.channel.name);
    _descCtrl = TextEditingController(text: widget.channel.description);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _isCreator => widget.channel.creatorUid == widget.myUid;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 60);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() => _newAvatarBase64 = base64Encode(bytes));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updates = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (_newAvatarBase64 != null) {
      updates['avatarBase64'] = _newAvatarBase64;
    }
    await widget.db
        .collection('channels')
        .doc(widget.channel.id)
        .update(updates);

    // Rebuild local model
    final updated = widget.channel.copyWith(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      avatarBase64: _newAvatarBase64 ?? widget.channel.avatarBase64,
    );
    widget.onUpdated(updated);

    if (mounted) Navigator.pop(context);
  }

  Future<void> _addWriter() async {
    Navigator.pop(context);
    final ctrl = TextEditingController();
    final uid = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        title: const Text('UID автора',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
            controller: ctrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
                hintText: 'Введите UID пользователя',
                hintStyle: TextStyle(color: AppColors.textHint))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена',
                  style: TextStyle(color: AppColors.textHint))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Добавить',
                  style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (uid != null && uid.isNotEmpty) {
      await widget.db
          .collection('channels')
          .doc(widget.channel.id)
          .update({
        'writers': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> _unsubscribe() async {
    Navigator.pop(context);
    await widget.db
        .collection('channels')
        .doc(widget.channel.id)
        .update({
      'subscribers': FieldValue.arrayRemove([widget.myUid]),
    });
    widget.onLeft();
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = _newAvatarBase64 != null ||
        (widget.channel.avatarBase64 != null &&
            widget.channel.avatarBase64!.isNotEmpty);
    final avatarBytes = _newAvatarBase64 != null
        ? base64Decode(_newAvatarBase64!)
        : (widget.channel.avatarBase64 != null
            ? base64Decode(widget.channel.avatarBase64!)
            : null);

    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Avatar
            GestureDetector(
              onTap: _isCreator ? _pickAvatar : null,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: hasAvatar && avatarBytes != null
                        ? Image.memory(avatarBytes,
                            width: 80, height: 80, fit: BoxFit.cover)
                        : Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accent.withValues(alpha: 0.3),
                                  Colors.deepPurple.withValues(alpha: 0.2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.campaign_rounded,
                                color: AppColors.accent, size: 40),
                          ),
                  ),
                  if (_isCreator)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.surfaceLight, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_isCreator) ...[
              // Name field
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Название канала',
                  hintStyle: TextStyle(
                      color: AppColors.textHint.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                ),
              ),
              TextField(
                controller: _descCtrl,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Описание канала',
                  hintStyle: TextStyle(
                      color: AppColors.textHint.withValues(alpha: 0.5)),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 12),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Сохранить',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white12),
            ] else ...[
              Text(widget.channel.name,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              if (widget.channel.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(widget.channel.description,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center),
                ),
              const SizedBox(height: 4),
              Text('${widget.channel.subscribers.length} подписчиков',
                  style: const TextStyle(
                      color: AppColors.textHint, fontSize: 13)),
              const SizedBox(height: 12),
              const Divider(color: Colors.white12),
            ],

            if (_isCreator) ...[
              ListTile(
                leading: const Icon(Icons.person_add_rounded,
                    color: AppColors.accent),
                title: const Text('Добавить автора',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: _addWriter,
              ),
            ],
            ListTile(
              leading:
                  Icon(Icons.exit_to_app_rounded, color: AppColors.error),
              title: Text('Отписаться',
                  style: TextStyle(color: AppColors.error)),
              onTap: _unsubscribe,
            ),
          ],
        ),
      ),
    );
  }
}
