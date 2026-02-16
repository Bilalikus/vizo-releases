import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../settings/settings_screen.dart';
import '../settings/app_lock_screen.dart';
import '../settings/storage_data_screen.dart';
import '../chat/saved_messages_screen.dart';
import '../chat/archived_chats_screen.dart';
import '../stories/stories_screen.dart';
import 'profile_qr_screen.dart';
import 'app_stats_screen.dart';

/// Profile screen — premium, with avatar upload and sign out.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  bool _loading = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  void _loadProfile() {
    final user = ref.read(currentUserProvider);
    _nameCtrl.text = user.displayName;
    _statusCtrl.text = user.status;
  }

  Future<void> _saveProfile() async {
    setState(() => _loading = true);

    try {
      await ref.read(currentUserProvider.notifier).updateProfile(
            displayName: _nameCtrl.text.trim(),
            status: _statusCtrl.text.trim(),
          );
      if (mounted) {
        setState(() {
          _loading = false;
          _hasChanges = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль обновлён')),
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

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() => _loading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final storageService = ref.read(storageServiceProvider);

      final url = await storageService.uploadAvatar(
        uid: authService.effectiveUid,
        file: File(image.path),
      );

      await ref.read(currentUserProvider.notifier).updateProfile(
            avatarBase64: url,
          );

      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото обновлено')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: const Text('Выйти из аккаунта?'),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
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
                const Text('Выйти', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final authService = ref.read(authServiceProvider);
    await authService.signOut();

    // Reset signed-in flag
    ref.read(desktopSignedInProvider.notifier).state = false;

    ref.read(currentUserProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: CustomScrollView(
        slivers: [
          // ─── Header ─────────────────────────
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.sm),
                child: const Text(
                  'Профиль',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ),
          ),

          // ─── Quick Actions Row ──────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileAction(
                          icon: Icons.bookmark_rounded,
                          label: 'Заметки',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SavedMessagesScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: _ProfileAction(
                          icon: Icons.settings_rounded,
                          label: 'Настройки',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileAction(
                          icon: Icons.qr_code_rounded,
                          label: 'QR-код',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileQrScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: _ProfileAction(
                          icon: Icons.bar_chart_rounded,
                          label: 'Статистика',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AppStatsScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileAction(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Моменты',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const StoriesScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: _ProfileAction(
                          icon: Icons.archive_rounded,
                          label: 'Архив',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ArchivedChatsScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileAction(
                          icon: Icons.lock_rounded,
                          label: 'Блокировка',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AppLockScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: _ProfileAction(
                          icon: Icons.storage_rounded,
                          label: 'Хранилище',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const StorageDataScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Column(
                children: [
                  // ─── Avatar ─────────────────
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        VAvatar(
                          imageUrl: user.effectiveAvatar,
                          name: user.displayName.isNotEmpty
                              ? user.displayName
                              : user.phoneNumber,
                          radius: 50,
                          showGlow: true,
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

                  const SizedBox(height: AppSizes.sm),

                  // ─── Phone ──────────────────
                  Text(
                    user.phoneNumber,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),

                  const SizedBox(height: AppSizes.xl),

                  // ─── Name ───────────────────
                  VTextField(
                    controller: _nameCtrl,
                    hint: 'Имя',
                    prefixIcon: const Icon(Icons.person_outline_rounded,
                        color: AppColors.textHint, size: 20),
                    onChanged: (_) {
                      if (!_hasChanges) setState(() => _hasChanges = true);
                    },
                  ),

                  const SizedBox(height: AppSizes.md),

                  // ─── Status ─────────────────
                  VTextField(
                    controller: _statusCtrl,
                    hint: 'Статус',
                    prefixIcon: const Icon(Icons.edit_note_rounded,
                        color: AppColors.textHint, size: 20),
                    onChanged: (_) {
                      if (!_hasChanges) setState(() => _hasChanges = true);
                    },
                  ),

                  const SizedBox(height: AppSizes.lg),

                  // ─── Save ───────────────────
                  AnimatedOpacity(
                    opacity: _hasChanges ? 1.0 : 0.4,
                    duration: AppSizes.animNormal,
                    child: VButton(
                      label: 'Сохранить',
                      onPressed:
                          _hasChanges && !_loading ? _saveProfile : null,
                      isLoading: _loading,
                    ),
                  ),

                  const SizedBox(height: AppSizes.xxl),

                  // ─── Sign Out ───────────────
                  _SignOutButton(onPressed: _signOut),

                  const SizedBox(height: AppSizes.lg),

                  // ─── App info ───────────────
                  Text(
                    'Vizo • E2E Encrypted Calls',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sign Out Button ─────────────────────────────────────

class _SignOutButton extends StatefulWidget {
  const _SignOutButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: AppSizes.animNormal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          decoration: BoxDecoration(
            color: _hovering
                ? AppColors.error.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppSizes.radiusDefault),
            border: Border.all(
              color: _hovering
                  ? AppColors.error.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_rounded,
                  color: AppColors.error.withValues(alpha: 0.8), size: 20),
              const SizedBox(width: AppSizes.sm),
              Text(
                'Выйти из аккаунта',
                style: TextStyle(
                  color: AppColors.error.withValues(alpha: 0.8),
                  fontSize: 14,
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

// ─── Profile Quick Action ─────────────────────────────

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSizes.radiusDefault),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.accentLight),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
