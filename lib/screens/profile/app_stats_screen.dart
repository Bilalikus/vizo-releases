import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// App usage statistics — personal analytics dashboard.
class AppStatsScreen extends ConsumerStatefulWidget {
  const AppStatsScreen({super.key});

  @override
  ConsumerState<AppStatsScreen> createState() => _AppStatsScreenState();
}

class _AppStatsScreenState extends ConsumerState<AppStatsScreen> {
  bool _loading = true;
  int _totalMessages = 0;
  int _totalChats = 0;
  int _totalContacts = 0;
  int _totalCalls = 0;
  int _sentMessages = 0;
  int _receivedMessages = 0;
  int _starredMessages = 0;
  int _totalReactions = 0;
  Map<String, int> _messagesByDay = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final uid = ref.read(authServiceProvider).effectiveUid;
    final db = FirebaseFirestore.instance;

    // Contacts count
    final contacts = await db
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .get();
    _totalContacts = contacts.docs.length;

    // Chats
    final chats = await db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();
    _totalChats = chats.docs.length;

    int sent = 0, received = 0, starred = 0, reactions = 0, total = 0;
    final byDay = <String, int>{};

    for (final chat in chats.docs) {
      final msgs = await db
          .collection('chats')
          .doc(chat.id)
          .collection('messages')
          .get();
      for (final m in msgs.docs) {
        final data = m.data();
        total++;
        if (data['senderId'] == uid) {
          sent++;
        } else {
          received++;
        }
        if (data['isStarred'] == true) starred++;
        if (data['reaction'] != null) reactions++;

        // Group by day of week
        final ts = (data['createdAt'] as Timestamp?)?.toDate();
        if (ts != null) {
          final dayName = _dayName(ts.weekday);
          byDay[dayName] = (byDay[dayName] ?? 0) + 1;
        }
      }
    }

    // Calls
    final calls = await db
        .collection('calls')
        .where(Filter.or(
          Filter('callerId', isEqualTo: uid),
          Filter('receiverId', isEqualTo: uid),
        ))
        .get();
    _totalCalls = calls.docs.length;

    if (mounted) {
      setState(() {
        _totalMessages = total;
        _sentMessages = sent;
        _receivedMessages = received;
        _starredMessages = starred;
        _totalReactions = reactions;
        _messagesByDay = byDay;
        _loading = false;
      });
    }
  }

  String _dayName(int weekday) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[weekday - 1];
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
              title: const Text('Статистика',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ─── Overview Grid ──────────
                Row(
                  children: [
                    Expanded(
                        child: _StatCard(
                            icon: Icons.chat_rounded,
                            label: 'Чаты',
                            value: '$_totalChats',
                            color: AppColors.accent)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _StatCard(
                            icon: Icons.message_rounded,
                            label: 'Сообщения',
                            value: '$_totalMessages',
                            color: AppColors.accentLight)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _StatCard(
                            icon: Icons.people_rounded,
                            label: 'Контакты',
                            value: '$_totalContacts',
                            color: AppColors.success)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _StatCard(
                            icon: Icons.call_rounded,
                            label: 'Звонки',
                            value: '$_totalCalls',
                            color: AppColors.warning)),
                  ],
                ),
                const SizedBox(height: 20),

                // ─── Message breakdown ──────
                VCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Сообщения',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      _StatRow(
                          label: 'Отправлено',
                          value: '$_sentMessages',
                          icon: Icons.send_rounded,
                          color: AppColors.accent),
                      _StatRow(
                          label: 'Получено',
                          value: '$_receivedMessages',
                          icon: Icons.inbox_rounded,
                          color: AppColors.accentLight),
                      _StatRow(
                          label: 'В избранном',
                          value: '$_starredMessages',
                          icon: Icons.star_rounded,
                          color: AppColors.warning),
                      _StatRow(
                          label: 'Реакции',
                          value: '$_totalReactions',
                          icon: Icons.emoji_emotions_rounded,
                          color: AppColors.success),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ─── Activity by day ──────
                VCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Активность по дням',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 16),
                      _WeekChart(data: _messagesByDay),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Ratio bar ──────
                if (_totalMessages > 0)
                  VCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Соотношение',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: _sentMessages,
                                child: Container(
                                    height: 24,
                                    color: AppColors.accent),
                              ),
                              Expanded(
                                flex: _receivedMessages.clamp(1, 999999),
                                child: Container(
                                    height: 24,
                                    color: AppColors.accentLight),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                    )),
                                const SizedBox(width: 6),
                                Text(
                                    'Отправлено ${(_sentMessages * 100 / _totalMessages).toInt()}%',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.7))),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppColors.accentLight,
                                      shape: BoxShape.circle,
                                    )),
                                const SizedBox(width: 6),
                                Text(
                                    'Получено ${(_receivedMessages * 100 / _totalMessages).toInt()}%',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.7))),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

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
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.data});
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final maxVal = data.values.fold(1, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((day) {
          final count = data[day] ?? 0;
          final fraction = count / maxVal;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('$count',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textHint
                              .withValues(alpha: 0.6))),
                  const SizedBox(height: 4),
                  Container(
                    height: 80 * fraction,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.accent.withValues(alpha: 0.3),
                          AppColors.accentLight.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(day,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.6))),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
