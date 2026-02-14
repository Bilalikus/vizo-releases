import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Profile setup screen — shown after OTP verification for new users.
/// Collects name, avatar, and optional status.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  bool _loading = false;
  String? _avatarUrl;
  String? _localAvatarPath;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _statusCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image == null) return;
    setState(() => _localAvatarPath = image.path);
  }

  Future<void> _complete() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите имя')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final storageService = ref.read(storageServiceProvider);
      final uid = authService.effectiveUid;

      // Upload avatar if selected
      if (_localAvatarPath != null) {
        try {
          _avatarUrl = await storageService.uploadAvatar(
            uid: uid,
            file: File(_localAvatarPath!),
          );
        } catch (e) {
          debugPrint('Avatar upload failed: $e');
          // Continue without avatar — not critical
        }
      }

      // Update profile
      await ref.read(currentUserProvider.notifier).updateProfile(
            displayName: name,
            status: _statusCtrl.text.trim(),
            avatarBase64: _avatarUrl,
          );

      if (!mounted) return;

      // Set signed-in flag → triggers navigation to AppShell
      ref.read(desktopSignedInProvider.notifier).state = true;

      // Pop all auth screens
      Navigator.of(context).popUntil((route) => route.isFirst);
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
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: FadeTransition(
            opacity: _fade,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 40),

                  // ─── Title ──────────────────
                  const Text(
                    'Настройка профиля',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Заполните данные для начала работы',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),

                  const SizedBox(height: AppSizes.xl),

                  // ─── Avatar picker ──────────
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        if (_localAvatarPath != null)
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.accentGradient,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: ClipOval(
                              child: Image.file(
                                File(_localAvatarPath!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surface,
                              border: Border.all(
                                color: AppColors.divider,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.textHint,
                              size: 48,
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.black,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Нажмите чтобы выбрать фото',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint.withValues(alpha: 0.6),
                    ),
                  ),

                  const SizedBox(height: AppSizes.xl),

                  // ─── Phone (read-only) ──────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppSizes.radiusDefault),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_rounded,
                            color: AppColors.textHint, size: 20),
                        const SizedBox(width: AppSizes.sm),
                        Text(
                          user.phoneNumber,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSizes.md),

                  // ─── Name ───────────────────
                  VTextField(
                    controller: _nameCtrl,
                    hint: 'Ваше имя',
                    prefixIcon: const Icon(Icons.person_outline_rounded,
                        color: AppColors.textHint, size: 20),
                  ),

                  const SizedBox(height: AppSizes.md),

                  // ─── Status ─────────────────
                  VTextField(
                    controller: _statusCtrl,
                    hint: 'Статус (необязательно)',
                    prefixIcon: const Icon(Icons.edit_note_rounded,
                        color: AppColors.textHint, size: 20),
                  ),

                  const SizedBox(height: AppSizes.lg),

                  // ─── Continue button ────────
                  VButton(
                    label: 'Продолжить',
                    onPressed: !_loading ? _complete : null,
                    isLoading: _loading,
                  ),

                  const SizedBox(height: AppSizes.md),

                  // ─── Skip ───────────────────
                  TextButton(
                    onPressed: !_loading
                        ? () {
                            // Skip profile setup — go straight to app
                            // Save a default name
                            ref
                                .read(currentUserProvider.notifier)
                                .updateProfile(displayName: user.phoneNumber);
                            ref.read(desktopSignedInProvider.notifier).state =
                                true;
                            Navigator.of(context)
                                .popUntil((route) => route.isFirst);
                          }
                        : null,
                    child: Text(
                      'Пропустить',
                      style: TextStyle(
                        color: AppColors.textHint.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
