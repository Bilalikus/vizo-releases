import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';

/// Saved Messages — personal notepad / self-chat.
class SavedMessagesScreen extends ConsumerStatefulWidget {
  const SavedMessagesScreen({super.key});

  @override
  ConsumerState<SavedMessagesScreen> createState() =>
      _SavedMessagesScreenState();
}

class _SavedMessagesScreenState extends ConsumerState<SavedMessagesScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = ref.read(authServiceProvider).effectiveUid;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  CollectionReference get _notesRef => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('saved_messages');

  Future<void> _addNote() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    await _notesRef.add({
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'isPinned': false,
    });
    _scrollToBottom();
  }

  Future<void> _deleteNote(String id) async {
    await _notesRef.doc(id).delete();
  }

  Future<void> _togglePin(String id, bool current) async {
    await _notesRef.doc(id).update({'isPinned': !current});
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
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
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_rounded,
                      size: 20, color: AppColors.accentLight),
                  SizedBox(width: 8),
                  Text('Заметки',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ],
              ),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _notesRef.orderBy('createdAt').snapshots(),
              builder: (_, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_outline_rounded,
                            size: 48,
                            color: AppColors.textHint.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text('Сохраняйте заметки и ссылки',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textHint
                                    .withValues(alpha: 0.6))),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final text = d['text'] as String? ?? '';
                    final pinned = d['isPinned'] as bool? ?? false;
                    final ts =
                        (d['createdAt'] as Timestamp?)?.toDate();
                    final tStr = ts != null
                        ? '${ts.day}.${ts.month.toString().padLeft(2, '0')} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                        : '';

                    return GestureDetector(
                      onLongPress: () => _showNoteActions(
                          docs[i].id, text, pinned),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: pinned
                                ? AppColors.accent.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: pinned
                                  ? AppColors.accent
                                      .withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.06),
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (pinned)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.push_pin_rounded,
                                          size: 12,
                                          color: AppColors.accent
                                              .withValues(alpha: 0.7)),
                                      const SizedBox(width: 4),
                                      Text('Закреплено',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.accent
                                                  .withValues(
                                                      alpha: 0.7))),
                                    ],
                                  ),
                                ),
                              Text(text,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(tStr,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textHint
                                            .withValues(alpha: 0.5))),
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
          ),

          // ─── Input ─────
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 8,
                  top: 8,
                  bottom:
                      MediaQuery.of(context).padding.bottom + 8,
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
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Заметка...',
                          hintStyle: TextStyle(
                              color: AppColors.textHint
                                  .withValues(alpha: 0.5)),
                          filled: true,
                          fillColor:
                              Colors.white.withValues(alpha: 0.06),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _addNote(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _addNote,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accent.withValues(alpha: 0.7),
                              AppColors.accentLight
                                  .withValues(alpha: 0.5),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 22),
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

  void _showNoteActions(String id, String text, bool pinned) {
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
                  _NoteAction(
                    icon: Icons.copy_rounded,
                    label: 'Копировать',
                    onTap: () {
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Скопировано')),
                      );
                    },
                  ),
                  _NoteAction(
                    icon: pinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                    label: pinned ? 'Открепить' : 'Закрепить',
                    onTap: () {
                      Navigator.pop(context);
                      _togglePin(id, pinned);
                    },
                  ),
                  _NoteAction(
                    icon: Icons.delete_outline_rounded,
                    label: 'Удалить',
                    color: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      _deleteNote(id);
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
}

class _NoteAction extends StatelessWidget {
  const _NoteAction({
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 14),
              Text(label,
                  style: TextStyle(
                      fontSize: 16,
                      color: color,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
