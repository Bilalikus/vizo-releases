import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Add / edit contact — premium with phone check and tags.
class ContactEditorScreen extends ConsumerStatefulWidget {
  const ContactEditorScreen({super.key, this.contact});

  /// Existing contact to edit — `null` for "add".
  final ContactModel? contact;

  @override
  ConsumerState<ContactEditorScreen> createState() =>
      _ContactEditorScreenState();
}

class _ContactEditorScreenState extends ConsumerState<ContactEditorScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: '+7');
  final _descCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _tags = <String>[];
  bool _loading = false;
  bool? _isRegistered;

  bool get _isEditing => widget.contact != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.contact!;
      _nameCtrl.text = c.name;
      _descCtrl.text = c.description;
      _tags.addAll(c.tags);

      // Parse country code from stored E.164
      final phone = c.phoneNumber;
      if (phone.startsWith('+')) {
        // Try to split off country code: assume 1-3 digit codes
        // Simple heuristic: +7XXX... → +7 / rest
        if (phone.length > 2) {
          // Find the country code length (1-3 digits after +)
          int ccLen = 1;
          if (phone.length >= 3 &&
              !RegExp(r'^[0-9]').hasMatch(phone.substring(2, 3))) {
            ccLen = 1;
          } else if (phone.length >= 4 &&
              phone.startsWith('+7')) {
            ccLen = 1;
          } else if (phone.startsWith('+1')) {
            ccLen = 1;
          } else {
            ccLen = 2;
          }
          _countryCtrl.text = phone.substring(0, ccLen + 1);
          final rest = phone.substring(ccLen + 1);
          _phoneCtrl.text = _applyMask(rest);
        }
      } else {
        _phoneCtrl.text = phone;
      }
    }
    _phoneCtrl.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneCtrl.removeListener(_onPhoneChanged);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _countryCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  // ─── Phone mask: XXX-XXX-XX-XX ────────────────────

  void _onPhoneChanged() {
    final raw = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = _applyMask(raw);
    if (formatted != _phoneCtrl.text) {
      _phoneCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    // Reset registration check on change
    if (_isRegistered != null) {
      setState(() => _isRegistered = null);
    }
  }

  String _applyMask(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 10; i++) {
      if (i == 3 || i == 6 || i == 8) buf.write('-');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  String get _fullPhoneNumber {
    final country = _countryCtrl.text.trim();
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return '$country$phone';
  }

  Future<void> _checkRegistered() async {
    final phone = _fullPhoneNumber;
    if (phone.length < 8) return;

    setState(() => _loading = true);
    final firestoreService = ref.read(firestoreServiceProvider);
    final user = await firestoreService.findUserByPhone(phone);
    if (!mounted) return;
    setState(() {
      _isRegistered = user != null;
      _loading = false;
    });
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagCtrl.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _fullPhoneNumber;
    if (name.isEmpty || phone.length < 8) return;

    setState(() => _loading = true);

    try {
      final notifier = ref.read(contactsProvider.notifier);

      if (_isEditing) {
        await notifier.updateContact(
          widget.contact!.copyWith(
            name: name,
            phoneNumber: phone,
            description: _descCtrl.text.trim(),
            tags: _tags,
          ),
        );
      } else {
        await notifier.addContact(
          ContactModel(
            id: '',
            ownerUid: '',
            name: name,
            phoneNumber: phone,
            description: _descCtrl.text.trim(),
            tags: _tags,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEditing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: const Text('Удалить контакт?'),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        content: Text(
          'Контакт "${widget.contact!.name}" будет удалён.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Удалить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    await ref.read(contactsProvider.notifier).deleteContact(widget.contact!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(_isEditing ? 'Контакт' : 'Новый контакт'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Name ─────────────────────
            VTextField(
              controller: _nameCtrl,
              hint: 'Имя',
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  color: AppColors.textHint, size: 20),
            ),

            const SizedBox(height: AppSizes.md),

            // ─── Phone ────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  child: VTextField(
                    controller: _countryCtrl,
                    hint: '+7',
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[+0-9]')),
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: VTextField(
                    controller: _phoneCtrl,
                    hint: '999-123-45-67',
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                      LengthLimitingTextInputFormatter(13),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                // Check button
                SizedBox(
                  height: AppSizes.buttonHeight,
                  child: VIconButton(
                    icon: Icons.verified_user_outlined,
                    onPressed: _checkRegistered,
                    color: _isRegistered == true
                        ? AppColors.success
                        : _isRegistered == false
                            ? AppColors.warning
                            : AppColors.accent,
                    tooltip: 'Проверить в Vizo',
                  ),
                ),
              ],
            ),

            // ─── Registration status ──────
            if (_isRegistered != null) ...[
              const SizedBox(height: AppSizes.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md, vertical: AppSizes.sm),
                decoration: BoxDecoration(
                  color: (_isRegistered!
                          ? AppColors.success
                          : AppColors.warning)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isRegistered!
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color: _isRegistered!
                          ? AppColors.success
                          : AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Text(
                      _isRegistered!
                          ? 'Зарегистрирован в Vizo'
                          : 'Не найден в Vizo',
                      style: TextStyle(
                        fontSize: 13,
                        color: _isRegistered!
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSizes.md),

            // ─── Description ──────────────
            VTextField(
              controller: _descCtrl,
              hint: 'Описание (необязательно)',
              maxLines: 3,
              prefixIcon: const Icon(Icons.notes_rounded,
                  color: AppColors.textHint, size: 20),
            ),

            const SizedBox(height: AppSizes.md),

            // ─── Tags ─────────────────────
            Row(
              children: [
                Expanded(
                  child: VTextField(
                    controller: _tagCtrl,
                    hint: 'Тег',
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                VIconButton(
                  icon: Icons.add_rounded,
                  onPressed: _addTag,
                  tooltip: 'Добавить тег',
                ),
              ],
            ),

            if (_tags.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(tag,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.accentLight,
                        )),
                    backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                    deleteIconColor: AppColors.accentLight,
                    onDeleted: () => _removeTag(tag),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusSmall),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: AppSizes.xl),

            // ─── Save button ──────────────
            VButton(
              label: _isEditing ? 'Сохранить' : 'Добавить',
              onPressed: !_loading ? _save : null,
              isLoading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
