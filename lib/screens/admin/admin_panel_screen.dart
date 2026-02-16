import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';
import '../../services/admin_service.dart';
import '../../widgets/widgets.dart';

/// Admin dashboard — stats, users, groups, channels, moderators, reports, audit, system.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  final _admin = AdminService();
  late TabController _tabCtrl;

  int _totalUsers = 0;
  int _onlineUsers = 0;
  int _totalChats = 0;
  int _totalGroups = 0;
  int _totalCommunities = 0;
  int _totalChannels = 0;
  int _totalBanned = 0;
  int _totalInstalls = 0;
  int _newUsersToday = 0;
  int _modCount = 0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 7, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final results = await Future.wait([
        _admin.getTotalUsers(),
        _admin.getOnlineUsers(),
        _admin.getTotalChats(),
        _admin.getTotalGroups(),
        _admin.getTotalCommunities(),
        _admin.getTotalChannels(),
        _admin.getTotalBanned(),
        _admin.getTotalInstalls(),
        _admin.getNewUsersToday(),
        _admin.getModeratorCount(),
      ]);
      if (mounted) {
        setState(() {
          _totalUsers = results[0];
          _onlineUsers = results[1];
          _totalChats = results[2];
          _totalGroups = results[3];
          _totalCommunities = results[4];
          _totalChannels = results[5];
          _totalBanned = results[6];
          _totalInstalls = results[7];
          _newUsersToday = results[8];
          _modCount = results[9];
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.sm),
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
                        const Icon(Icons.admin_panel_settings_rounded, color: AppColors.accent, size: 28),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Админ панель', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.8)),
                        ),
                        GestureDetector(
                          onTap: _loadStats,
                          child: const Icon(Icons.refresh_rounded, color: AppColors.textHint, size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _loadingStats
                        ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)))
                        : _buildStatsGrid(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                indicatorColor: AppColors.accent,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textHint,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Пользователи'),
                  Tab(text: 'Забаненные'),
                  Tab(text: 'Группы'),
                  Tab(text: 'Модераторы'),
                  Tab(text: 'Репорты'),
                  Tab(text: 'Аудит'),
                  Tab(text: 'Система'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _AllUsersTab(admin: _admin),
            _BannedUsersTab(admin: _admin),
            _GroupsTab(admin: _admin),
            _ModeratorsTab(admin: _admin),
            _ReportsTab(admin: _admin),
            _AuditTab(admin: _admin),
            _SystemTab(admin: _admin),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatCard(icon: Icons.people_rounded, label: 'Всего', value: '$_totalUsers', color: AppColors.accent),
        _StatCard(icon: Icons.circle, label: 'Онлайн', value: '$_onlineUsers', color: AppColors.success),
        _StatCard(icon: Icons.chat_rounded, label: 'Чаты', value: '$_totalChats', color: Colors.blue),
        _StatCard(icon: Icons.group_rounded, label: 'Группы', value: '$_totalGroups', color: Colors.orange),
        _StatCard(icon: Icons.public_rounded, label: 'Сообщества', value: '$_totalCommunities', color: Colors.cyan),
        _StatCard(icon: Icons.campaign_rounded, label: 'Каналы', value: '$_totalChannels', color: Colors.deepPurple),
        _StatCard(icon: Icons.block, label: 'Баны', value: '$_totalBanned', color: AppColors.error),
        _StatCard(icon: Icons.shield_rounded, label: 'Модеры', value: '$_modCount', color: Colors.teal),
        _StatCard(icon: Icons.download_rounded, label: 'Установки', value: '$_totalInstalls', color: Colors.indigo),
        _StatCard(icon: Icons.fiber_new_rounded, label: 'За 24ч', value: '$_newUsersToday', color: Colors.pink),
      ],
    );
  }
}

// ─── Stat Card ─────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: (MediaQuery.of(context).size.width - 48 - 16) / 5,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tab Bar Delegate ─────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: AppColors.black, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

// ─── All Users Tab ──────────────────────────

class _AllUsersTab extends StatelessWidget {
  const _AllUsersTab({required this.admin});
  final AdminService admin;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: admin.allUsersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
        final users = snapshot.data!;
        if (users.isEmpty) return const Center(child: Text('Нет пользователей', style: TextStyle(color: AppColors.textHint)));
        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.md),
          itemCount: users.length,
          itemBuilder: (_, i) => _UserTile(user: users[i], admin: admin),
        );
      },
    );
  }
}

// ─── Banned Users Tab ───────────────────────

class _BannedUsersTab extends StatelessWidget {
  const _BannedUsersTab({required this.admin});
  final AdminService admin;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: admin.bannedUsersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
        final banned = snapshot.data!;
        if (banned.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.success.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              const Text('Нет забаненных', style: TextStyle(color: AppColors.textHint)),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.md),
          itemCount: banned.length,
          itemBuilder: (_, i) {
            final ban = banned[i];
            final uid = ban['uid'] as String? ?? '';
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
              builder: (context, userSnap) {
                final userData = userSnap.data?.data() as Map<String, dynamic>?;
                final name = userData?['displayName'] as String? ?? userData?['phoneNumber'] as String? ?? uid;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: VCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(backgroundColor: AppColors.error, child: Icon(Icons.block, color: Colors.white)),
                      title: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      subtitle: Text('Причина: ${ban['reason'] ?? 'Не указана'}', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.undo_rounded, color: AppColors.success),
                        onPressed: () async {
                          await admin.unbanUser(uid);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Разбанен')));
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── Groups Tab ─────────────────────────────

class _GroupsTab extends StatelessWidget {
  const _GroupsTab({required this.admin});
  final AdminService admin;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: admin.allGroupsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
        final groups = snapshot.data!;
        if (groups.isEmpty) return const Center(child: Text('Нет групп', style: TextStyle(color: AppColors.textHint)));
        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.md),
          itemCount: groups.length,
          itemBuilder: (_, i) {
            final g = groups[i];
            final name = g['name'] as String? ?? 'Без названия';
            final members = (g['members'] as List?)?.length ?? 0;
            final isBanned = g['isBanned'] as bool? ?? false;
            final isPublic = g['isPublic'] as bool? ?? false;
            final id = g['id'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isBanned ? AppColors.error.withValues(alpha: 0.2) : (isPublic ? Colors.blue.withValues(alpha: 0.2) : AppColors.accent.withValues(alpha: 0.2)),
                    child: Icon(isBanned ? Icons.block : (isPublic ? Icons.public : Icons.group), color: isBanned ? AppColors.error : (isPublic ? Colors.blue : AppColors.accent)),
                  ),
                  title: Text(name, style: TextStyle(color: isBanned ? AppColors.error : AppColors.textPrimary, fontWeight: FontWeight.w600, decoration: isBanned ? TextDecoration.lineThrough : null)),
                  subtitle: Text('$members участников${isPublic ? ' • Сообщество' : ''}${isBanned ? ' • ЗАБАНЕНА' : ''}', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AppColors.textHint, size: 20),
                    color: AppColors.surfaceLight,
                    onSelected: (action) async {
                      if (action == 'ban') {
                        final result = await _showGroupBanDialog(context, name);
                        if (result != null) {
                          await admin.banGroup(id, reason: result['reason'], banAllMembers: result['banAll']);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Группа забанена')));
                        }
                      } else if (action == 'unban') {
                        await admin.unbanGroup(id);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Группа разбанена')));
                      } else if (action == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.surfaceLight,
                            title: const Text('Удалить группу?', style: TextStyle(color: AppColors.textPrimary)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена', style: TextStyle(color: AppColors.textHint))),
                              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: AppColors.error))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await admin.deleteGroup(id);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Группа удалена')));
                        }
                      } else if (action == 'freeze') {
                        await admin.freezeGroup(id);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Группа заморожена')));
                      }
                    },
                    itemBuilder: (_) => [
                      if (!isBanned)
                        const PopupMenuItem(value: 'ban', child: Row(children: [Icon(Icons.block, color: AppColors.error, size: 18), SizedBox(width: 8), Text('Забанить', style: TextStyle(color: AppColors.error))]))
                      else
                        const PopupMenuItem(value: 'unban', child: Row(children: [Icon(Icons.undo, color: AppColors.success, size: 18), SizedBox(width: 8), Text('Разбанить', style: TextStyle(color: AppColors.success))])),
                      const PopupMenuItem(value: 'freeze', child: Row(children: [Icon(Icons.ac_unit, color: Colors.blue, size: 18), SizedBox(width: 8), Text('Заморозить', style: TextStyle(color: Colors.blue))])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, color: AppColors.error, size: 18), SizedBox(width: 8), Text('Удалить', style: TextStyle(color: AppColors.error))])),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _showGroupBanDialog(BuildContext context, String groupName) async {
    final reasonCtrl = TextEditingController();
    bool banAll = false;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Забанить группу', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Причина бана (ОБЯЗАТЕЛЬНО)', hintStyle: TextStyle(color: AppColors.textHint)),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: banAll,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setSt(() => banAll = v ?? false),
                activeColor: AppColors.accent,
                title: Text('Забанить всех участников группы «$groupName»?', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: AppColors.textHint))),
            TextButton(
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Укажите причину!')));
                  return;
                }
                Navigator.pop(ctx, {'reason': reason, 'banAll': banAll});
              },
              child: const Text('Забанить', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Moderators Tab ─────────────────────────

class _ModeratorsTab extends StatelessWidget {
  const _ModeratorsTab({required this.admin});
  final AdminService admin;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: admin.moderatorsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
        final mods = snapshot.data!;
        if (mods.isEmpty) return const Center(child: Text('Нет модераторов', style: TextStyle(color: AppColors.textHint)));
        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.md),
          itemCount: mods.length,
          itemBuilder: (_, i) {
            final m = mods[i];
            final uid = m['uid'] as String? ?? '';
            final name = m['displayName'] as String? ?? m['phoneNumber'] as String? ?? uid;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.withValues(alpha: 0.2),
                    child: const Icon(Icons.shield_rounded, color: Colors.teal),
                  ),
                  title: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Модератор', style: TextStyle(color: Colors.teal, fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_remove_rounded, color: AppColors.error, size: 20),
                    onPressed: () async {
                      await admin.demoteToUser(uid);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Понижен до пользователя')));
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Reports Tab ────────────────────────────

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({required this.admin});
  final AdminService admin;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: admin.pendingReportsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
        final reports = snapshot.data!;
        if (reports.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline, size: 48, color: AppColors.success.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              const Text('Нет жалоб', style: TextStyle(color: AppColors.textHint)),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.md),
          itemCount: reports.length,
          itemBuilder: (_, i) {
            final r = reports[i];
            final id = r['id'] as String? ?? '';
            final reason = r['reason'] as String? ?? '';
            final targetUid = r['targetUid'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.report_rounded, color: Colors.white)),
                  title: Text('Жалоба на $targetUid', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(reason, style: const TextStyle(color: AppColors.textHint, fontSize: 12), maxLines: 2),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.check_rounded, color: AppColors.success, size: 22), onPressed: () async { await admin.resolveReport(id, 'Resolved'); }),
                      IconButton(icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 22), onPressed: () async { await admin.dismissReport(id); }),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Audit Tab ──────────────────────────────

class _AuditTab extends StatelessWidget {
  const _AuditTab({required this.admin});
  final AdminService admin;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: admin.auditLogStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2));
        final logs = snapshot.data!;
        if (logs.isEmpty) return const Center(child: Text('Нет записей', style: TextStyle(color: AppColors.textHint)));
        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.md),
          itemCount: logs.length,
          itemBuilder: (_, i) {
            final log = logs[i];
            final action = log['action'] as String? ?? '';
            final details = log['details'] as String? ?? '';
            final ts = (log['timestamp'] as Timestamp?)?.toDate();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: VCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(_getLogIcon(action), color: AppColors.accent, size: 20),
                  title: Text(action, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(details, style: const TextStyle(color: AppColors.textHint, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: ts != null ? Text('${ts.day}.${ts.month} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: AppColors.textHint, fontSize: 10)) : null,
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getLogIcon(String action) {
    if (action.contains('ban')) return Icons.block;
    if (action.contains('unban')) return Icons.undo;
    if (action.contains('promote')) return Icons.arrow_upward;
    if (action.contains('demote')) return Icons.arrow_downward;
    if (action.contains('delete')) return Icons.delete;
    if (action.contains('warn')) return Icons.warning;
    if (action.contains('broadcast')) return Icons.campaign;
    return Icons.info_outline;
  }
}

// ─── System Tab ─────────────────────────────

class _SystemTab extends StatefulWidget {
  const _SystemTab({required this.admin});
  final AdminService admin;

  @override
  State<_SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<_SystemTab> {
  bool _maintenance = false;
  final _broadcastCtrl = TextEditingController();
  final _minVersionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.admin.isMaintenanceMode().then((v) { if (mounted) setState(() => _maintenance = v); });
  }

  @override
  void dispose() {
    _broadcastCtrl.dispose();
    _minVersionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.lg),
      children: [
        const Text('Система', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        VCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Режим обслуживания', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Блокирует доступ для всех пользователей', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
            value: _maintenance,
            activeColor: AppColors.accent,
            onChanged: (v) async {
              await widget.admin.setMaintenanceMode(v);
              setState(() => _maintenance = v);
            },
          ),
        ),
        const SizedBox(height: 12),
        VCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Рассылка всем', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _broadcastCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Текст сообщения...', hintStyle: TextStyle(color: AppColors.textHint), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                    onPressed: () async {
                      final text = _broadcastCtrl.text.trim();
                      if (text.isEmpty) return;
                      await widget.admin.broadcastMessage(text);
                      _broadcastCtrl.clear();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Рассылка отправлена')));
                    },
                    child: const Text('Отправить', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        VCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Мин. версия приложения', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _minVersionCtrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(hintText: '1.9.0', hintStyle: TextStyle(color: AppColors.textHint), border: OutlineInputBorder()))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                      onPressed: () async {
                        final v = _minVersionCtrl.text.trim();
                        if (v.isEmpty) return;
                        await widget.admin.setMinVersion(v);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Мин. версия: $v')));
                      },
                      child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        VCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Объявление', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: widget.admin.announcementsStream(),
                  builder: (ctx, snap) {
                    final items = snap.data ?? [];
                    if (items.isEmpty) return const Text('Нет объявлений', style: TextStyle(color: AppColors.textHint, fontSize: 13));
                    return Column(
                      children: items.take(3).map((a) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(a['text'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                        trailing: IconButton(icon: const Icon(Icons.delete, color: AppColors.error, size: 18), onPressed: () => widget.admin.removeAnnouncement(a['id'])),
                      )).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── User Tile ──────────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.admin});
  final Map<String, dynamic> user;
  final AdminService admin;

  @override
  Widget build(BuildContext context) {
    final uid = user['uid'] as String? ?? '';
    final name = user['displayName'] as String? ?? user['phoneNumber'] as String? ?? '';
    final phone = user['phoneNumber'] as String? ?? '';
    final avatar = user['avatarBase64'] as String?;
    final isOnline = user['isOnline'] as bool? ?? false;
    final isBanned = user['isBanned'] as bool? ?? false;
    final role = user['role'] as String? ?? 'user';
    final createdAt = (user['createdAt'] as Timestamp?)?.toDate();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Stack(
            children: [
              VAvatar(imageUrl: avatar, name: name, radius: 20),
              if (isOnline) Positioned(bottom: 0, right: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle, border: Border.all(color: AppColors.black, width: 2)))),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(name, style: TextStyle(color: isBanned ? AppColors.error : AppColors.textPrimary, fontWeight: FontWeight.w600, decoration: isBanned ? TextDecoration.lineThrough : null), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (role == 'admin' || AdminService.isAdminPhone(phone))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: const Text('ADMIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.accent)),
                )
              else if (role == 'moderator')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: const Text('MOD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.teal)),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(phone, style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
              if (createdAt != null) Text('Регистрация: ${createdAt.day}.${createdAt.month}.${createdAt.year}', style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
            ],
          ),
          trailing: AdminService.isAdminPhone(phone)
              ? null
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textHint, size: 20),
                  color: AppColors.surfaceLight,
                  onSelected: (action) async {
                    if (action == 'ban') {
                      final reason = await _showBanDialog(context, mandatory: true);
                      if (reason != null && reason.isNotEmpty) {
                        await admin.banUser(uid, reason: reason);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Забанен')));
                      }
                    } else if (action == 'unban') {
                      await admin.unbanUser(uid);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Разбанен')));
                    } else if (action == 'promote_mod') {
                      await admin.promoteToModerator(uid);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Назначен модератором')));
                    } else if (action == 'promote_admin') {
                      await admin.promoteToAdmin(uid);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Назначен админом')));
                    } else if (action == 'demote') {
                      await admin.demoteToUser(uid);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Понижен')));
                    } else if (action == 'warn') {
                      final msg = await _showBanDialog(context, mandatory: true, title: 'Предупреждение', hint: 'Текст предупреждения');
                      if (msg != null && msg.isNotEmpty) {
                        await admin.warnUser(uid, msg);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Предупреждение отправлено')));
                      }
                    } else if (action == 'reset_avatar') {
                      await admin.resetUserAvatar(uid);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Аватар сброшен')));
                    } else if (action == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surfaceLight,
                          title: const Text('Удалить аккаунт?', style: TextStyle(color: AppColors.textPrimary)),
                          content: const Text('Это действие НЕОБРАТИМО', style: TextStyle(color: AppColors.error)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена', style: TextStyle(color: AppColors.textHint))),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: AppColors.error))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await admin.deleteUserAccount(uid);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Аккаунт удалён')));
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    if (!isBanned)
                      const PopupMenuItem(value: 'ban', child: Row(children: [Icon(Icons.block, color: AppColors.error, size: 18), SizedBox(width: 8), Text('Забанить', style: TextStyle(color: AppColors.error))]))
                    else
                      const PopupMenuItem(value: 'unban', child: Row(children: [Icon(Icons.undo, color: AppColors.success, size: 18), SizedBox(width: 8), Text('Разбанить', style: TextStyle(color: AppColors.success))])),
                    if (role == 'user') ...[
                      const PopupMenuItem(value: 'promote_mod', child: Row(children: [Icon(Icons.shield, color: Colors.teal, size: 18), SizedBox(width: 8), Text('Модератор', style: TextStyle(color: Colors.teal))])),
                      const PopupMenuItem(value: 'promote_admin', child: Row(children: [Icon(Icons.admin_panel_settings, color: AppColors.accent, size: 18), SizedBox(width: 8), Text('Админ', style: TextStyle(color: AppColors.accent))])),
                    ] else if (role == 'moderator')
                      const PopupMenuItem(value: 'demote', child: Row(children: [Icon(Icons.arrow_downward, color: Colors.orange, size: 18), SizedBox(width: 8), Text('Понизить', style: TextStyle(color: Colors.orange))])),
                    const PopupMenuItem(value: 'warn', child: Row(children: [Icon(Icons.warning_rounded, color: Colors.amber, size: 18), SizedBox(width: 8), Text('Предупредить', style: TextStyle(color: Colors.amber))])),
                    const PopupMenuItem(value: 'reset_avatar', child: Row(children: [Icon(Icons.image_not_supported, color: AppColors.textHint, size: 18), SizedBox(width: 8), Text('Сбросить аватар', style: TextStyle(color: AppColors.textHint))])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, color: AppColors.error, size: 18), SizedBox(width: 8), Text('Удалить аккаунт', style: TextStyle(color: AppColors.error))])),
                  ],
                ),
        ),
      ),
    );
  }

  Future<String?> _showBanDialog(BuildContext context, {bool mandatory = false, String title = 'Забанить пользователя?', String hint = 'Причина'}) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(hintText: mandatory ? '$hint (ОБЯЗАТЕЛЬНО)' : hint, hintStyle: const TextStyle(color: AppColors.textHint)),
            ),
            if (mandatory) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Модератор обязан указать причину', style: TextStyle(color: AppColors.error, fontSize: 11))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: AppColors.textHint))),
          TextButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (mandatory && text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Укажите причину!')));
                return;
              }
              Navigator.pop(ctx, text);
            },
            child: const Text('Подтвердить', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
