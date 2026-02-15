import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Screen to create a group or community.
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key, this.isCommunity = false});
  final bool isCommunity;

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название')),
      );
      return;
    }

    setState(() => _loading = true);

    final uid = ref.read(authServiceProvider).effectiveUid;
    final db = FirebaseFirestore.instance;

    try {
      final ref = db.collection('groups').doc();
      await ref.set({
        'name': name,
        'description': _descCtrl.text.trim(),
        'creatorUid': uid,
        'members': [uid],
        'admins': [uid],
        'isPublic': widget.isCommunity,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'mutedBy': [],
        'bannedUsers': [],
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isCommunity
                ? 'Сообщество «$name» создано!'
                : 'Группа «$name» создана!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.isCommunity ? 'Новое сообщество' : 'Новая группа';

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    widget.isCommunity
                        ? Icons.public_rounded
                        : Icons.group_add_rounded,
                    color: AppColors.accent,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Group icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    widget.isCommunity
                        ? Icons.public_rounded
                        : Icons.group_rounded,
                    color: AppColors.accent,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              VTextField(
                controller: _nameCtrl,
                hint: 'Название',
                prefixIcon: const Icon(Icons.edit_rounded, color: AppColors.textHint, size: 20),
              ),
              const SizedBox(height: 12),
              VTextField(
                controller: _descCtrl,
                hint: 'Описание (необязательно)',
                prefixIcon: const Icon(Icons.info_outline_rounded, color: AppColors.textHint, size: 20),
              ),

              if (widget.isCommunity) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Сообщество доступно для всех пользователей. '
                              'Любой может вступить и писать сообщения.',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: VButton(
                  onPressed: _loading ? null : _create,
                  label: _loading ? 'Создание...' : 'Создать',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
