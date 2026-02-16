import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'call_screen.dart';

/// Incoming call screen — premium with accept / decline.
class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key, required this.call});
  final CallModel call;

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  final AudioPlayer _ringtonePlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _playRingtone();
  }

  Future<void> _playRingtone() async {
    try {
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.play(
        UrlSource('https://www.soundjay.com/phone/phone-calling-1.mp3'),
        volume: 0.7,
      );
    } catch (e) {
      debugPrint('Ringtone error: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _ringtonePlayer.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    await _stopRingtone();
    final authService = ref.read(authServiceProvider);
    final currentUser = ref.read(currentUserProvider);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callerId: widget.call.callerId,
          callerName: widget.call.callerName,
          receiverId: authService.effectiveUid,
          receiverName: currentUser.displayName.isNotEmpty
              ? currentUser.displayName
              : currentUser.phoneNumber,
          receiverAvatarUrl: widget.call.callerAvatar.isNotEmpty ? widget.call.callerAvatar : null,
          incomingCall: widget.call,
          isVideoCall: widget.call.isVideoCall,
        ),
      ),
    );
  }

  bool get _isVideo => widget.call.isVideoCall;

  Future<void> _decline() async {
    await _stopRingtone();
    final webrtc = ref.read(webrtcServiceProvider);
    await webrtc.declineCall(widget.call.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ─── Encryption badge ─────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded,
                      color: AppColors.encryptionActive, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'E2E Encrypted',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.encryptionActive,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.xxl),

            // ─── Pulsing avatar ───────────
            ScaleTransition(
              scale: _pulse,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.2),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: VAvatar(
                  name: widget.call.callerName,
                  imageUrl: widget.call.callerAvatar.isNotEmpty ? widget.call.callerAvatar : null,
                  radius: 50,
                  showGlow: true,
                ),
              ),
            ),

            const SizedBox(height: AppSizes.lg),

            // ─── Caller info ──────────────
            Text(
              widget.call.callerName.isNotEmpty
                  ? widget.call.callerName
                  : 'Неизвестный',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: AppSizes.sm),

            Text(
              _isVideo ? 'Входящий видеозвонок...' : 'Входящий звонок...',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ),

            const Spacer(flex: 3),

            // ─── Accept / Decline ─────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.xxl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline
                  _RoundButton(
                    icon: Icons.call_end_rounded,
                    label: 'Отклонить',
                    color: AppColors.callEnd,
                    onPressed: _decline,
                  ),
                  // Accept
                  _RoundButton(
                    icon: _isVideo
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    label: 'Ответить',
                    color: AppColors.success,
                    onPressed: _accept,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.xxl),
          ],
        ),
      ),
    );
  }
}

// ─── Round Action Button ─────────────────────────────────

class _RoundButton extends StatefulWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
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
            widget.onPressed();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.88 : 1.0,
            duration: AppSizes.animFast,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Text(
          widget.label,
          style: TextStyle(fontSize: 12, color: widget.color),
        ),
      ],
    );
  }
}
