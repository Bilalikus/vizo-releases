import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Contact notes — private notes about a contact.
class ContactNotesScreen extends ConsumerStatefulWidget {
  const ContactNotesScreen({super.key, required this.contact});

  final ContactModel contact;

  @override
  ConsumerState<ContactNotesScreen> createState() =>
      _ContactNotesScreenState();
}

class _ContactNotesScreenState extends ConsumerState<ContactNotesScreen> {
  late final TextEditingController _ctrl;
  bool _hasChanges = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.contact.notes ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final notifier = ref.read(contactsProvider.notifier);
      await notifier.updateContact(
        widget.contact.copyWith(notes: _ctrl.text.trim()),
      );
      if (mounted) {
        setState(() {
          _hasChanges = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Заметка сохранена'),
            backgroundColor: AppColors.accent.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
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
              title: Column(
                children: [
                  Text('Заметки о ${widget.contact.name}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text('Видны только вам',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint.withValues(alpha: 0.5))),
                ],
              ),
              centerTitle: true,
              actions: [
                if (_hasChanges)
                  IconButton(
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.accent))
                        : const Icon(Icons.check_rounded,
                            color: AppColors.accent, size: 24),
                    onPressed: _saving ? null : _save,
                  ),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ─── Contact info ──────
            VCard(
              child: Row(
                children: [
                  VAvatar(
                    name: widget.contact.name,
                    imageUrl: widget.contact.avatarUrl,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.contact.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        Text(widget.contact.phoneNumber,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Notes editor ──────
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: TextField(
                  controller: _ctrl,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText:
                        'Запишите приватные заметки о ${widget.contact.name}...\n\nНапример:\n• День рождения: 15 марта\n• Любит кофе\n• Работает в IT',
                    hintStyle: TextStyle(
                        color: AppColors.textHint.withValues(alpha: 0.4),
                        fontSize: 14),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) {
                    if (!_hasChanges) setState(() => _hasChanges = true);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
