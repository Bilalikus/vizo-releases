import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Quick replies — predefined message templates.
class QuickRepliesScreen extends ConsumerStatefulWidget {
  const QuickRepliesScreen({super.key});

  @override
  ConsumerState<QuickRepliesScreen> createState() =>
      _QuickRepliesScreenState();
}

class _QuickRepliesScreenState extends ConsumerState<QuickRepliesScreen> {
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = ref.read(authServiceProvider).effectiveUid;
  }

  CollectionReference get _repliesRef => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('quick_replies');

  void _showAddDialog() {
    final labelCtrl = TextEditingController();
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: const Text('Новый шаблон',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VTextField(
              controller: labelCtrl,
              hint: 'Название (напр. Привет)',
            ),
            const SizedBox(height: 12),
            VTextField(
              controller: textCtrl,
              hint: 'Текст сообщения...',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () async {
              final label = labelCtrl.text.trim();
              final text = textCtrl.text.trim();
              if (label.isEmpty || text.isEmpty) return;
              await _repliesRef.add({
                'label': label,
                'text': text,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Добавить',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(String id) async {
    await _repliesRef.doc(id).delete();
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
              title: const Text('Быстрые ответы',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded,
                      color: AppColors.accent, size: 24),
                  onPressed: _showAddDialog,
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _repliesRef.orderBy('createdAt').snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.quickreply_rounded,
                      size: 56,
                      color: AppColors.textHint.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text('Нет шаблонов быстрых ответов',
                      style: TextStyle(
                          color: AppColors.textHint.withValues(alpha: 0.6),
                          fontSize: 15)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _showAddDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text('Создать первый',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final label = d['label'] as String? ?? '';
              final text = d['text'] as String? ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Dismissible(
                  key: Key(docs[i].id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.delete_rounded,
                        color: AppColors.error),
                  ),
                  onDismissed: (_) => _delete(docs[i].id),
                  child: VCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.accent
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(label,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accentLight)),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _delete(docs[i].id),
                              child: Icon(Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.textHint
                                      .withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(text,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary)),
                      ],
                    ),
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
