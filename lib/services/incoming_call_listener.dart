import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/constants/constants.dart';
import '../models/models.dart';
import '../screens/call/call_screen.dart';
import '../widgets/widgets.dart';

/// Listens for incoming calls in Firestore and shows a full-screen overlay +
/// a top banner on every screen. Plays a ringtone.
class IncomingCallListener {
  StreamSubscription? _subscription;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Set<String> _handledCallIds = {};

  OverlayEntry? _overlayEntry;
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  String _activeCallId = '';

  /// Start listening for incoming calls directed at [uid].
  void startListening({
    required String uid,
    required GlobalKey<NavigatorState> navigatorKey,
  }) {
    _subscription?.cancel();
    _handledCallIds.clear();

    _subscription = _db
        .collection('calls')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: CallStatus.ringing.name)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final call = CallModel.fromMap(change.doc.id, data);

          // Skip if WE are the caller
          if (call.callerId == uid) continue;

          // Skip if already handled
          if (_handledCallIds.contains(call.id)) continue;
          _handledCallIds.add(call.id);

          final navigator = navigatorKey.currentState;
          if (navigator != null) {
            _showIncomingCallOverlay(navigator, call, uid);
          }
        }
      }

      // Also check if the active call was cancelled/ended
      if (_activeCallId.isNotEmpty) {
        final stillRinging = snapshot.docs.any((d) => d.id == _activeCallId);
        if (!stillRinging) {
          _dismissOverlay();
        }
      }
    });
  }

  void _showIncomingCallOverlay(
    NavigatorState navigator,
    CallModel call,
    String uid,
  ) {
    // Dismiss any existing overlay
    _dismissOverlay();
    _activeCallId = call.id;

    // Play ringtone
    _playRingtone();

    // Create overlay
    _overlayEntry = OverlayEntry(
      builder: (context) => _IncomingCallOverlay(
        call: call,
        currentUid: uid,
        onAccept: () {
          _dismissOverlay();
          navigator.push(
            MaterialPageRoute(
              builder: (_) => _buildCallScreen(call, uid, navigator),
            ),
          );
        },
        onDecline: () async {
          _dismissOverlay();
          await _db.collection('calls').doc(call.id).update({
            'status': CallStatus.declined.name,
          });
        },
      ),
    );

    navigator.overlay?.insert(_overlayEntry!);
  }

  Widget _buildCallScreen(CallModel call, String uid, NavigatorState nav) {
    // We need a ConsumerWidget to read providers, but for simplicity
    // we pass basic info directly
    return CallScreen(
      callerId: call.callerId,
      callerName: call.callerName,
      receiverId: uid,
      receiverName: '', // Will be resolved in CallScreen
      receiverAvatarUrl:
          call.callerAvatar.isNotEmpty ? call.callerAvatar : null,
      incomingCall: call,
      isVideoCall: call.isVideoCall,
    );
  }

  Future<void> _playRingtone() async {
    try {
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      // Use bundled asset ringtone
      await _ringtonePlayer.play(
        AssetSource('ringtone.mp3'),
        volume: 0.8,
      );
    } catch (e) {
      debugPrint('Ringtone error: $e');
      // Fallback to URL
      try {
        await _ringtonePlayer.play(
          UrlSource('https://www.soundjay.com/phone/phone-calling-1.mp3'),
          volume: 0.7,
        );
      } catch (_) {}
    }
  }

  void _dismissOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _activeCallId = '';
    try {
      _ringtonePlayer.stop();
    } catch (_) {}
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _dismissOverlay();
  }

  void dispose() {
    stopListening();
    _ringtonePlayer.dispose();
  }
}

// ─── Full-screen Incoming Call Overlay ───────────────────

class _IncomingCallOverlay extends StatefulWidget {
  const _IncomingCallOverlay({
    required this.call,
    required this.currentUid,
    required this.onAccept,
    required this.onDecline,
  });

  final CallModel call;
  final String currentUid;
  final VoidCallback onAccept;
  final Future<void> Function() onDecline;

  @override
  State<_IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<_IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: mq.size.width,
        height: mq.size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0015),
              Color(0xFF000000),
              Color(0xFF050010),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Encryption badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded,
                        color: AppColors.encryptionActive, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'E2E Encrypted',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.encryptionActive,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Pulsing avatar
              ScaleTransition(
                scale: _pulse,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.25),
                        blurRadius: 60,
                        spreadRadius: 15,
                      ),
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        blurRadius: 80,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                  child: VAvatar(
                    name: widget.call.callerName,
                    imageUrl: widget.call.callerAvatar.isNotEmpty
                        ? widget.call.callerAvatar
                        : null,
                    radius: 56,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Caller name
              Text(
                widget.call.callerName.isNotEmpty
                    ? widget.call.callerName
                    : 'Неизвестный',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              // Call type
              Text(
                widget.call.isVideoCall
                    ? '📹 Входящий видеозвонок...'
                    : '📞 Входящий звонок...',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
              ),

              const Spacer(flex: 3),

              // Accept / Decline buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline
                    _CallActionBtn(
                      icon: Icons.call_end_rounded,
                      label: 'Отклонить',
                      color: AppColors.callEnd,
                      onTap: widget.onDecline,
                    ),
                    // Accept
                    _CallActionBtn(
                      icon: widget.call.isVideoCall
                          ? Icons.videocam_rounded
                          : Icons.call_rounded,
                      label: 'Ответить',
                      color: AppColors.success,
                      onTap: widget.onAccept,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Call Action Button ──────────────────────────────────

class _CallActionBtn extends StatefulWidget {
  const _CallActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_CallActionBtn> createState() => _CallActionBtnState();
}

class _CallActionBtnState extends State<_CallActionBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.85 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            color: widget.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
