import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Stories / Moments screen — Instagram-like 24hr stories.
class StoriesScreen extends ConsumerStatefulWidget {
  const StoriesScreen({super.key});

  @override
  ConsumerState<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends ConsumerState<StoriesScreen> {
  Future<void> _createTextStory() async {
    final textCtrl = TextEditingController();
    int colorIndex = 0;

    final gradients = <List<Color>>[
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
      [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
      [const Color(0xFFFFA585), const Color(0xFFFFEDA0)],
      [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)],
    ];

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.maxFinite,
            height: 400,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradients[colorIndex],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      GestureDetector(
                        onTap: () => setS(() {
                          colorIndex =
                              (colorIndex + 1) % gradients.length;
                        }),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                                colors: gradients[
                                    (colorIndex + 1) %
                                        gradients.length]),
                            border: Border.all(
                                color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_rounded,
                            color: Colors.white),
                        onPressed: () {
                          final text = textCtrl.text.trim();
                          if (text.isNotEmpty) {
                            Navigator.pop(ctx,
                                '$colorIndex|$text');
                          }
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: TextField(
                        controller: textCtrl,
                        textAlign: TextAlign.center,
                        maxLines: 5,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Что нового?',
                          hintStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
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
    );

    if (result == null) return;

    final parts = result.split('|');
    final cIdx = int.tryParse(parts[0]) ?? 0;
    final text = parts.sublist(1).join('|');

    final uid = ref.read(authServiceProvider).effectiveUid;
    final user = ref.read(currentUserProvider);

    await FirebaseFirestore.instance.collection('stories').add({
      'userId': uid,
      'userName': user.displayName,
      'userAvatar': user.effectiveAvatar,
      'type': 'text',
      'text': text,
      'colorIndex': cIdx,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24))),
      'views': <String>[],
    });

    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Момент опубликован ✓')),
      );
    }
  }

  Future<void> _createImageStory() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 70,
    );
    if (image == null) return;

    final bytes = await File(image.path).readAsBytes();
    final base64Img = base64Encode(bytes);

    final uid = ref.read(authServiceProvider).effectiveUid;
    final user = ref.read(currentUserProvider);

    await FirebaseFirestore.instance.collection('stories').add({
      'userId': uid,
      'userName': user.displayName,
      'userAvatar': user.effectiveAvatar,
      'type': 'image',
      'imageBase64': base64Img,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24))),
      'views': <String>[],
    });

    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фото опубликовано ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.read(authServiceProvider).effectiveUid;
    final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)));

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
              title: const Text('Моменты',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              centerTitle: true,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: AppColors.surfaceLight,
            shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(Icons.text_fields_rounded,
                        color: AppColors.accent),
                    title: const Text('Текстовый момент',
                        style:
                            TextStyle(color: AppColors.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _createTextStory();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_rounded,
                        color: AppColors.accent),
                    title: const Text('Фото момент',
                        style:
                            TextStyle(color: AppColors.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _createImageStory();
                    },
                  ),
                ],
              ),
            ),
          );
        },
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('stories')
            .where('expiresAt', isGreaterThan: cutoff)
            .orderBy('expiresAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 56,
                      color: AppColors.textHint.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text('Нет моментов',
                      style: TextStyle(
                          fontSize: 15,
                          color:
                              AppColors.textHint.withValues(alpha: 0.6))),
                  const SizedBox(height: 4),
                  Text('Создайте первый момент!',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              AppColors.textHint.withValues(alpha: 0.4))),
                ],
              ),
            );
          }

          // Group by userId
          final Map<String, List<QueryDocumentSnapshot>> grouped = {};
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final userId = data['userId'] as String? ?? '';
            grouped.putIfAbsent(userId, () => []).add(doc);
          }

          final userIds = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: userIds.length,
            itemBuilder: (_, i) {
              final userId = userIds[i];
              final stories = grouped[userId]!;
              final first = stories.first.data() as Map<String, dynamic>;
              final userName = first['userName'] as String? ?? '';
              final userAvatar = first['userAvatar'] as String?;
              final isMe = userId == uid;
              final hasUnviewed = stories.any((s) {
                final data = s.data() as Map<String, dynamic>;
                final views = List<String>.from(data['views'] ?? []);
                return !views.contains(uid);
              });

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: VCard(
                  onTap: () => _viewStories(context, stories, uid),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: hasUnviewed
                                ? AppColors.accent
                                : Colors.white.withValues(alpha: 0.15),
                            width: 2,
                          ),
                        ),
                        child: VAvatar(
                          name: userName,
                          imageUrl: userAvatar,
                          radius: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isMe ? 'Мои моменты' : userName,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            Text(
                              '${stories.length} момент${stories.length > 1 ? (stories.length < 5 ? 'а' : 'ов') : ''}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textHint
                                      .withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                      if (hasUnviewed)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
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

  void _viewStories(BuildContext context,
      List<QueryDocumentSnapshot> stories, String myUid) {
    final gradients = <List<Color>>[
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
      [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
      [const Color(0xFFFFA585), const Color(0xFFFFEDA0)],
      [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)],
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _StoryViewer(
          stories: stories,
          myUid: myUid,
          gradients: gradients,
        ),
      ),
    );
  }
}

// ─── Story Viewer ────────────────────────────────────────

class _StoryViewer extends StatefulWidget {
  const _StoryViewer({
    required this.stories,
    required this.myUid,
    required this.gradients,
  });
  final List<QueryDocumentSnapshot> stories;
  final String myUid;
  final List<List<Color>> gradients;

  @override
  State<_StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<_StoryViewer> {
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _markViewed();
  }

  void _markViewed() {
    final doc = widget.stories[_current];
    final data = doc.data() as Map<String, dynamic>;
    final views = List<String>.from(data['views'] ?? []);
    if (!views.contains(widget.myUid)) {
      doc.reference.update({
        'views': FieldValue.arrayUnion([widget.myUid]),
      });
    }
  }

  void _next() {
    if (_current < widget.stories.length - 1) {
      setState(() => _current++);
      _markViewed();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_current > 0) {
      setState(() => _current--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data =
        widget.stories[_current].data() as Map<String, dynamic>;
    final type = data['type'] as String? ?? 'text';
    final userName = data['userName'] as String? ?? '';
    final colorIndex = data['colorIndex'] as int? ?? 0;
    final views = List<String>.from(data['views'] ?? []);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _prev();
          } else {
            _next();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Content
            if (type == 'text')
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.gradients[
                        colorIndex % widget.gradients.length],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      data['text'] as String? ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              )
            else if (type == 'image')
              () {
                final img = data['imageBase64'] as String?;
                if (img != null && img.isNotEmpty) {
                  return Image.memory(
                    base64Decode(img),
                    fit: BoxFit.cover,
                  );
                }
                return Container(color: Colors.black);
              }(),

            // Progress bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(widget.stories.length, (i) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: i <= _current
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Header
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  Text(userName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const Spacer(),
                  Text('${views.length} 👁',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
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
