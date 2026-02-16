import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'chat_screen.dart';
import '../groups/group_chat_screen.dart';

/// Universal search screen — search users, groups, communities by @Name.
class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late final TabController _tabCtrl;
  String _query = '';

  List<UserModel> _users = [];
  List<GroupModel> _groups = [];
  List<GroupModel> _communities = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _query = '';
        _users = [];
        _groups = [];
        _communities = [];
      });
      return;
    }

    setState(() {
      _query = query;
      _searching = true;
    });

    final db = FirebaseFirestore.instance;
    final q = query.toLowerCase().replaceAll('@', '').trim();
    final myUid = ref.read(authServiceProvider).effectiveUid;

    // Search users — fetch all and filter client-side for Cyrillic support
    final userSnap = await db.collection('users').limit(200).get();
    final users = userSnap.docs
        .map((d) => UserModel.fromFirestore(d))
        .where((u) =>
            u.uid != myUid &&
            (u.displayName.toLowerCase().contains(q) ||
             u.phoneNumber.contains(q)))
        .toList();

    // Search groups by name (client-side filter for Cyrillic)
    final groupSnap = await db.collection('groups').get();
    final allGroups = groupSnap.docs.map((d) => GroupModel.fromFirestore(d)).toList();

    final groups = allGroups
        .where((g) => !g.isCommunity && g.name.toLowerCase().contains(q))
        .toList();
    final communities = allGroups
        .where((g) => g.isCommunity && g.name.toLowerCase().contains(q))
        .toList();

    if (mounted) {
      setState(() {
        _users = users;
        _groups = groups;
        _communities = communities;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Search field
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_rounded,
                                size: 20, color: AppColors.textPrimary),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              autofocus: true,
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontSize: 16),
                              decoration: InputDecoration(
                                hintText: 'Поиск @имя, телефон, группа...',
                                hintStyle: TextStyle(
                                    color: AppColors.textHint.withValues(alpha: 0.5)),
                                border: InputBorder.none,
                                prefixIcon: Icon(Icons.search_rounded,
                                    color: AppColors.textHint.withValues(alpha: 0.5),
                                    size: 20),
                              ),
                              onChanged: _search,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tabs
                    TabBar(
                      controller: _tabCtrl,
                      indicatorColor: AppColors.accent,
                      labelColor: AppColors.accent,
                      unselectedLabelColor: AppColors.textHint,
                      indicatorSize: TabBarIndicatorSize.label,
                      labelStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      tabs: [
                        Tab(text: 'Люди (${_users.length})'),
                        Tab(text: 'Группы (${_groups.length})'),
                        Tab(text: 'Сообщества (${_communities.length})'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: _searching
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
          : _query.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_rounded,
                          size: 56,
                          color: AppColors.textHint.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                        'Введите @имя или номер телефона',
                        style: TextStyle(
                          color: AppColors.textHint.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // Users tab
                    _buildUsersList(),
                    // Groups tab
                    _buildGroupsList(_groups, isGroup: true),
                    // Communities tab
                    _buildGroupsList(_communities, isGroup: false),
                  ],
                ),
    );
  }

  Widget _buildUsersList() {
    if (_users.isEmpty) {
      return Center(
        child: Text('Пользователи не найдены',
            style: TextStyle(
                color: AppColors.textHint.withValues(alpha: 0.5))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: _users.length,
      itemBuilder: (_, i) {
        final user = _users[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: VCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    peerId: user.uid,
                    peerName: user.displayName.isNotEmpty
                        ? user.displayName
                        : user.phoneNumber,
                    peerAvatarUrl: user.effectiveAvatar,
                  ),
                ),
              );
            },
            child: Row(
              children: [
                VAvatar(
                  name: user.displayName.isNotEmpty
                      ? user.displayName
                      : user.phoneNumber,
                  imageUrl: user.effectiveAvatar,
                  radius: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName.isNotEmpty
                            ? user.displayName
                            : user.phoneNumber,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (user.displayName.isNotEmpty)
                        Text(
                          '@${user.displayName}',
                          style: TextStyle(
                            color: AppColors.accent.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: user.isOnline ? AppColors.success : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupsList(List<GroupModel> groups, {required bool isGroup}) {
    if (groups.isEmpty) {
      return Center(
        child: Text(
          isGroup ? 'Группы не найдены' : 'Сообщества не найдены',
          style: TextStyle(
              color: AppColors.textHint.withValues(alpha: 0.5)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: groups.length,
      itemBuilder: (_, i) {
        final g = groups[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: VCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupChatScreen(group: g),
                ),
              );
            },
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: g.isCommunity
                        ? Colors.blue.withValues(alpha: 0.15)
                        : AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    g.isCommunity ? Icons.public_rounded : Icons.group_rounded,
                    color: g.isCommunity ? Colors.blue : AppColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600)),
                      Text(
                        '${g.members.length} участников',
                        style: TextStyle(
                          color: AppColors.textHint.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
