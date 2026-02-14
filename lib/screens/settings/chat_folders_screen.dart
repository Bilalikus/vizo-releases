import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Chat folders — organize conversations into custom categories.
class ChatFoldersScreen extends ConsumerStatefulWidget {
  const ChatFoldersScreen({super.key});

  @override
  ConsumerState<ChatFoldersScreen> createState() =>
      _ChatFoldersScreenState();
}

class _ChatFoldersScreenState extends ConsumerState<ChatFoldersScreen> {
  late final String _uid;

  static const _iconOptions = [
    Icons.work_rounded,
    Icons.people_rounded,
    Icons.favorite_rounded,
    Icons.school_rounded,
    Icons.sports_esports_rounded,
    Icons.shopping_bag_rounded,
    Icons.attach_money_rounded,
    Icons.flight_rounded,
    Icons.restaurant_rounded,
    Icons.music_note_rounded,
    Icons.fitness_center_rounded,
    Icons.code_rounded,
  ];

  static const _iconNames = [
    'work', 'people', 'favorite', 'school', 'gaming',
    'shopping', 'money', 'travel', 'food', 'music',
    'fitness', 'code',
  ];

  IconData _iconFromName(String name) {
    final idx = _iconNames.indexOf(name);
    return idx >= 0 ? _iconOptions[idx] : Icons.folder_rounded;
  }

  @override
  void initState() {
    super.initState();
    _uid = ref.read(authServiceProvider).effectiveUid;
  }

  CollectionReference get _foldersRef => FirebaseFirestore.instance
      .collection('users')
      .doc(_uid)
      .collection('chat_folders');

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    int selectedIcon = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          ),
          title: const Text('Новая папка',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VTextField(
                controller: nameCtrl,
                hint: 'Название папки',
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Иконка',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_iconOptions.length, (i) {
                  final isSelected = i == selectedIcon;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedIcon = i),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accent.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : Colors.white.withValues(alpha: 0.1),
                          width: isSelected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Icon(_iconOptions[i],
                          size: 20,
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textSecondary),
                    ),
                  );
                }),
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
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final count = (await _foldersRef.get()).docs.length;
                await _foldersRef.add({
                  'name': name,
                  'icon': _iconNames[selectedIcon],
                  'chatIds': <String>[],
                  'order': count,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Создать',
                  style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteFolder(String id) async {
    await _foldersRef.doc(id).delete();
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
              title: const Text('Папки чатов',
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
        stream: _foldersRef.orderBy('order').snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_outlined,
                      size: 56,
                      color: AppColors.textHint.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text('Создайте папки для организации чатов',
                      style: TextStyle(
                          color: AppColors.textHint.withValues(alpha: 0.6),
                          fontSize: 15)),
                  const SizedBox(height: 12),
                  Text('Например: Работа, Семья, Друзья',
                      style: TextStyle(
                          color: AppColors.textHint.withValues(alpha: 0.4),
                          fontSize: 13)),
                  const SizedBox(height: 20),
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
                      child: const Text('Создать папку',
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
              final name = d['name'] as String? ?? '';
              final iconName = d['icon'] as String? ?? 'folder';
              final chatIds =
                  List<String>.from(d['chatIds'] as List? ?? []);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: VCard(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_iconFromName(iconName),
                            size: 22, color: AppColors.accentLight),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(
                              '${chatIds.length} ${chatIds.length == 1 ? 'чат' : 'чатов'}',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _deleteFolder(docs[i].id),
                        child: Icon(Icons.delete_outline_rounded,
                            size: 20,
                            color: AppColors.error.withValues(alpha: 0.7)),
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
