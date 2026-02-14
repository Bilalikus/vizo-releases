import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'blocked_users_screen.dart';
import 'chat_wallpaper_screen.dart';
import 'quick_replies_screen.dart';
import 'chat_folders_screen.dart';

/// App‑wide settings — notifications, privacy, appearance, storage.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _readReceipts = true;
  bool _lastSeenVisible = true;
  bool _typingIndicator = true;
  bool _dndEnabled = false;
  bool _linkPreview = true;
  int _disappearingMinutes = 0; // 0 = off
  int _fontSizeIndex = 1; // 0=small 1=normal 2=large
  int _bubbleStyleIndex = 0; // 0=rounded 1=sharp 2=minimal

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = p.getBool('pref_notifications') ?? true;
      _readReceipts = p.getBool('pref_read_receipts') ?? true;
      _lastSeenVisible = p.getBool('pref_last_seen') ?? true;
      _typingIndicator = p.getBool('pref_typing') ?? true;
      _dndEnabled = p.getBool('pref_dnd') ?? false;
      _linkPreview = p.getBool('pref_link_preview') ?? true;
      _disappearingMinutes = p.getInt('pref_disappear') ?? 0;
      _fontSizeIndex = p.getInt('pref_font_size') ?? 1;
      _bubbleStyleIndex = p.getInt('pref_bubble_style') ?? 0;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }

  Future<void> _saveInt(String key, int value) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(key, value);
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        ),
        title: const Text('Удалить аккаунт?',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: const Text(
          'Все данные будут удалены безвозвратно:\nконтакты, чаты, история звонков.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final auth = ref.read(authServiceProvider);
    final uid = auth.effectiveUid;

    // Delete user doc, sign out
    try {
      final fs = ref.read(firestoreServiceProvider);
      await fs.deleteUserData(uid);
      await auth.signOut();
      ref.read(desktopSignedInProvider.notifier).state = false;
      ref.read(currentUserProvider.notifier).clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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
              title: const Text('Настройки',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Notifications ──
          _SectionHeader(title: 'Уведомления'),
          _ToggleTile(
            icon: Icons.notifications_rounded,
            label: 'Push-уведомления',
            value: _notificationsEnabled,
            onChanged: (v) {
              setState(() => _notificationsEnabled = v);
              _saveBool('pref_notifications', v);
            },
          ),
          _ToggleTile(
            icon: Icons.do_not_disturb_on_rounded,
            label: 'Не беспокоить',
            value: _dndEnabled,
            onChanged: (v) {
              setState(() => _dndEnabled = v);
              _saveBool('pref_dnd', v);
            },
          ),

          const SizedBox(height: 20),
          _SectionHeader(title: 'Конфиденциальность'),
          _ToggleTile(
            icon: Icons.done_all_rounded,
            label: 'Галочки прочитано',
            value: _readReceipts,
            onChanged: (v) {
              setState(() => _readReceipts = v);
              _saveBool('pref_read_receipts', v);
            },
          ),
          _ToggleTile(
            icon: Icons.visibility_rounded,
            label: 'Показывать «был(а) в сети»',
            value: _lastSeenVisible,
            onChanged: (v) {
              setState(() => _lastSeenVisible = v);
              _saveBool('pref_last_seen', v);
            },
          ),
          _ToggleTile(
            icon: Icons.keyboard_rounded,
            label: 'Индикатор набора',
            value: _typingIndicator,
            onChanged: (v) {
              setState(() => _typingIndicator = v);
              _saveBool('pref_typing', v);
            },
          ),
          const SizedBox(height: 4),
          _NavTile(
            icon: Icons.block_rounded,
            label: 'Заблокированные',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BlockedUsersScreen())),
          ),

          const SizedBox(height: 20),
          _SectionHeader(title: 'Исчезающие сообщения'),
          _DropdownTile(
            icon: Icons.timer_rounded,
            label: 'Авто-удаление',
            value: _disappearingMinutes,
            items: const {
              0: 'Выкл',
              5: '5 минут',
              60: '1 час',
              1440: '24 часа',
              10080: '7 дней',
            },
            onChanged: (v) {
              setState(() => _disappearingMinutes = v);
              _saveInt('pref_disappear', v);
            },
          ),

          const SizedBox(height: 20),
          _SectionHeader(title: 'Внешний вид'),
          _DropdownTile(
            icon: Icons.text_fields_rounded,
            label: 'Размер шрифта',
            value: _fontSizeIndex,
            items: const {0: 'Мелкий', 1: 'Обычный', 2: 'Крупный'},
            onChanged: (v) {
              setState(() => _fontSizeIndex = v);
              _saveInt('pref_font_size', v);
            },
          ),
          _DropdownTile(
            icon: Icons.chat_bubble_rounded,
            label: 'Стиль пузырей',
            value: _bubbleStyleIndex,
            items: const {0: 'Скруглённый', 1: 'Острый', 2: 'Минимал'},
            onChanged: (v) {
              setState(() => _bubbleStyleIndex = v);
              _saveInt('pref_bubble_style', v);
            },
          ),
          _ToggleTile(
            icon: Icons.link_rounded,
            label: 'Превью ссылок',
            value: _linkPreview,
            onChanged: (v) {
              setState(() => _linkPreview = v);
              _saveBool('pref_link_preview', v);
            },
          ),
          _NavTile(
            icon: Icons.wallpaper_rounded,
            label: 'Обои чата',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ChatWallpaperScreen())),
          ),

          const SizedBox(height: 20),
          _SectionHeader(title: 'Чаты'),
          _NavTile(
            icon: Icons.flash_on_rounded,
            label: 'Быстрые ответы',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const QuickRepliesScreen())),
          ),
          _NavTile(
            icon: Icons.folder_rounded,
            label: 'Папки чатов',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ChatFoldersScreen())),
          ),

          const SizedBox(height: 32),
          _SectionHeader(title: 'Аккаунт'),
          _DangerTile(
            icon: Icons.delete_forever_rounded,
            label: 'Удалить аккаунт',
            onTap: _confirmDeleteAccount,
          ),

          const SizedBox(height: 40),
          Center(
            child: Text(
              'Vizo v1.7.0 • E2E Encrypted',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint.withValues(alpha: 0.35),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── Reusable tiles ──────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.accent.withValues(alpha: 0.7),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: VCard(
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textPrimary)),
            ),
            Switch.adaptive(
              value: value,
              activeTrackColor: AppColors.accent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: VCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textPrimary)),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: VCard(
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textPrimary)),
            ),
            DropdownButton<T>(
              value: value,
              dropdownColor: AppColors.surfaceLight,
              underline: const SizedBox.shrink(),
              style: const TextStyle(
                  fontSize: 14, color: AppColors.accentLight),
              icon: const Icon(Icons.expand_more_rounded,
                  size: 18, color: AppColors.textHint),
              items: items.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerTile extends StatelessWidget {
  const _DangerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.error,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
