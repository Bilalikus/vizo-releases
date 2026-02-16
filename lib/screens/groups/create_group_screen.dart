import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Screen to create a group, community, or channel.
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key, this.isCommunity = false, this.isChannel = false});
  final bool isCommunity;
  final bool isChannel;

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  bool _loading = false;
  String? _avatarBase64;
  String _region = '';

  static const _regions = [
    {'code': '', 'label': 'Не указан'},
    {'code': 'EU', 'label': '🇪🇺 Европа'},
    {'code': 'USA', 'label': '🇺🇸 США'},
    {'code': 'RU', 'label': '🇷🇺 Россия'},
    {'code': 'ASIA', 'label': '🌏 Азия'},
    {'code': 'OTHER', 'label': '🌍 Другое'},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 256, maxHeight: 256, imageQuality: 60);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() => _avatarBase64 = base64Encode(bytes));
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите название')));
      return;
    }

    if (widget.isCommunity && _region.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Выберите регион!')));
      return;
    }

    setState(() => _loading = true);

    final uid = ref.read(authServiceProvider).effectiveUid;
    final db = FirebaseFirestore.instance;

    try {
      if (widget.isChannel) {
        // Create channel
        final docRef = db.collection('channels').doc();
        await docRef.set({
          'name': name,
          'description': _descCtrl.text.trim(),
          'avatarBase64': _avatarBase64,
          'creatorUid': uid,
          'subscribers': [uid],
          'writers': [uid],
          'isBanned': false,
          'banReason': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': null,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'mutedBy': [],
        });
      } else {
        // Create group or community
        final type = widget.isCommunity ? 'community' : 'group';
        final docRef = db.collection('groups').doc();
        await docRef.set({
          'name': name,
          'description': _descCtrl.text.trim(),
          'avatarBase64': _avatarBase64,
          'creatorUid': uid,
          'members': [uid],
          'admins': [uid],
          'isPublic': widget.isCommunity,
          'type': type,
          'region': _region,
          'category': _categoryCtrl.text.trim(),
          'isBanned': false,
          'banReason': '',
          'isFrozen': false,
          'writers': [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessage': null,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'mutedBy': [],
          'bannedUsers': [],
        });
      }

      if (mounted) {
        Navigator.pop(context);
        final label = widget.isChannel ? 'Канал' : (widget.isCommunity ? 'Сообщество' : 'Группа');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label «$name» создан!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isChannel ? 'Новый канал' : (widget.isCommunity ? 'Новое сообщество' : 'Новая группа');
    final icon = widget.isChannel ? Icons.campaign_rounded : (widget.isCommunity ? Icons.public_rounded : Icons.group_add_rounded);

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
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Icon(icon, color: AppColors.accent, size: 28),
                  const SizedBox(width: 10),
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
                ],
              ),
              const SizedBox(height: 30),

              // Icon picker
              Center(
                child: GestureDetector(
                  onTap: _pickIcon,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                      image: _avatarBase64 != null ? DecorationImage(image: MemoryImage(base64Decode(_avatarBase64!)), fit: BoxFit.cover) : null,
                    ),
                    child: _avatarBase64 == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, color: AppColors.accent, size: 32),
                              const SizedBox(height: 2),
                              const Text('Фото', style: TextStyle(color: AppColors.accent, fontSize: 10)),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
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
                        const SizedBox(height: 12),
                        VTextField(
                          controller: _categoryCtrl,
                          hint: 'Тема (напр. Игры, Музыка, Спорт)',
                          prefixIcon: const Icon(Icons.category_rounded, color: AppColors.textHint, size: 20),
                        ),
                        const SizedBox(height: 16),
                        // Region selector
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Регион *', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  const Text('Чтобы люди знали откуда участники', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _regions.where((r) => r['code']!.isNotEmpty).map((r) {
                                      final selected = _region == r['code'];
                                      return GestureDetector(
                                        onTap: () => setState(() => _region = r['code']!),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: selected ? AppColors.accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: selected ? AppColors.accent : Colors.white.withValues(alpha: 0.1)),
                                          ),
                                          child: Text(r['label']!, style: TextStyle(color: selected ? AppColors.accent : AppColors.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, fontSize: 13)),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Сообщество — это место где люди могут создавать группы на общую тему. '
                                      'Все пользователи могут вступить и создавать подгруппы.',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],

                      if (widget.isChannel) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.15)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.campaign_rounded, color: Colors.deepPurple, size: 18),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Канал — только вы и назначенные вами пользователи могут публиковать сообщения. '
                                      'Остальные подписчики могут только читать.',
                                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

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
