import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/constants.dart';
import '../../models/message_model.dart';
import '../../models/sticker_model.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../call/call_screen.dart';
import 'chat_info_screen.dart';
import 'media_viewer_screen.dart';

/// Chat screen between two users.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerAvatarUrl,
  });

  final String peerId;
  final String peerName;
  final String? peerAvatarUrl;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _db = FirebaseFirestore.instance;

  late final String _chatId;
  late final String _myUid;

  // ─── Reply / Edit state ─────────────────
  MessageModel? _replyTo;
  MessageModel? _editingMsg;
  Timer? _typingTimer;
  bool _amTyping = false;
  final _showScrollFab = ValueNotifier<bool>(false);

  // ─── Multi-select state ────────────────
  bool _multiSelectMode = false;
  final Set<String> _selectedIds = {};

  // ─── Wallpaper ─────────────────────────
  int _wallpaperIndex = -1;

  // ─── Read tracking ──
  int _lastDocCount = 0;

  // ─── Sticker picker state ──────────────
  bool _showStickerPicker = false;

  // ─── Chat search state ────────────────
  bool _showChatSearch = false;
  String _chatSearchQuery = '';
  final _chatSearchCtrl = TextEditingController();

  // ─── Voice recording state ─────────────
  bool _isRecording = false;
  Timer? _recordTimer;
  int _recordSeconds = 0;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _hasText = false;

  // ─── Pending attachment state ──────────
  File? _pendingFile;
  String? _pendingFileName;
  String? _pendingMediaType; // 'image', 'video', 'file'

  // ─── Message key map for scroll-to-message ───
  final Map<String, GlobalKey> _messageKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _myUid = ref.read(authServiceProvider).effectiveUid;
    _chatId = _buildChatId(_myUid, widget.peerId);
    _markRead();
    _setOnline(true);
    _msgCtrl.addListener(_onTextChanged);
    _scrollCtrl.addListener(_onScroll);
    _loadWallpaper();
  }

  Future<void> _loadWallpaper() async {
    final p = await SharedPreferences.getInstance();
    final idx = p.getInt('pref_wallpaper') ?? -1;
    if (mounted) setState(() => _wallpaperIndex = idx);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    // reverse: true — pixels > 0 means user scrolled UP from bottom
    final show = _scrollCtrl.position.pixels > 300;
    if (show != _showScrollFab.value) _showScrollFab.value = show;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgCtrl.removeListener(_onTextChanged);
    _scrollCtrl.removeListener(_onScroll);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _showScrollFab.dispose();
    _chatSearchCtrl.dispose();
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _setTyping(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _setOnline(state == AppLifecycleState.resumed);
  }

  // ─── Helpers ────────────────────────────

  String _buildChatId(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> _setOnline(bool online) async {
    try {
      await _db.collection('users').doc(_myUid).update({
        'isOnline': online,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _onTextChanged() {
    final hasText = _msgCtrl.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    if (hasText && !_amTyping) {
      _setTyping(true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _setTyping(false);
    });
  }

  Future<void> _setTyping(bool typing) async {
    if (_amTyping == typing) return;
    _amTyping = typing;
    try {
      await _db.collection('chats').doc(_chatId).set({
        'typing_$_myUid': typing,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _markRead() async {
    final unread = await _db
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: _myUid)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ─── Send / Edit ────────────────────────

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    // Editing existing message
    if (_editingMsg != null) {
      await _db
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc(_editingMsg!.id)
          .update({'text': text, 'isEdited': true});
      _cancelEdit();
      return;
    }

    _msgCtrl.clear();
    _setTyping(false);

    final currentUser = ref.read(currentUserProvider);
    final senderName = currentUser.displayName.isNotEmpty
        ? currentUser.displayName
        : currentUser.phoneNumber;

    await _db.collection('chats').doc(_chatId).set({
      'participants': [_myUid, widget.peerId],
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final msgData = <String, dynamic>{
      'chatId': _chatId,
      'senderId': _myUid,
      'senderName': senderName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'isEdited': false,
      'isDeleted': false,
    };

    if (_replyTo != null) {
      msgData['replyToId'] = _replyTo!.id;
      msgData['replyToText'] = _replyTo!.text;
      msgData['replyToSender'] = _replyTo!.senderName;
    }

    await _db
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .add(msgData);

    _cancelReply();
  }

  // ─── Send Sticker ──────────────────────

  Future<void> _sendSticker(String emoji) async {
    final currentUser = ref.read(currentUserProvider);
    final senderName = currentUser.displayName.isNotEmpty
        ? currentUser.displayName
        : currentUser.phoneNumber;

    await _db.collection('chats').doc(_chatId).set({
      'participants': [_myUid, widget.peerId],
      'lastMessage': emoji,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .add({
      'chatId': _chatId,
      'senderId': _myUid,
      'senderName': senderName,
      'text': emoji,
      'mediaType': 'sticker',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'isEdited': false,
      'isDeleted': false,
    });

    setState(() => _showStickerPicker = false);
  }

  // ─── Attach File ──────────────────────

  Future<void> _attachFile() async {
    // Show bottom sheet with options: photo, video, file
    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                _ActionTile(
                  icon: Icons.photo_rounded,
                  label: 'Фото из галереи',
                  onTap: () => Navigator.pop(context, 'photo'),
                ),
                _ActionTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Сделать фото',
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                _ActionTile(
                  icon: Icons.videocam_rounded,
                  label: 'Видео',
                  onTap: () => Navigator.pop(context, 'video'),
                ),
                _ActionTile(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'Файл',
                  onTap: () => Navigator.pop(context, 'file'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
    if (choice == null) return;

    try {
      switch (choice) {
        case 'photo':
          final picked = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            imageQuality: 80,
          );
          if (picked == null) return;
          setState(() {
            _pendingFile = File(picked.path);
            _pendingFileName = picked.name;
            _pendingMediaType = 'image';
          });
          break;
        case 'camera':
          final picked = await ImagePicker().pickImage(
            source: ImageSource.camera,
            imageQuality: 80,
          );
          if (picked == null) return;
          setState(() {
            _pendingFile = File(picked.path);
            _pendingFileName = picked.name;
            _pendingMediaType = 'image';
          });
          break;
        case 'video':
          final picked = await ImagePicker().pickVideo(
            source: ImageSource.gallery,
          );
          if (picked == null) return;
          setState(() {
            _pendingFile = File(picked.path);
            _pendingFileName = picked.name;
            _pendingMediaType = 'video';
          });
          break;
        case 'file':
          final result = await FilePicker.platform.pickFiles(
            allowMultiple: false,
            withData: false,
            withReadStream: false,
          );
          if (result == null || result.files.isEmpty) return;
          final f = result.files.first;
          setState(() {
            _pendingFile = f.path != null ? File(f.path!) : null;
            _pendingFileName = f.name;
            _pendingMediaType = 'file';
          });
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  void _cancelPendingFile() {
    setState(() {
      _pendingFile = null;
      _pendingFileName = null;
      _pendingMediaType = null;
    });
  }

  Future<void> _sendPendingFile() async {
    if (_pendingFile == null && _pendingFileName == null) return;

    final caption = _msgCtrl.text.trim();
    final mediaType = _pendingMediaType ?? 'file';
    final fileName = _pendingFileName ?? 'file';
    final file = _pendingFile;
    final fileSize = file != null ? await file.length() : 0;

    // Convert media to base64 data URI so the other user can see it
    // (no Firebase Storage on Spark plan — store in Firestore directly)
    String? mediaUrl;
    if (file != null) {
      final bytes = await file.readAsBytes();
      if (mediaType == 'image') {
        // Images: compress + encode as base64 data URI
        final ext = file.path.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        final b64 = base64Encode(bytes);
        mediaUrl = 'data:$mime;base64,$b64';
      } else if (mediaType == 'video') {
        // Videos are too large for Firestore — store local path as fallback
        // and indicate it's local-only
        mediaUrl = file.path;
      } else {
        // Generic files — if small enough (<800KB), encode as base64
        if (bytes.length < 800 * 1024) {
          final b64 = base64Encode(bytes);
          mediaUrl = 'data:application/octet-stream;base64,$b64';
        } else {
          mediaUrl = file.path;
        }
      }
    }

    final currentUser = ref.read(currentUserProvider);
    final senderName = currentUser.displayName.isNotEmpty
        ? currentUser.displayName
        : currentUser.phoneNumber;

    // Format size
    String sizeStr;
    if (fileSize < 1024) {
      sizeStr = '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      sizeStr = '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      sizeStr = '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    final icon = mediaType == 'image'
        ? '📷'
        : mediaType == 'video'
            ? '🎬'
            : '📎';
    final lastMsg = caption.isNotEmpty ? '$icon $caption' : '$icon $fileName';

    await _db.collection('chats').doc(_chatId).set({
      'participants': [_myUid, widget.peerId],
      'lastMessage': lastMsg,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final msgData = <String, dynamic>{
      'chatId': _chatId,
      'senderId': _myUid,
      'senderName': senderName,
      'text': caption.isNotEmpty ? caption : '$icon $fileName ($sizeStr)',
      'mediaType': mediaType,
      'mediaName': fileName,
      'mediaSize': fileSize,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'isEdited': false,
      'isDeleted': false,
    };

    if (mediaUrl != null) {
      msgData['mediaUrl'] = mediaUrl;
    }

    await _db
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .add(msgData);

    _msgCtrl.clear();
    setState(() {
      _pendingFile = null;
      _pendingFileName = null;
      _pendingMediaType = null;
      _hasText = false;
    });
  }

  // ─── Voice recording ──────────────────

  bool _recordingLocked = false; // true = locked recording mode (user lifted finger after lock)

  void _startRecording() async {
    if (_isRecording) return; // prevent double-start
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/vizo_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            setState(() => _recordSeconds++);
            // Auto-stop at 60 seconds to stay within Firestore 1MB limit
            if (_recordSeconds >= 60) {
              _stopRecording(send: true);
            }
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет доступа к микрофону')),
          );
        }
      }
    } catch (e) {
      debugPrint('Recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка записи: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    _recordTimer?.cancel();
    _recordTimer = null;

    if (!_isRecording) return;
    final duration = _recordSeconds;
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
      _recordingLocked = false;
    });

    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }

    if (!send || duration < 1 || path == null) return;

    // Read recorded file and encode to base64
    try {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('Voice file does not exist: $path');
        return;
      }
      final bytes = await file.readAsBytes();

      // Firestore doc limit is ~1MB. Base64 expands by ~33%. Skip if too large.
      if (bytes.length > 700000) {
        debugPrint('Voice file too large: ${bytes.length} bytes');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Голосовое слишком длинное. Макс ~60 сек.')),
          );
        }
        try { await file.delete(); } catch (_) {}
        return;
      }

      final base64Audio = base64Encode(bytes);

      final currentUser = ref.read(currentUserProvider);
      final senderName = currentUser.displayName.isNotEmpty
          ? currentUser.displayName
          : currentUser.phoneNumber;

      final durStr = '${(duration ~/ 60).toString().padLeft(2, '0')}:${(duration % 60).toString().padLeft(2, '0')}';

      await _db.collection('chats').doc(_chatId).set({
        'participants': [_myUid, widget.peerId],
        'lastMessage': '🎤 Голосовое ($durStr)',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _db
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add({
        'chatId': _chatId,
        'senderId': _myUid,
        'senderName': senderName,
        'text': '🎤 Голосовое сообщение ($durStr)',
        'mediaType': 'voice',
        'mediaUrl': base64Audio,
        'mediaName': 'voice_message.m4a',
        'mediaSize': duration,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'isEdited': false,
        'isDeleted': false,
      });

      // Clean up temp file
      try { await file.delete(); } catch (_) {}
    } catch (e) {
      debugPrint('Voice send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e')),
        );
      }
    }
  }

  void _cancelRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    final wasRecording = _isRecording;
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
      _recordingLocked = false;
    });
    if (wasRecording) {
      try {
        final path = await _audioRecorder.stop();
        // Delete the temp file
        if (path != null) {
          try { await File(path).delete(); } catch (_) {}
        }
      } catch (_) {}
    }
  }

  // ─── Voice Call / Video Call from chat ──

  void _startVoiceCall() {
    final authService = ref.read(authServiceProvider);
    final currentUser = ref.read(currentUserProvider);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callerId: authService.effectiveUid,
          callerName: currentUser.displayName.isNotEmpty
              ? currentUser.displayName
              : currentUser.phoneNumber,
          receiverId: widget.peerId,
          receiverName: widget.peerName,
          receiverAvatarUrl: widget.peerAvatarUrl,
          isVideoCall: false,
        ),
      ),
    );
  }

  void _startVideoCall() {
    final authService = ref.read(authServiceProvider);
    final currentUser = ref.read(currentUserProvider);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callerId: authService.effectiveUid,
          callerName: currentUser.displayName.isNotEmpty
              ? currentUser.displayName
              : currentUser.phoneNumber,
          receiverId: widget.peerId,
          receiverName: widget.peerName,
          receiverAvatarUrl: widget.peerAvatarUrl,
          isVideoCall: true,
        ),
      ),
    );
  }

  // ─── Toggle chat search ───────────────

  void _toggleChatSearch() {
    setState(() {
      _showChatSearch = !_showChatSearch;
      if (!_showChatSearch) {
        _chatSearchQuery = '';
        _chatSearchCtrl.clear();
      }
    });
  }

  // ─── Message actions ────────────────────

  void _startReply(MessageModel msg) {
    setState(() {
      _replyTo = msg;
      _editingMsg = null;
    });
  }

  void _cancelReply() {
    if (!mounted) return;
    setState(() => _replyTo = null);
  }

  void _startEdit(MessageModel msg) {
    setState(() {
      _editingMsg = msg;
      _replyTo = null;
      _msgCtrl.text = msg.text;
      _msgCtrl.selection =
          TextSelection.collapsed(offset: msg.text.length);
    });
  }

  void _cancelEdit() {
    if (!mounted) return;
    setState(() {
      _editingMsg = null;
      _msgCtrl.clear();
    });
  }

  Future<void> _deleteMessage(String msgId) async {
    await _db
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc(msgId)
        .update({'isDeleted': true, 'text': ''});
  }

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Текст скопирован'),
        backgroundColor: AppColors.accent.withValues(alpha: 0.9),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _toggleStar(MessageModel msg) async {
    await _db
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc(msg.id)
        .update({'isStarred': !msg.isStarred});
  }

  Future<void> _togglePin(MessageModel msg) async {
    await _db
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc(msg.id)
        .update({'isPinned': !(msg.isPinned)});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isPinned ? 'Откреплено' : 'Закреплено'),
          backgroundColor: AppColors.accent.withValues(alpha: 0.9),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ─── Multi-select ───────────────────────

  void _toggleMultiSelect(String msgId) {
    setState(() {
      if (_selectedIds.contains(msgId)) {
        _selectedIds.remove(msgId);
        if (_selectedIds.isEmpty) _multiSelectMode = false;
      } else {
        _selectedIds.add(msgId);
      }
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final batch = _db.batch();
    for (final id in _selectedIds) {
      batch.update(
        _db.collection('chats').doc(_chatId).collection('messages').doc(id),
        {'isDeleted': true, 'text': ''},
      );
    }
    await batch.commit();
    _exitMultiSelect();
  }

  // ─── Quick reply picker ─────────────────

  Future<void> _showQuickReplies() async {
    final uid = _myUid;
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('quick_replies')
        .get();
    if (snap.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Нет быстрых ответов — добавьте в настройках'),
            backgroundColor: AppColors.accent.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Быстрые ответы',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                ...snap.docs.map((d) {
                  final data = d.data();
                  return ListTile(
                    leading: Icon(Icons.flash_on_rounded,
                        color: AppColors.accent, size: 20),
                    title: Text(data['label'] ?? '',
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14)),
                    subtitle: Text(data['text'] ?? '',
                        style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                            fontSize: 12)),
                    onTap: () => Navigator.pop(context, data['text'] as String?),
                  );
                }),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ),
      ),
    );
    if (chosen != null && chosen.isNotEmpty) {
      _msgCtrl.text = chosen;
      _send();
    }
  }

  Future<void> _reactToMessage(MessageModel msg) async {
    final emojis = ['❤️', '👍', '😂', '😮', '😢', '🔥', '🎉', '👎'];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.5,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
                const Text('Реакция',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: emojis.map((e) {
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, e),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Center(
                            child: Text(e,
                                style: const TextStyle(fontSize: 24))),
                      ),
                    );
                  }).toList(),
                ),
                if (msg.reaction != null || msg.reactions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, '__remove__'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Убрать реакцию',
                          style: TextStyle(
                              color: AppColors.error, fontSize: 14)),
                    ),
                  ),
                ],
                SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ),
      ),
    );

    if (chosen == null || !mounted) return;

    // Multi-reaction: toggle current user in the reactions map
    final msgRef = _db.collection('chats').doc(_chatId).collection('messages').doc(msg.id);

    if (chosen == '__remove__') {
      // Remove all reactions by this user
      final snap = await msgRef.get();
      final data = snap.data() ?? {};
      final reactions = Map<String, dynamic>.from(data['reactions'] as Map? ?? {});
      bool changed = false;
      for (final key in reactions.keys.toList()) {
        final list = List<String>.from(reactions[key] as List? ?? []);
        if (list.remove(_myUid)) {
          changed = true;
          if (list.isEmpty) {
            reactions.remove(key);
          } else {
            reactions[key] = list;
          }
        }
      }
      if (changed) {
        await msgRef.update({'reactions': reactions});
      }
      // Also clear legacy reaction field
      await msgRef.update({'reaction': FieldValue.delete()});
    } else {
      // Toggle this emoji for current user
      final snap = await msgRef.get();
      final data = snap.data() ?? {};
      final reactions = Map<String, dynamic>.from(data['reactions'] as Map? ?? {});
      final list = List<String>.from(reactions[chosen] as List? ?? []);
      if (list.contains(_myUid)) {
        list.remove(_myUid);
        if (list.isEmpty) {
          reactions.remove(chosen);
        } else {
          reactions[chosen] = list;
        }
      } else {
        list.add(_myUid);
        reactions[chosen] = list;
      }
      await msgRef.update({'reactions': reactions, 'reaction': chosen});
    }
  }

  Future<void> _forwardMessage(MessageModel msg) async {
    final contacts = ref.read(contactsProvider);
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Нет контактов для пересылки'),
          backgroundColor: AppColors.accent.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final selectedUid = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ForwardContactPicker(contacts: contacts),
    );

    if (selectedUid == null || !mounted) return;

    final fwdChatId = _buildChatId(_myUid, selectedUid);
    final currentUser = ref.read(currentUserProvider);
    final senderName = currentUser.displayName.isNotEmpty
        ? currentUser.displayName
        : currentUser.phoneNumber;

    await _db.collection('chats').doc(fwdChatId).set({
      'participants': [_myUid, selectedUid],
      'lastMessage': msg.text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db
        .collection('chats')
        .doc(fwdChatId)
        .collection('messages')
        .add({
      'chatId': fwdChatId,
      'senderId': _myUid,
      'senderName': senderName,
      'text': msg.text,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'isEdited': false,
      'isDeleted': false,
      'forwardedFrom': msg.senderName,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Сообщение переслано'),
          backgroundColor: AppColors.accent.withValues(alpha: 0.9),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showActions(MessageModel msg) {
    final isMine = msg.senderId == _myUid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionTile(
                    icon: Icons.reply_rounded,
                    label: 'Ответить',
                    onTap: () {
                      Navigator.pop(context);
                      _startReply(msg);
                    },
                  ),
                  if (!msg.isDeleted)
                    _ActionTile(
                      icon: Icons.copy_rounded,
                      label: 'Копировать',
                      onTap: () {
                        Navigator.pop(context);
                        _copyText(msg.text);
                      },
                    ),
                  if (!msg.isDeleted)
                    _ActionTile(
                      icon: Icons.forward_rounded,
                      label: 'Переслать',
                      onTap: () {
                        Navigator.pop(context);
                        _forwardMessage(msg);
                      },
                    ),
                  if (!msg.isDeleted)
                    _ActionTile(
                      icon: msg.isStarred
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      label: msg.isStarred
                          ? 'Убрать из избранного'
                          : 'В избранное',
                      onTap: () {
                        Navigator.pop(context);
                        _toggleStar(msg);
                      },
                    ),
                  if (!msg.isDeleted)
                    _ActionTile(
                      icon: Icons.emoji_emotions_outlined,
                      label: 'Реакция',
                      onTap: () {
                        Navigator.pop(context);
                        _reactToMessage(msg);
                      },
                    ),
                  if (!msg.isDeleted)
                    _ActionTile(
                      icon: msg.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      label: msg.isPinned ? 'Открепить' : 'Закрепить',
                      onTap: () {
                        Navigator.pop(context);
                        _togglePin(msg);
                      },
                    ),
                  if (isMine && !msg.isDeleted)
                    _ActionTile(
                      icon: Icons.edit_rounded,
                      label: 'Редактировать',
                      onTap: () {
                        Navigator.pop(context);
                        _startEdit(msg);
                      },
                    ),
                  if (isMine && !msg.isDeleted)
                    _ActionTile(
                      icon: Icons.delete_outline_rounded,
                      label: 'Удалить',
                      color: AppColors.error,
                      onTap: () {
                        Navigator.pop(context);
                        _deleteMessage(msg.id);
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0, // reverse: true — 0 is the bottom (newest messages)
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  /// Scroll to a specific message by ID (used for pinned / reply-to taps).
  void _scrollToMessage(String messageId) {
    // The list uses ValueKey(msg.id) — find the context via GlobalKey approach
    // Since the ListView is reversed, we find the index of the message in the stream
    // and use Scrollable.ensureVisible on the target
    final ctx = _messageKeys[messageId]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    }
  }

  bool _differentDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  // ─── Build ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Wallpaper gradients
    const wallpapers = <List<Color>>[
      [Color(0xFF0D1B2A), Color(0xFF1B2838)],
      [Color(0xFF0B0E2D), Color(0xFF1A1040)],
      [Color(0xFF0A1628), Color(0xFF0D2137)],
      [Color(0xFF0A1A10), Color(0xFF122A18)],
      [Color(0xFF1A0A28), Color(0xFF2D1040)],
      [Color(0xFF2A0A0A), Color(0xFF401010)],
      [Color(0xFF0A2828), Color(0xFF104040)],
      [Color(0xFF1A1A0A), Color(0xFF2D2D10)],
      [Color(0xFF0D0D1A), Color(0xFF15152A)],
      [Color(0xFF1A0D1A), Color(0xFF2A152A)],
      [Color(0xFF0D1A1A), Color(0xFF152A2A)],
      [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
    ];

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: _multiSelectMode
          ? PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppColors.textPrimary),
                              onPressed: _exitMultiSelect,
                            ),
                            Text('${_selectedIds.length}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.error),
                              onPressed: _bulkDelete,
                              tooltip: 'Удалить выбранные',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            size: 20, color: AppColors.textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                      VAvatar(
                        imageUrl: widget.peerAvatarUrl,
                        name: widget.peerName,
                        radius: 18,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.peerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Online status
                            _PeerStatus(peerId: widget.peerId),
                          ],
                        ),
                      ),
                      // Voice call button
                      IconButton(
                        icon: const Icon(Icons.call_rounded,
                            size: 20, color: AppColors.textHint),
                        onPressed: _startVoiceCall,
                        tooltip: 'Голосовой звонок',
                      ),
                      // Video call button
                      IconButton(
                        icon: const Icon(Icons.videocam_rounded,
                            size: 20, color: AppColors.textHint),
                        onPressed: _startVideoCall,
                        tooltip: 'Видеозвонок',
                      ),
                      // Search in chat
                      IconButton(
                        icon: Icon(
                          _showChatSearch
                              ? Icons.search_off_rounded
                              : Icons.search_rounded,
                          size: 20,
                          color: _showChatSearch
                              ? AppColors.accent
                              : AppColors.textHint,
                        ),
                        onPressed: _toggleChatSearch,
                        tooltip: 'Поиск в чате',
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline_rounded,
                            size: 20, color: AppColors.textHint),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatInfoScreen(
                              chatId: _chatId,
                              peerId: widget.peerId,
                              peerName: widget.peerName,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: _wallpaperIndex >= 0 && _wallpaperIndex < wallpapers.length
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: wallpapers[_wallpaperIndex],
                ),
              )
            : null,
        child: Column(
        children: [
          // ─── Pinned message bar ────────
          _PinnedBar(chatId: _chatId, onTap: _scrollToMessage),

          // ─── Chat search bar ──────────
          if (_showChatSearch)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                ),
              ),
              child: TextField(
                controller: _chatSearchCtrl,
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Поиск в чате...',
                  hintStyle: TextStyle(
                    color: AppColors.textHint.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 18,
                      color: AppColors.textHint.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _chatSearchQuery = v.toLowerCase()),
              ),
            ),

          // ─── Messages ──────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2,
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: AppColors.textHint.withValues(alpha: 0.4)),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          'Напишите первое сообщение',
                          style: TextStyle(
                            color: AppColors.textHint.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Mark messages as read (no scroll, no rebuild)
                if (docs.length != _lastDocCount) {
                  _lastDocCount = docs.length;
                  _markRead();
                }

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: AppSizes.sm,
                      ),
                      cacheExtent: 1000, // pre-render off-screen for smooth scroll
                      addAutomaticKeepAlives: true,
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        // reverse: true means docs[0] is newest,
                        // so we read from the end for chronological order
                        final msg = MessageModel.fromFirestore(docs[i]);

                        // Chat search filter
                        if (_chatSearchQuery.isNotEmpty &&
                            !msg.text
                                .toLowerCase()
                                .contains(_chatSearchQuery)) {
                          return const SizedBox.shrink();
                        }

                        final isMine = msg.senderId == _myUid;

                        // Date separator — since list is reversed,
                        // "previous" message is at i+1
                        Widget? separator;
                        if (i == docs.length - 1 ||
                            _differentDay(
                                MessageModel.fromFirestore(docs[i + 1])
                                    .createdAt,
                                msg.createdAt)) {
                          separator = _DateSeparator(date: msg.createdAt);
                        }

                        final bubble = GestureDetector(
                              onLongPress: () {
                                if (_multiSelectMode) {
                                  _toggleMultiSelect(msg.id);
                                } else {
                                  _showActions(msg);
                                }
                              },
                              onDoubleTap: () => _reactToMessage(msg),
                              onTap: _multiSelectMode
                                  ? () => _toggleMultiSelect(msg.id)
                                  : null,
                              child: Dismissible(
                                key: Key('swipe_${msg.id}'),
                                direction: DismissDirection.startToEnd,
                                confirmDismiss: (_) async {
                                  _startReply(msg);
                                  return false; // Don't actually dismiss
                                },
                                background: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 16),
                                    child: Icon(Icons.reply_rounded,
                                        color: AppColors.accent.withValues(alpha: 0.6),
                                        size: 24),
                                  ),
                                ),
                                child: Row(
                                children: [
                                  if (_multiSelectMode) ...[
                                    Checkbox(
                                      value: _selectedIds.contains(msg.id),
                                      onChanged: (_) =>
                                          _toggleMultiSelect(msg.id),
                                      activeColor: AppColors.accent,
                                      side: BorderSide(
                                        color: AppColors.textHint
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ],
                                  Expanded(
                                    child: _MessageBubble(
                                      msg: msg,
                                      isMine: isMine,
                                      onScrollToMessage: _scrollToMessage,
                                    ),
                                  ),
                                ],
                              ),
                              ),
                            );

                        // Date separator comes ABOVE the message
                        // In reverse list, we put bubble first then separator
                        final key = _messageKeys.putIfAbsent(
                            msg.id, () => GlobalKey());
                        return RepaintBoundary(
                          key: key,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              bubble,
                              if (separator != null) separator,
                            ],
                          ),
                        );
                      },
                    ),
                    // Scroll-to-bottom FAB (uses ValueListenableBuilder — no parent rebuilds)
                    ValueListenableBuilder<bool>(
                      valueListenable: _showScrollFab,
                      builder: (_, show, child) {
                        if (!show) return const SizedBox.shrink();
                        return child!;
                      },
                      child: Positioned(
                        right: 12,
                        bottom: 12,
                        child: GestureDetector(
                          onTap: _scrollToBottom,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: const Icon(Icons.keyboard_arrow_down,
                                color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // ─── Typing indicator ──────────
          _TypingIndicator(chatId: _chatId, peerId: widget.peerId),

          // ─── Reply / Edit Preview ──────
          if (_replyTo != null)
            _InputPreviewBar(
              icon: Icons.reply_rounded,
              label: _replyTo!.senderName.isNotEmpty
                  ? _replyTo!.senderName
                  : 'Ответ',
              text: _replyTo!.text,
              onCancel: _cancelReply,
            ),
          if (_editingMsg != null)
            _InputPreviewBar(
              icon: Icons.edit_rounded,
              label: 'Редактирование',
              text: _editingMsg!.text,
              onCancel: _cancelEdit,
              accentColor: AppColors.warning,
            ),

          // ─── Pending File Preview ──────
          if (_pendingFile != null || _pendingFileName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                border: Border(
                  left: const BorderSide(color: AppColors.accent, width: 3),
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Thumbnail for images
                  if (_pendingMediaType == 'image' && _pendingFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _pendingFile!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48, height: 48,
                          color: Colors.white.withValues(alpha: 0.06),
                          child: const Icon(Icons.image_rounded,
                              color: AppColors.accent, size: 24),
                        ),
                      ),
                    )
                  else
                    Icon(
                      _pendingMediaType == 'video'
                          ? Icons.videocam_rounded
                          : Icons.insert_drive_file_rounded,
                      size: 28,
                      color: AppColors.accent.withValues(alpha: 0.8),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _pendingMediaType == 'image'
                              ? 'Фото'
                              : _pendingMediaType == 'video'
                                  ? 'Видео'
                                  : 'Файл',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                        Text(
                          _pendingFileName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _cancelPendingFile,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textHint.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

          // ─── Input ─────────────────────
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                padding: EdgeInsets.only(
                  left: AppSizes.md,
                  right: AppSizes.sm,
                  top: AppSizes.sm,
                  bottom:
                      MediaQuery.of(context).padding.bottom + AppSizes.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 0.5,
                    ),
                  ),
                ),
                child: _isRecording
                    // ── Recording bar ──
                    ? Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(_recordSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Запись...',
                            style: TextStyle(
                              color: AppColors.textHint.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _cancelRecording,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              child: Icon(Icons.delete_rounded,
                                  color: AppColors.error.withValues(alpha: 0.8),
                                  size: 20),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _stopRecording(send: true),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.success.withValues(alpha: 0.7),
                                    AppColors.success.withValues(alpha: 0.5),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 0.5,
                                ),
                              ),
                              child: const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      )
                    // ── Normal input bar ──
                    : Row(
                  children: [
                    // Attach file button (📎)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _attachFile,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: Icon(Icons.attach_file_rounded,
                            color: AppColors.textHint.withValues(alpha: 0.6),
                            size: 22),
                      ),
                    ),
                    // Quick replies button
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _showQuickReplies,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: Icon(Icons.flash_on_rounded,
                            color: AppColors.accent.withValues(alpha: 0.7),
                            size: 22),
                      ),
                    ),
                    // Sticker button
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(
                          () => _showStickerPicker = !_showStickerPicker),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6, top: 8, bottom: 8),
                        child: Icon(
                          _showStickerPicker
                              ? Icons.keyboard_rounded
                              : Icons.emoji_emotions_outlined,
                          color: _showStickerPicker
                              ? AppColors.accent
                              : AppColors.textHint.withValues(alpha: 0.6),
                          size: 22,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: _editingMsg != null
                              ? 'Изменить сообщение...'
                              : 'Сообщение...',
                          hintStyle: TextStyle(
                            color:
                                AppColors.textHint.withValues(alpha: 0.5),
                          ),
                          filled: true,
                          fillColor:
                              Colors.white.withValues(alpha: 0.06),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.md,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                AppSizes.radiusLarge),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    // Send or Mic button
                    if (_hasText || _editingMsg != null || _pendingFile != null)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _pendingFile != null
                            ? _sendPendingFile
                            : _send,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _editingMsg != null
                                  ? [
                                      AppColors.warning
                                          .withValues(alpha: 0.7),
                                      AppColors.warning
                                          .withValues(alpha: 0.5),
                                    ]
                                  : [
                                      AppColors.accent
                                          .withValues(alpha: 0.7),
                                      AppColors.accentLight
                                          .withValues(alpha: 0.5),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color:
                                  Colors.white.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                          child: Icon(
                            _editingMsg != null
                                ? Icons.check_rounded
                                : Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      )
                    else
                      // Tap to record (locked mode), or hold to record (release to send)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPressStart: (_) => _startRecording(),
                        onLongPressEnd: (_) {
                          if (_isRecording && !_recordingLocked) {
                            _stopRecording(send: true);
                          }
                        },
                        onTap: () {
                          // Single tap starts recording in locked mode
                          _recordingLocked = true;
                          _startRecording();
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.error.withValues(alpha: 0.6),
                                AppColors.error.withValues(alpha: 0.4),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color:
                                  Colors.white.withValues(alpha: 0.15),
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Sticker Picker ────────────
          if (_showStickerPicker) _StickerPickerPanel(onStickerTap: _sendSticker),
        ],
      ),
      ), // end wallpaper Container
    );
  }
}

// ─── Pinned Message Bar ──────────────────────────────────

class _PinnedBar extends StatelessWidget {
  const _PinnedBar({required this.chatId, this.onTap});
  final String chatId;
  final void Function(String messageId)? onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('isPinned', isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        final msg = MessageModel.fromFirestore(docs.first);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap?.call(msg.id),
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 0.5,
              ),
              left: const BorderSide(color: AppColors.accent, width: 3),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.push_pin_rounded,
                  size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Закреплено',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent)),
                    Text(msg.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}

// ─── Peer Online Status ──────────────────────────────────

class _PeerStatus extends StatelessWidget {
  const _PeerStatus({required this.peerId});
  final String peerId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(peerId)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final isOnline = data['isOnline'] as bool? ?? false;
        final lastSeen = (data['lastSeen'] as Timestamp?)?.toDate();

        String statusText;
        if (isOnline) {
          statusText = 'в сети';
        } else if (lastSeen != null) {
          final diff = DateTime.now().difference(lastSeen);
          if (diff.inMinutes < 1) {
            statusText = 'только что';
          } else if (diff.inHours < 1) {
            statusText = '${diff.inMinutes} мин. назад';
          } else if (diff.inDays < 1) {
            statusText = '${diff.inHours} ч. назад';
          } else {
            statusText =
                '${lastSeen.day}.${lastSeen.month.toString().padLeft(2, '0')}';
          }
        } else {
          return const SizedBox.shrink();
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOnline)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 4),
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 12,
                color: isOnline
                    ? AppColors.success
                    : AppColors.textHint.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Typing Indicator ────────────────────────────────────

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.chatId, required this.peerId});
  final String chatId;
  final String peerId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final peerTyping = data['typing_$peerId'] as bool? ?? false;
        if (!peerTyping) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BouncingDots(),
                const SizedBox(width: 6),
                Text(
                  'печатает...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BouncingDots extends StatefulWidget {
  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) ctrl.repeat(reverse: true);
      });
      return ctrl;
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _ctrls.map((ctrl) {
        return AnimatedBuilder(
          animation: ctrl,
          builder: (_, __) => Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textHint
                  .withValues(alpha: 0.3 + ctrl.value * 0.5),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Input Preview Bar (Reply / Edit) ────────────────────

class _InputPreviewBar extends StatelessWidget {
  const _InputPreviewBar({
    required this.icon,
    required this.label,
    required this.text,
    required this.onCancel,
    this.accentColor = AppColors.accent,
  });

  final IconData icon;
  final String label;
  final String text;
  final VoidCallback onCancel;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textHint.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Tile ─────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Forward Contact Picker ──────────────────────────────

class _ForwardContactPicker extends StatelessWidget {
  const _ForwardContactPicker({required this.contacts});
  final List<dynamic> contacts;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Переслать',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  itemBuilder: (_, i) {
                    final c = contacts[i];
                    final name = c.name as String? ?? '';
                    final uid = (c.linkedUserId as String?) ?? '';
                    if (uid.isEmpty) return const SizedBox.shrink();

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, uid),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              VAvatar(name: name, radius: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.send_rounded,
                                size: 18,
                                color: AppColors.accent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Date Separator ──────────────────────────────────

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    String label;
    if (d == today) {
      label = 'Сегодня';
    } else if (d == today.subtract(const Duration(days: 1))) {
      label = 'Вчера';
    } else {
      label =
          '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textHint.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Message Bubble ──────────────────────────────────────

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.msg,
    required this.isMine,
    this.onScrollToMessage,
  });

  final MessageModel msg;
  final bool isMine;
  final void Function(String messageId)? onScrollToMessage;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _isPlayingVoice = false;
  Timer? _voiceTimer;
  int _voiceProgress = 0;
  AudioPlayer? _voicePlayer;
  StreamSubscription? _positionSub;
  StreamSubscription? _completeSub;

  MessageModel get msg => widget.msg;
  bool get isMine => widget.isMine;

  @override
  void dispose() {
    _voiceTimer?.cancel();
    _positionSub?.cancel();
    _completeSub?.cancel();
    _voicePlayer?.dispose();
    super.dispose();
  }

  void _toggleVoicePlay() async {
    if (_isPlayingVoice) {
      _voiceTimer?.cancel();
      _positionSub?.cancel();
      _completeSub?.cancel();
      await _voicePlayer?.stop();
      setState(() {
        _isPlayingVoice = false;
        _voiceProgress = 0;
      });
    } else {
      final totalSec = msg.mediaSize ?? 5;
      final audioData = msg.mediaUrl;

      if (audioData == null || audioData.isEmpty) {
        // No audio data available — fallback timer animation
        setState(() {
          _isPlayingVoice = true;
          _voiceProgress = 0;
        });
        _voiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) { timer.cancel(); return; }
          setState(() => _voiceProgress++);
          if (_voiceProgress >= totalSec) {
            timer.cancel();
            setState(() { _isPlayingVoice = false; _voiceProgress = 0; });
          }
        });
        return;
      }

      try {
        // Stop any existing playback
        _voiceTimer?.cancel();
        _positionSub?.cancel();
        _completeSub?.cancel();
        _voicePlayer?.dispose();
        _voicePlayer = AudioPlayer();

        // Decode base64 audio, write to temp file with unique name
        final bytes = base64Decode(audioData);
        final dir = await getTemporaryDirectory();
        final ts = DateTime.now().millisecondsSinceEpoch;
        final tmpFile = File('${dir.path}/vizo_play_${msg.id}_$ts.m4a');
        await tmpFile.writeAsBytes(bytes);

        // Use position stream for accurate progress tracking
        _positionSub = _voicePlayer!.onPositionChanged.listen((pos) {
          if (!mounted) return;
          final sec = pos.inSeconds;
          if (sec != _voiceProgress) {
            setState(() => _voiceProgress = sec);
          }
        });

        _completeSub = _voicePlayer!.onPlayerComplete.listen((_) {
          if (mounted) {
            _positionSub?.cancel();
            setState(() { _isPlayingVoice = false; _voiceProgress = 0; });
            // Clean up temp file
            try { tmpFile.delete(); } catch (_) {}
          }
        });

        await _voicePlayer!.play(DeviceFileSource(tmpFile.path));

        setState(() {
          _isPlayingVoice = true;
          _voiceProgress = 0;
        });
      } catch (e) {
        debugPrint('Voice play error: $e');
        _positionSub?.cancel();
        _completeSub?.cancel();
        setState(() { _isPlayingVoice = false; _voiceProgress = 0; });
      }
    }
  }

  static final _urlRegex = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  );

  static String? _extractUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    return match?.group(0);
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Decode a data:image/...;base64,... URL to bytes
  static Uint8List? _decodeBase64Url(String dataUrl) {
    try {
      final commaIdx = dataUrl.indexOf(',');
      if (commaIdx < 0) return null;
      return base64Decode(dataUrl.substring(commaIdx + 1));
    } catch (_) {
      return null;
    }
  }

  /// Build the right Image widget depending on the URL format
  Widget _buildImageWidget(MessageModel msg) {
    final url = msg.mediaUrl;

    // Case 1: base64 data URL
    if (url != null && url.startsWith('data:')) {
      final bytes = _decodeBase64Url(url);
      if (bytes != null) {
        return Image.memory(
          bytes,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _imageErrorPlaceholder(),
        );
      }
      return _imageErrorPlaceholder();
    }

    // Case 2: local file path
    if (url != null && (url.startsWith('/') || url.startsWith('file:'))) {
      final file = File(url.replaceFirst('file://', ''));
      if (file.existsSync()) {
        return Image.file(
          file,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _imageErrorPlaceholder(),
        );
      }
      return _imageErrorPlaceholder();
    }

    // Case 3: HTTP/HTTPS URL
    if (url != null && url.startsWith('http')) {
      return Image.network(
        url,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 180,
            alignment: Alignment.center,
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          );
        },
        errorBuilder: (_, __, ___) => _imageErrorPlaceholder(),
      );
    }

    // Fallback: no URL — show file name
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_rounded,
              size: 28,
              color: AppColors.accent.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              msg.mediaName ?? 'Фото',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: isMine ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageErrorPlaceholder() {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_rounded,
              size: 32,
              color: AppColors.textHint.withValues(alpha: 0.4)),
          const SizedBox(height: 4),
          Text('Не удалось загрузить',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint.withValues(alpha: 0.4),
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = msg.createdAt != DateTime(0)
        ? '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    final hasReactions = msg.reactions.isNotEmpty || msg.reaction != null;

    return Padding(
      padding: EdgeInsets.only(bottom: hasReactions ? 20 : 6),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: msg.isDeleted
                ? Colors.white.withValues(alpha: 0.04)
                : isMine
                    ? AppColors.accent.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
            border: Border.all(
              color: msg.isDeleted
                  ? Colors.white.withValues(alpha: 0.04)
                  : isMine
                      ? AppColors.accent.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Forwarded label
              if (msg.forwardedFrom != null && !msg.isDeleted) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forward_rounded,
                        size: 12,
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.textHint.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      'Переслано от ${msg.forwardedFrom}',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.textHint.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Reply preview
              if (msg.replyToText != null && !msg.isDeleted) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: msg.replyToId != null
                      ? () => widget.onScrollToMessage?.call(msg.replyToId!)
                      : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: AppColors.accentLight.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (msg.replyToSender != null)
                        Text(
                          msg.replyToSender!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentLight
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      Text(
                        msg.replyToText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isMine
                              ? Colors.white.withValues(alpha: 0.6)
                              : AppColors.textSecondary
                                  .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                ),
                const SizedBox(height: 6),
              ],

              // Message text or deleted placeholder
              if (msg.isDeleted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block_rounded,
                        size: 14,
                        color: AppColors.textHint.withValues(alpha: 0.4)),
                    const SizedBox(width: 4),
                    Text(
                      'Сообщение удалено',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textHint.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                )
              else ...[
                // Sticker message — big emoji
                if (msg.mediaType == 'sticker') ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(msg.text,
                        style: const TextStyle(fontSize: 56)),
                  ),
                ]
                // Image message — display inline
                else if (msg.mediaType == 'image') ...[
                  GestureDetector(
                    onTap: () {
                      // Open full-screen image viewer
                      if (msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MediaViewerScreen(
                              imageUrl: msg.mediaUrl!.startsWith('data:')
                                  ? null
                                  : msg.mediaUrl!,
                              imageBytes: msg.mediaUrl!.startsWith('data:')
                                  ? _decodeBase64Url(msg.mediaUrl!)
                                  : null,
                              heroTag: 'img_${msg.id}',
                            ),
                          ),
                        );
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _buildImageWidget(msg),
                    ),
                  ),
                  if (msg.text.isNotEmpty &&
                      !msg.text.startsWith('📷') &&
                      !msg.text.startsWith('🖼'))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          color: isMine ? Colors.white : AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                ]
                // Video message — display with play overlay
                else if (msg.mediaType == 'video') ...[
                  GestureDetector(
                    onTap: () {
                      // Open video player screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _VideoPlayerScreen(
                            mediaUrl: msg.mediaUrl,
                            mediaName: msg.mediaName ?? 'Видео',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Video thumbnail placeholder
                          Center(
                            child: Icon(Icons.videocam_rounded,
                                size: 40,
                                color: AppColors.textHint.withValues(alpha: 0.3)),
                          ),
                          // Play overlay
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.5),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(Icons.play_arrow_rounded,
                                size: 32, color: Colors.white),
                          ),
                          // File name at bottom
                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Text(
                              msg.mediaName ?? 'Видео',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isMine
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : AppColors.textHint.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (msg.text.isNotEmpty &&
                      !msg.text.startsWith('🎬') &&
                      !msg.text.startsWith('📹'))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          color: isMine ? Colors.white : AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                ]
                // File message
                else if (msg.mediaType == 'file') ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insert_drive_file_rounded,
                            size: 28,
                            color: AppColors.accent.withValues(alpha: 0.8)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                msg.mediaName ?? 'Файл',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isMine
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (msg.mediaSize != null)
                                Text(
                                  _formatFileSize(msg.mediaSize!),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isMine
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : AppColors.textHint
                                            .withValues(alpha: 0.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
                // Voice message
                else if (msg.mediaType == 'voice') ...[
                  GestureDetector(
                    onTap: _toggleVoicePlay,
                    child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isMine
                                ? Colors.white.withValues(alpha: 0.15)
                                : AppColors.accent.withValues(alpha: 0.15),
                          ),
                          child: Icon(
                              _isPlayingVoice
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 22,
                              color: isMine
                                  ? Colors.white
                                  : AppColors.accent),
                        ),
                        const SizedBox(width: 10),
                        // Waveform with progress
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Simulated waveform bars with playback progress
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(16, (i) {
                                  final h = 4.0 + (i * 7 % 13).toDouble();
                                  final totalSec = msg.mediaSize ?? 5;
                                  final progress = totalSec > 0
                                      ? _voiceProgress / totalSec
                                      : 0.0;
                                  final played = i / 16 < progress;
                                  return Container(
                                    width: 3,
                                    height: h,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(
                                      color: played
                                          ? (isMine
                                              ? Colors.white.withValues(alpha: 0.9)
                                              : AppColors.accent.withValues(alpha: 0.9))
                                          : (isMine
                                              ? Colors.white.withValues(alpha: 0.3)
                                              : AppColors.accent.withValues(alpha: 0.3)),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isPlayingVoice
                                    ? '${(_voiceProgress ~/ 60).toString().padLeft(2, '0')}:${(_voiceProgress % 60).toString().padLeft(2, '0')}'
                                    : (msg.mediaSize != null
                                        ? '${(msg.mediaSize! ~/ 60).toString().padLeft(2, '0')}:${(msg.mediaSize! % 60).toString().padLeft(2, '0')}'
                                        : '0:00'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMine
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : AppColors.textHint.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                ]
                // Normal message with possible link preview
                else ...[
                // Link preview (detect URLs)
                if (_extractUrl(msg.text) != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_rounded,
                            size: 16,
                            color: AppColors.accentLight.withValues(alpha: 0.7)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _extractUrl(msg.text)!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.accentLight.withValues(alpha: 0.8),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Text(
                  msg.text,
                  style: TextStyle(
                    color: isMine ? Colors.white : AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                ],
              ],

              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (msg.isEdited && !msg.isDeleted) ...[
                    Text(
                      'ред.',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.45)
                            : AppColors.textHint.withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.6)
                          : AppColors.textHint.withValues(alpha: 0.6),
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.isRead ? Icons.done_all : Icons.done,
                      size: 14,
                      color: msg.isRead
                          ? Colors.lightBlueAccent
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ],
                  if (msg.isStarred) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.star_rounded,
                        size: 12,
                        color: Colors.amber.withValues(alpha: 0.7)),
                  ],
                  if (msg.isPinned) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.push_pin_rounded,
                        size: 11,
                        color: AppColors.accentLight.withValues(alpha: 0.6)),
                  ],
                ],
              ),
              // Reaction badge — positioned as overlay so it doesn't stretch bubble
              ],
              ),
            ),
            // Multi-reaction badges
            if (msg.reactions.isNotEmpty)
              Positioned(
                bottom: -14,
                right: isMine ? 8 : null,
                left: isMine ? null : 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: msg.reactions.entries.map((entry) {
                    final emoji = entry.key;
                    final users = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 14)),
                            if (users.length > 1) ...[
                              const SizedBox(width: 3),
                              Text('${users.length}', style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )
            // Legacy single reaction fallback
            else if (msg.reaction != null)
              Positioned(
                bottom: -12,
                right: isMine ? 8 : null,
                left: isMine ? null : 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Text(msg.reaction!, style: const TextStyle(fontSize: 16)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Video Player Screen ─────────────────────────────────

class _VideoPlayerScreen extends StatefulWidget {
  const _VideoPlayerScreen({
    required this.mediaUrl,
    required this.mediaName,
  });

  final String? mediaUrl;
  final String mediaName;

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final url = widget.mediaUrl;
      if (url != null && (url.startsWith('/') || url.startsWith('file:'))) {
        final path = url.replaceFirst('file://', '');
        _controller = VideoPlayerController.file(File(path));
      } else if (url != null && url.startsWith('http')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        setState(() => _hasError = true);
        return;
      }

      await _controller.initialize();
      _controller.addListener(() {
        if (mounted) setState(() {});
      });
      if (mounted) {
        setState(() => _initialized = true);
        _controller.play();
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    if (_initialized) _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.mediaName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _hasError
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.textHint.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('Не удалось воспроизвести видео',
                      style: TextStyle(
                          color: AppColors.textHint.withValues(alpha: 0.6),
                          fontSize: 15)),
                ],
              ),
            )
          : !_initialized
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accent,
                    strokeWidth: 2,
                  ),
                )
              : GestureDetector(
                  onTap: () =>
                      setState(() => _showControls = !_showControls),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                      // Play/Pause overlay
                      if (_showControls) ...[
                        GestureDetector(
                          onTap: () {
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                            } else {
                              _controller.play();
                            }
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                            child: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Progress bar
                        Positioned(
                          bottom: 20,
                          left: 16,
                          right: 16,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              VideoProgressIndicator(
                                _controller,
                                allowScrubbing: true,
                                colors: VideoProgressColors(
                                  playedColor: AppColors.accent,
                                  bufferedColor:
                                      AppColors.accent.withValues(alpha: 0.3),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(
                                        _controller.value.position),
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(
                                        _controller.value.duration),
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

// ─── Sticker Picker Panel ────────────────────────────────

class _StickerPickerPanel extends StatefulWidget {
  const _StickerPickerPanel({required this.onStickerTap});
  final void Function(String emoji) onStickerTap;

  @override
  State<_StickerPickerPanel> createState() => _StickerPickerPanelState();
}

class _StickerPickerPanelState extends State<_StickerPickerPanel> {
  int _selectedPackIndex = 0;

  @override
  Widget build(BuildContext context) {
    final packs = StickerPack.builtInPacks;

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Pack tabs
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: packs.length,
              itemBuilder: (_, i) {
                final isSelected = i == _selectedPackIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPackIndex = i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: AppColors.accent.withValues(alpha: 0.4),
                              width: 0.5)
                          : null,
                    ),
                    child: Text(
                      packs[i].name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Sticker grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: packs[_selectedPackIndex].stickers.length,
              itemBuilder: (_, i) {
                final sticker = packs[_selectedPackIndex].stickers[i];
                return GestureDetector(
                  onTap: () => widget.onStickerTap(sticker.emoji),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(sticker.emoji,
                            style: const TextStyle(fontSize: 32)),
                        if (sticker.label != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              sticker.label!,
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textHint
                                    .withValues(alpha: 0.5),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
