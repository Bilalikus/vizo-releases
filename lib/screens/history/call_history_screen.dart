import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Call history — premium with filter tabs.
/// Uses two separate Firestore queries (caller + receiver) merged client-side
/// to avoid requiring a composite index for Filter.or + orderBy.
class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  int _filterIndex = 0; // 0 = all, 1 = incoming, 2 = outgoing, 3 = missed
  List<CallModel> _calls = [];
  bool _isLoading = true;
  StreamSubscription? _callerSub;
  StreamSubscription? _receiverSub;
  List<CallModel> _callerCalls = [];
  List<CallModel> _receiverCalls = [];
  String _currentUid = '';

  @override
  void dispose() {
    _callerSub?.cancel();
    _receiverSub?.cancel();
    super.dispose();
  }

  void _startListening(String uid) {
    if (_currentUid == uid) return;
    _currentUid = uid;
    _callerSub?.cancel();
    _receiverSub?.cancel();

    final db = FirebaseFirestore.instance;

    // Query 1: calls where user is the caller
    _callerSub = db
        .collection('calls')
        .where('callerId', isEqualTo: uid)
        .orderBy('startedAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      _callerCalls = snap.docs
          .map((d) => CallModel.fromMap(d.id, d.data()))
          .toList();
      _mergeCalls();
    }, onError: (_) {
      // Fallback: query without orderBy
      _callerSub?.cancel();
      _callerSub = db
          .collection('calls')
          .where('callerId', isEqualTo: uid)
          .limit(50)
          .snapshots()
          .listen((snap) {
        _callerCalls = snap.docs
            .map((d) => CallModel.fromMap(d.id, d.data()))
            .toList();
        _mergeCalls();
      });
    });

    // Query 2: calls where user is the receiver
    _receiverSub = db
        .collection('calls')
        .where('receiverId', isEqualTo: uid)
        .orderBy('startedAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      _receiverCalls = snap.docs
          .map((d) => CallModel.fromMap(d.id, d.data()))
          .toList();
      _mergeCalls();
    }, onError: (_) {
      // Fallback: query without orderBy
      _receiverSub?.cancel();
      _receiverSub = db
          .collection('calls')
          .where('receiverId', isEqualTo: uid)
          .limit(50)
          .snapshots()
          .listen((snap) {
        _receiverCalls = snap.docs
            .map((d) => CallModel.fromMap(d.id, d.data()))
            .toList();
        _mergeCalls();
      });
    });
  }

  void _mergeCalls() {
    // Merge, deduplicate by ID, sort by startedAt descending
    final map = <String, CallModel>{};
    for (final c in _callerCalls) {
      map[c.id] = c;
    }
    for (final c in _receiverCalls) {
      map[c.id] = c;
    }
    final merged = map.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    if (mounted) {
      setState(() {
        _calls = merged;
        _isLoading = false;
      });
    }
  }

  bool _matchesFilter(CallModel call, String uid) {
    switch (_filterIndex) {
      case 1: // Incoming
        return call.receiverId == uid;
      case 2: // Outgoing
        return call.callerId == uid;
      case 3: // Missed
        return call.receiverId == uid &&
            (call.status == CallStatus.missed ||
                call.status == CallStatus.declined);
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.read(authServiceProvider);
    final uid = authService.effectiveUid;

    if (uid.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.black,
        body: Center(
          child: Text('Не авторизован',
              style: TextStyle(color: AppColors.textHint)),
        ),
      );
    }

    // Start listening (idempotent — checks uid)
    _startListening(uid);

    final filtered = _calls.where((c) => _matchesFilter(c, uid)).toList();

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Звонки',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),

                    // ─── Filter chips ───────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Все',
                            isActive: _filterIndex == 0,
                            onTap: () => setState(() => _filterIndex = 0),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          _FilterChip(
                            label: 'Входящие',
                            isActive: _filterIndex == 1,
                            onTap: () => setState(() => _filterIndex = 1),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          _FilterChip(
                            label: 'Исходящие',
                            isActive: _filterIndex == 2,
                            onTap: () => setState(() => _filterIndex = 2),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          _FilterChip(
                            label: 'Пропущенные',
                            isActive: _filterIndex == 3,
                            onTap: () => setState(() => _filterIndex = 3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Call list ──────────────────────
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_rounded,
                        size: 56,
                        color:
                            AppColors.textHint.withValues(alpha: 0.4)),
                    const SizedBox(height: AppSizes.md),
                    Text(
                      'Нет звонков',
                      style: TextStyle(
                        color:
                            AppColors.textHint.withValues(alpha: 0.6),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSizes.md),
              sliver: SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) =>
                    _CallHistoryTile(call: filtered[i], uid: uid),
              ),
            ),

          SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ─── Filter Chip ─────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppSizes.animNormal,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.accent.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Call History Tile ───────────────────────────────────

class _CallHistoryTile extends StatelessWidget {
  const _CallHistoryTile({required this.call, required this.uid});

  final CallModel call;
  final String uid;

  bool get _isOutgoing => call.callerId == uid;

  String get _peerName =>
      _isOutgoing ? call.receiverName : call.callerName;

  String get _peerAvatar =>
      _isOutgoing ? call.receiverAvatar : call.callerAvatar;

  IconData get _directionIcon =>
      _isOutgoing ? Icons.call_made_rounded : Icons.call_received_rounded;

  Color get _directionColor {
    if (call.status == CallStatus.missed ||
        call.status == CallStatus.declined) {
      return AppColors.error;
    }
    return _isOutgoing ? AppColors.success : AppColors.accentLight;
  }

  String get _subtitle {
    final time = _formatTime(call.startedAt);
    final dur = call.duration;
    final videoTag = call.isVideoCall ? '📹 ' : '';
    if (dur != null && dur.inSeconds > 0) {
      final m = dur.inMinutes.toString().padLeft(2, '0');
      final s = (dur.inSeconds % 60).toString().padLeft(2, '0');
      return '$videoTag$time • $m:$s';
    }
    if (call.status == CallStatus.missed) return '$videoTag$time • Пропущен';
    if (call.status == CallStatus.declined) return '$videoTag$time • Отклонён';
    return '$videoTag$time';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inDays < 1) return '${diff.inHours} ч назад';
    if (diff.inDays == 1) return 'вчера';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.xs),
      child: VCard(
        child: Row(
          children: [
            VAvatar(
              name: _peerName,
              imageUrl: _peerAvatar.isNotEmpty ? _peerAvatar : null,
              radius: 22,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _peerName.isNotEmpty ? _peerName : 'Неизвестный',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(_directionIcon, color: _directionColor, size: 20),
          ],
        ),
      ),
    );
  }
}
