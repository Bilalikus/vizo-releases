import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';
import '../../services/admin_service.dart';
import '../../widgets/widgets.dart';

/// Admin dashboard — stats, user management, bans.
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
  int _totalInstalls = 0;
  int _newUsersToday = 0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
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
        _admin.getTotalInstalls(),
        _admin.getNewUsersToday(),
      ]);
      if (mounted) {
        setState(() {
          _totalUsers = results[0];
          _onlineUsers = results[1];
          _totalChats = results[2];
          _totalGroups = results[3];
          _totalInstalls = results[4];
          _newUsersToday = results[5];
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
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.sm),
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
                        const Icon(Icons.admin_panel_settings_rounded,
                            color: AppColors.accent, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          'Админ панель',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // ─── Stats Cards ─────────────
                    _loadingStats
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: AppColors.accent,
                                strokeWidth: 2,
                              ),
                            ),
                          )
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
                indicatorColor: AppColors.accent,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textHint,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Пользователи'),
                  Tab(text: 'Забаненные'),
                  Tab(text: 'Онлайн'),
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
            _OnlineUsersTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatCard(
          icon: Icons.people_rounded,
          label: 'Всего',
          value: '$_totalUsers',
          color: AppColors.accent,
        ),
        _StatCard(
          icon: Icons.circle,
          label: 'Онлайн',
          value: '$_onlineUsers',
          color: AppColors.success,
        ),
        _StatCard(
          icon: Icons.chat_rounded,
          label: 'Чаты',
          value: '$_totalChats',
          color: Colors.blue,
        ),
        _StatCard(
          icon: Icons.group_rounded,
          label: 'Группы',
          value: '$_totalGroups',
          color: Colors.orange,
        ),
        _StatCard(
          icon: Icons.download_rounded,
          label: 'Установки',
          value: '$_totalInstalls',
          color: Colors.teal,
        ),
        _StatCard(
          icon: Icons.fiber_new_rounded,
          label: 'За 24ч',
          value: '$_newUsersToday',
          color: Colors.pink,
        ),
      ],
    );
  }
}

// ─── Stat Card ─────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
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
          width: (MediaQuery.of(context).size.width - 48 - 20) / 3,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
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
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.black,
      child: tabBar,
    );
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
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.accent, strokeWidth: 2),
          );
        }
        final users = snapshot.data!;
        if (users.isEmpty) {
          return const Center(
            child: Text('Нет пользователей',
                style: TextStyle(color: AppColors.textHint)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.md),
          itemCount: users.length,
          itemBuilder: (_, i) => _UserTile(
            user: users[i],
            admin: admin,
          ),
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
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.accent, strokeWidth: 2),
          );
        }
        final banned = snapshot.data!;
        if (banned.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 48,
                    color: AppColors.success.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text('Нет забаненных',
                    style: TextStyle(color: AppColors.textHint)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.md),
          itemCount: banned.length,
          itemBuilder: (_, i) {
            final ban = banned[i];
            final uid = ban['uid'] as String? ?? '';
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .get(),
              builder: (context, userSnap) {
                final userData =
                    userSnap.data?.data() as Map<String, dynamic>?;
                final name = userData?['displayName'] as String? ??
                    userData?['phoneNumber'] as String? ??
                    uid;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: VCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.error,
                        child: Icon(Icons.block, color: Colors.white),
                      ),
                      title: Text(name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'Причина: ${ban['reason'] ?? 'Не указана'}',
                        style: const TextStyle(
                            color: AppColors.textHint, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.undo_rounded,
                            color: AppColors.success),
                        onPressed: () async {
                          await admin.unbanUser(uid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Разбанен')),
                            );
                          }
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

// ─── Online Users Tab ───────────────────────

class _OnlineUsersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('isOnline', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.accent, strokeWidth: 2),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('Никого в сети',
                style: TextStyle(color: AppColors.textHint)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.md),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            data['uid'] = docs[i].id;
            final name = data['displayName'] as String? ??
                data['phoneNumber'] as String? ??
                '';
            final avatar = data['avatarBase64'] as String?;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Stack(
                    children: [
                      VAvatar(imageUrl: avatar, name: name, radius: 20),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.black, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(name,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    data['phoneNumber'] as String? ?? '',
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 12),
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

// ─── User Tile ──────────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.admin});
  final Map<String, dynamic> user;
  final AdminService admin;

  @override
  Widget build(BuildContext context) {
    final uid = user['uid'] as String? ?? '';
    final name = user['displayName'] as String? ??
        user['phoneNumber'] as String? ??
        '';
    final phone = user['phoneNumber'] as String? ?? '';
    final avatar = user['avatarBase64'] as String?;
    final isOnline = user['isOnline'] as bool? ?? false;
    final isBanned = user['isBanned'] as bool? ?? false;
    final createdAt = (user['createdAt'] as Timestamp?)?.toDate();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Stack(
            children: [
              VAvatar(imageUrl: avatar, name: name, radius: 20),
              if (isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.black, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: isBanned
                        ? AppColors.error
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    decoration:
                        isBanned ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (AdminService.isAdminPhone(phone))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(phone,
                  style: const TextStyle(
                      color: AppColors.textHint, fontSize: 12)),
              if (createdAt != null)
                Text(
                  'Регистрация: ${createdAt.day}.${createdAt.month}.${createdAt.year}',
                  style: const TextStyle(
                      color: AppColors.textHint, fontSize: 10),
                ),
            ],
          ),
          trailing: AdminService.isAdminPhone(phone)
              ? null
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.textHint, size: 20),
                  color: AppColors.surfaceLight,
                  onSelected: (action) async {
                    if (action == 'ban') {
                      final reason = await _showBanDialog(context);
                      if (reason != null) {
                        await admin.banUser(uid, reason: reason);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Забанен')),
                          );
                        }
                      }
                    } else if (action == 'unban') {
                      await admin.unbanUser(uid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Разбанен')),
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    if (!isBanned)
                      const PopupMenuItem(
                        value: 'ban',
                        child: Row(
                          children: [
                            Icon(Icons.block, color: AppColors.error, size: 18),
                            SizedBox(width: 8),
                            Text('Забанить',
                                style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'unban',
                        child: Row(
                          children: [
                            Icon(Icons.undo_rounded,
                                color: AppColors.success, size: 18),
                            SizedBox(width: 8),
                            Text('Разбанить',
                                style: TextStyle(color: AppColors.success)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<String?> _showBanDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Забанить пользователя?',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Причина (необязательно)',
            hintStyle: TextStyle(color: AppColors.textHint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Забанить',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
