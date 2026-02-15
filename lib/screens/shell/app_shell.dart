import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../services/admin_service.dart';
import '../contacts/contact_list_screen.dart';
import '../chat/chat_list_screen.dart';
import '../history/call_history_screen.dart';
import '../profile/profile_screen.dart';
import '../groups/group_list_screen.dart';
import '../admin/admin_panel_screen.dart';
import '../whats_new/whats_new_screen.dart';

/// Current app version — increment when releasing updates.
const String _appVersion = '1.8.0';

/// Main shell with bottom navigation — premium tab bar + update banner.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;
  bool _isAdmin = false;

  final _pages = const [
    ContactListScreen(),
    ChatListScreen(),
    GroupListScreen(),
    CallHistoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentUserProvider.notifier).loadUser();
      // Show "What's New" if user hasn't seen this version yet
      showWhatsNewIfNeeded(context, _appVersion);
      _checkAdmin();
      _recordInstall();
    });
  }

  Future<void> _checkAdmin() async {
    final uid = ref.read(authServiceProvider).effectiveUid;
    if (uid.isEmpty) return;
    final isAdmin = await AdminService().isAdminUid(uid);
    if (isAdmin && mounted) setState(() => _isAdmin = true);
  }

  Future<void> _recordInstall() async {
    final uid = ref.read(authServiceProvider).effectiveUid;
    if (uid.isEmpty) return;
    final platform = Platform.isAndroid ? 'android' : 'macos';
    await AdminService().recordInstall(uid, platform);
  }

  @override
  Widget build(BuildContext context) {
    // Sync contacts from stream
    ref.listen<AsyncValue<List>>(contactsStreamProvider, (_, next) {
      next.whenData((contacts) {
        ref.read(contactsProvider.notifier).setContacts(
              contacts.cast(),
            );
      });
    });

    return Scaffold(
      backgroundColor: AppColors.black,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Update Banner ────────────────
          _UpdateBanner(),

          // ─── Bottom Nav ───────────────────
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                      vertical: AppSizes.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NavItem(
                          icon: Icons.people_alt_rounded,
                          label: 'Контакты',
                          isActive: _currentIndex == 0,
                          onTap: () => setState(() => _currentIndex = 0),
                        ),
                        _NavItem(
                          icon: Icons.chat_rounded,
                          label: 'Чаты',
                          isActive: _currentIndex == 1,
                          onTap: () => setState(() => _currentIndex = 1),
                          badgeStream: FirebaseFirestore.instance
                              .collectionGroup('messages')
                              .where('senderId', isNotEqualTo: ref.read(authServiceProvider).effectiveUid)
                              .where('isRead', isEqualTo: false)
                              .snapshots(),
                        ),
                        _NavItem(
                          icon: Icons.group_rounded,
                          label: 'Группы',
                          isActive: _currentIndex == 2,
                          onTap: () => setState(() => _currentIndex = 2),
                        ),
                        _NavItem(
                          icon: Icons.history_rounded,
                          label: 'Звонки',
                          isActive: _currentIndex == 3,
                          onTap: () => setState(() => _currentIndex = 3),
                        ),
                        _NavItem(
                          icon: Icons.person_rounded,
                          label: 'Профиль',
                          isActive: _currentIndex == 4,
                          onTap: () => setState(() => _currentIndex = 4),
                        ),
                        if (_isAdmin)
                          _NavItem(
                            icon: Icons.admin_panel_settings_rounded,
                            label: 'Админ',
                            isActive: false,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminPanelScreen(),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Update Banner ───────────────────────────────────────

class _UpdateBanner extends StatefulWidget {
  @override
  State<_UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<_UpdateBanner> {
  bool _downloading = false;
  double _progress = 0;
  String _statusText = '';

  /// Compare two semantic versions. Returns true if [remote] > [local].
  static bool _isNewerVersion(String remote, String local) {
    final rParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final lParts = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final r = i < rParts.length ? rParts[i] : 0;
      final l = i < lParts.length ? lParts[i] : 0;
      if (r > l) return true;
      if (r < l) return false;
    }
    return false; // equal
  }

  /// Extract Google Drive file ID from any GDrive URL format.
  String? _extractGDriveId(String url) {
    // /file/d/ID/...
    var m = RegExp(r'drive\.google\.com/file/d/([^/]+)').firstMatch(url);
    if (m != null) return m.group(1);
    // open?id=ID
    m = RegExp(r'drive\.google\.com/open\?id=([^&]+)').firstMatch(url);
    if (m != null) return m.group(1);
    // uc?...id=ID
    m = RegExp(r'drive\.google\.com/uc\?.*id=([^&]+)').firstMatch(url);
    if (m != null) return m.group(1);
    return null;
  }

  /// Download file from Google Drive handling the virus-scan confirm page.
  Future<File?> _downloadGDrive(String fileId, String savePath) async {
    final client = HttpClient();
    client.badCertificateCallback = (_, __, ___) => true;
    String cookies = '';

    // Step 1: initial request — Google may return HTML confirm page
    var uri = Uri.parse(
        'https://drive.google.com/uc?export=download&id=$fileId');

    for (int attempt = 0; attempt < 3; attempt++) {
      final req = await client.getUrl(uri);
      req.followRedirects = true;
      req.maxRedirects = 10;
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36');
      if (cookies.isNotEmpty) {
        req.headers.set('Cookie', cookies);
      }

      final resp = await req.close();

      // Collect cookies
      final setCookies = resp.headers[HttpHeaders.setCookieHeader] ?? [];
      for (final c in setCookies) {
        final name = c.split(';').first;
        cookies = cookies.isEmpty ? name : '$cookies; $name';
      }

      // Check content type — if HTML, parse for confirm token
      final contentType = resp.headers.contentType?.mimeType ?? '';
      if (contentType.contains('html') || contentType.contains('text')) {
        final html = await resp.transform(utf8.decoder).join();
        // Look for confirm link or UUID token
        final confirmMatch =
            RegExp(r'confirm=([0-9A-Za-z_-]+)').firstMatch(html);
        final uuidMatch =
            RegExp(r'uuid=([0-9a-f-]+)').firstMatch(html);

        if (confirmMatch != null) {
          uri = Uri.parse(
              'https://drive.google.com/uc?export=download&confirm=${confirmMatch.group(1)}&id=$fileId');
          continue;
        } else if (uuidMatch != null) {
          uri = Uri.parse(
              'https://drive.google.com/uc?export=download&confirm=t&uuid=${uuidMatch.group(1)}&id=$fileId');
          continue;
        }
        // Can't parse confirm page
        client.close();
        return null;
      }

      // It's a binary file — download it
      final totalBytes = resp.contentLength;
      int receivedBytes = 0;
      final file = File(savePath);
      // Ensure parent directory exists
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
      final sink = file.openWrite();

      await for (final chunk in resp) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() => _progress = receivedBytes / totalBytes);
        }
      }
      await sink.close();
      client.close();
      return file;
    }

    client.close();
    return null;
  }

  /// Download file from a direct URL (non-GDrive).
  Future<File?> _downloadDirect(String url, String savePath) async {
    final client = HttpClient();
    client.badCertificateCallback = (_, __, ___) => true;
    final req = await client.getUrl(Uri.parse(url));
    req.followRedirects = true;
    req.maxRedirects = 10;
    req.headers.set('User-Agent',
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36');

    final resp = await req.close();
    if (resp.statusCode != 200) {
      client.close();
      return null;
    }

    final totalBytes = resp.contentLength;
    int receivedBytes = 0;
    final file = File(savePath);
    // Ensure parent directory exists
    final parentDir = file.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }
    final sink = file.openWrite();

    await for (final chunk in resp) {
      sink.add(chunk);
      receivedBytes += chunk.length;
      if (totalBytes > 0 && mounted) {
        setState(() => _progress = receivedBytes / totalBytes);
      }
    }
    await sink.close();
    client.close();
    return file;
  }

  /// macOS self-update: write an external updater script to /tmp,
  /// launch it detached (outside sandbox), then exit.
  /// The script: mounts DMG → copies .app → unmounts → relaunches.
  Future<void> _installMacOS(String dmgPath) async {
    try {
      if (mounted) setState(() => _statusText = 'Подготовка установки...');

      // Determine where the current app bundle lives
      final currentExe = Platform.resolvedExecutable;
      final appBundleMatch = RegExp(r'(.+\.app)/').firstMatch(currentExe);
      final destApp = appBundleMatch?.group(1) ?? '/Applications/Vizo.app';
      final appName = destApp.split('/').last; // "Vizo.app" or similar

      // Write an updater shell script to /tmp (outside sandbox)
      final script = '''#!/bin/bash
# Vizo auto-updater — runs outside the sandbox
DEST="$destApp"
DMG="$dmgPath"
APP_NAME="$appName"

# Wait for the old app to quit
sleep 1

# Mount DMG
MOUNT_OUT=\$(hdiutil attach "\$DMG" -nobrowse -quiet 2>&1)
if [ \$? -ne 0 ]; then
  # Fallback: try without -quiet
  MOUNT_OUT=\$(hdiutil attach "\$DMG" -nobrowse 2>&1)
fi

# Find mount point
MOUNT_POINT=\$(echo "\$MOUNT_OUT" | grep -o '/Volumes/[^"]*' | tail -1)
if [ -z "\$MOUNT_POINT" ]; then
  # Try listing /Volumes for recently mounted
  sleep 1
  MOUNT_POINT=\$(ls -dt /Volumes/*/ 2>/dev/null | head -1)
fi

if [ -z "\$MOUNT_POINT" ]; then
  osascript -e 'display notification "Не удалось смонтировать DMG" with title "Vizo Update"'
  rm -f "\$DMG"
  exit 1
fi

# Find .app in the mounted volume
SRC_APP=\$(find "\$MOUNT_POINT" -maxdepth 1 -name "*.app" -type d | head -1)
if [ -z "\$SRC_APP" ]; then
  hdiutil detach "\$MOUNT_POINT" -quiet 2>/dev/null
  osascript -e 'display notification "Приложение не найдено в DMG" with title "Vizo Update"'
  rm -f "\$DMG"
  exit 1
fi

# Remove old app and copy new one
rm -rf "\$DEST"
cp -R "\$SRC_APP" "\$DEST"

# Unmount
hdiutil detach "\$MOUNT_POINT" -quiet 2>/dev/null

# Clean up DMG and this script
rm -f "\$DMG"
rm -f /tmp/vizo_updater.sh

# Relaunch
open "\$DEST"
''';

      final scriptFile = File('/tmp/vizo_updater.sh');
      await scriptFile.writeAsString(script);

      // Make executable
      await Process.run('chmod', ['+x', '/tmp/vizo_updater.sh']);

      if (mounted) setState(() => _statusText = 'Перезапуск...');

      // Launch the script detached (runs outside sandbox)
      await Process.start(
        '/bin/bash',
        ['/tmp/vizo_updater.sh'],
        mode: ProcessStartMode.detached,
      );

      // Give the script a moment to start, then quit this app
      await Future.delayed(const Duration(milliseconds: 300));
      exit(0);
    } catch (e) {
      debugPrint('macOS install error: $e');
      if (mounted) {
        setState(() {
          _downloading = false;
          _statusText = 'Ошибка установки: $e';
        });
      }
    }
  }

  Future<void> _doUpdate(String rawUrl) async {
    if (_downloading || rawUrl.isEmpty) return;

    setState(() {
      _downloading = true;
      _progress = 0;
      _statusText = 'Подготовка...';
    });

    try {
      final isAndroid = Platform.isAndroid;
      final ext = isAndroid ? 'apk' : 'dmg';

      // Use application support dir on macOS (more reliable in sandbox),
      // temp dir on other platforms.
      final dir = Platform.isMacOS
          ? await getApplicationSupportDirectory()
          : await getTemporaryDirectory();

      // Ensure directory actually exists (macOS sandbox may not create it)
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final savePath = '${dir.path}/vizo_update.$ext';

      // Delete old file
      final oldFile = File(savePath);
      if (await oldFile.exists()) await oldFile.delete();

      if (mounted) setState(() => _statusText = 'Скачивание...');

      // Download
      File? file;
      final gdriveId = _extractGDriveId(rawUrl);
      if (gdriveId != null) {
        file = await _downloadGDrive(gdriveId, savePath);
      } else {
        file = await _downloadDirect(rawUrl, savePath);
      }

      if (file == null || !await file.exists()) {
        if (mounted) {
          setState(() {
            _downloading = false;
            _statusText = 'Ошибка скачивания. Попробуйте ещё раз.';
          });
        }
        return;
      }

      // Verify it's not an HTML page
      final size = await file.length();
      if (size < 1000000) {
        // < 1MB — not a real APK/DMG
        await file.delete();
        if (mounted) {
          setState(() {
            _downloading = false;
            _statusText = 'Ошибка: файл повреждён. Попробуйте позже.';
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _statusText = 'Установка...';
        });
      }

      if (Platform.isMacOS) {
        await _installMacOS(savePath);
      } else {
        // Android — open APK for install
        final result = await OpenFilex.open(savePath);
        if (result.type != ResultType.done && mounted) {
          setState(() {
            _downloading = false;
            _statusText = 'Не удалось открыть файл: ${result.message}';
          });
        }
      }
    } catch (e) {
      debugPrint('Update error: $e');
      if (mounted) {
        setState(() {
          _downloading = false;
          _statusText = 'Ошибка: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('app_config')
          .doc('version')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final latestVersion = data?['latest'] as String? ?? _appVersion;
        final updateUrl = Platform.isAndroid
            ? (data?['apkUrl'] as String? ?? '')
            : (data?['dmgUrl'] as String? ?? '');

        // Compare versions properly — only show banner when remote > local
        if (updateUrl.isEmpty || !_isNewerVersion(latestVersion, _appVersion)) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => _doUpdate(updateUrl),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.4),
                  AppColors.accentLight.withValues(alpha: 0.3),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: _downloading
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _progress > 0 && _progress < 1.0
                                ? 'Скачивание ${(_progress * 100).toInt()}%'
                                : _statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          backgroundColor: Colors.white24,
                          color: Colors.white,
                          minHeight: 3,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.system_update_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusText.isNotEmpty
                              ? _statusText
                              : 'Обновление v$latestVersion доступно! Нажмите для обновления',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Icon(Icons.download_rounded,
                          color: Colors.white, size: 18),
                    ],
                  ),
          ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Nav Item ────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeStream,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Stream<QuerySnapshot>? badgeStream;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppSizes.animFast,
    );
    _scale = Tween(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: AppSizes.animNormal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.accent.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
            border: widget.isActive
                ? Border.all(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    width: 0.5,
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.badgeStream != null
                  ? StreamBuilder<QuerySnapshot>(
                      stream: widget.badgeStream,
                      builder: (_, snap) {
                        final count = snap.data?.docs.length ?? 0;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedSwitcher(
                              duration: AppSizes.animNormal,
                              child: Icon(
                                widget.icon,
                                key: ValueKey(widget.isActive),
                                color: widget.isActive
                                    ? AppColors.accent
                                    : AppColors.textHint,
                                size: 24,
                              ),
                            ),
                            if (count > 0)
                              Positioned(
                                top: -4,
                                right: -8,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                      minWidth: 16, minHeight: 16),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    )
                  : AnimatedSwitcher(
                      duration: AppSizes.animNormal,
                      child: Icon(
                        widget.icon,
                        key: ValueKey(widget.isActive),
                        color: widget.isActive
                            ? AppColors.accent
                            : AppColors.textHint,
                        size: 24,
                      ),
                    ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: AppSizes.animNormal,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      widget.isActive ? FontWeight.w600 : FontWeight.w400,
                  color: widget.isActive
                      ? AppColors.accent
                      : AppColors.textHint,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
