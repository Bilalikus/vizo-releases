import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/constants/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Voice & Video call screen with screen sharing support.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    super.key,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    this.incomingCall,
    this.isVideoCall = false,
  });

  final String callerId;
  final String callerName;
  final String receiverId;
  final String receiverName;
  final CallModel? incomingCall;
  final bool isVideoCall;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with SingleTickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isVideoEnabled = false;
  bool _isScreenSharing = false;
  CallStatus _status = CallStatus.idle;
  Timer? _callTimer;
  int _seconds = 0;
  bool _hasPopped = false;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _renderersInitialized = false;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _isVideoEnabled = widget.isVideoCall ||
        (widget.incomingCall?.isVideoCall ?? false);

    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    setState(() => _renderersInitialized = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCall());
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _pulseCtrl.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  Future<void> _initCall() async {
    final webrtc = ref.read(webrtcServiceProvider);

    webrtc.onLocalStream = (stream) {
      if (mounted) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
      }
    };

    webrtc.onRemoteStream = (stream) {
      if (mounted) {
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      }
    };

    webrtc.onCallStatusChanged = (status) {
      if (!mounted) return;
      setState(() => _status = status);

      if (status == CallStatus.active) {
        _startTimer();
      }
      if (status == CallStatus.ended) {
        _safePop();
      }
    };

    webrtc.onCallEnded = () {
      if (!mounted) return;
      _safePop();
    };

    webrtc.onScreenShareChanged = (sharing) {
      if (mounted) setState(() => _isScreenSharing = sharing);
    };

    webrtc.onVideoStateChanged = (enabled) {
      if (mounted) setState(() => _isVideoEnabled = enabled);
    };

    if (widget.incomingCall != null) {
      setState(() => _status = CallStatus.connecting);
      await webrtc.answerCall(widget.incomingCall!);
    } else {
      final receiverId = widget.receiverId;

      if (receiverId.isEmpty) {
        if (mounted) {
          setState(() => _status = CallStatus.ended);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Пользователь не зарегистрирован в Vizo'),
            ),
          );
          Future.delayed(const Duration(seconds: 1), () => _safePop());
        }
        return;
      }

      setState(() => _status = CallStatus.ringing);

      await webrtc.makeCall(
        callerId: widget.callerId,
        callerName: widget.callerName,
        receiverId: receiverId,
        receiverName: widget.receiverName,
        isVideoCall: widget.isVideoCall,
      );
    }
  }

  void _startTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _safePop() {
    if (_hasPopped || !mounted) return;
    _hasPopped = true;
    Navigator.of(context).pop();
  }

  Future<void> _endCall() async {
    final webrtc = ref.read(webrtcServiceProvider);
    await webrtc.endCall();
    _safePop();
  }

  void _toggleMute() {
    final webrtc = ref.read(webrtcServiceProvider);
    final muted = webrtc.toggleMute();
    setState(() => _isMuted = muted);
  }

  void _toggleSpeaker() {
    final webrtc = ref.read(webrtcServiceProvider);
    final newVal = !_isSpeaker;
    webrtc.toggleSpeaker(newVal);
    setState(() => _isSpeaker = newVal);
  }

  void _toggleVideo() {
    final webrtc = ref.read(webrtcServiceProvider);
    final enabled = webrtc.toggleVideo();
    setState(() => _isVideoEnabled = enabled);
  }

  Future<void> _switchCamera() async {
    final webrtc = ref.read(webrtcServiceProvider);
    await webrtc.switchCamera();
  }

  Future<void> _toggleScreenShare() async {
    final webrtc = ref.read(webrtcServiceProvider);
    if (_isScreenSharing) {
      await webrtc.stopScreenShare();
    } else {
      await webrtc.startScreenShare();
    }
  }

  String get _statusText {
    switch (_status) {
      case CallStatus.ringing:
        return 'Вызов...';
      case CallStatus.connecting:
        return 'Подключение...';
      case CallStatus.active:
        return _formattedTime;
      case CallStatus.ended:
        return 'Завершён';
      case CallStatus.declined:
        return 'Отклонён';
      case CallStatus.missed:
        return 'Пропущен';
      default:
        return '';
    }
  }

  bool get _showVideo =>
      (_isVideoEnabled || _isScreenSharing) &&
      _renderersInitialized &&
      _status == CallStatus.active;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) return;
        _hasPopped = true;
        final webrtc = ref.read(webrtcServiceProvider);
        if (webrtc.currentCallId != null) {
          await webrtc.endCall();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: Stack(
          children: [
            // ─── Video Background (remote) ───
            if (_showVideo)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),

            // ─── Main content ────────────────
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: AppSizes.md),

                  // ─── Encryption badge ─────────
                  const _EncryptionBadge(),

                  if (!_showVideo) ...[
                    const Spacer(flex: 2),

                    // ─── Avatar / pulsing ring ────
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, child) {
                        final scale = 1.0 +
                            (_status == CallStatus.ringing ||
                                    _status == CallStatus.connecting
                                ? _pulseCtrl.value * 0.06
                                : 0);
                        return Transform.scale(
                            scale: scale, child: child);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent
                                  .withValues(alpha: 0.2),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: VAvatar(
                          name: widget.receiverName,
                          radius: 50,
                          showGlow: _status == CallStatus.active,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSizes.lg),

                    // ─── Receiver name ────────────
                    Text(
                      widget.receiverName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                    // Name overlay for video mode
                    Text(
                      widget.receiverName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        shadows: [
                          Shadow(blurRadius: 10, color: Colors.black54),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSizes.sm),

                  // ─── Status / timer ───────────
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_status == CallStatus.ringing ||
                          _status == CallStatus.connecting)
                        const _PulsingDot(),
                      if (_status == CallStatus.ringing ||
                          _status == CallStatus.connecting)
                        const SizedBox(width: AppSizes.sm),
                      Text(
                        _statusText,
                        style: TextStyle(
                          fontSize: 15,
                          color: _status == CallStatus.active
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ],
                          shadows: _showVideo
                              ? const [
                                  Shadow(
                                      blurRadius: 8,
                                      color: Colors.black54),
                                ]
                              : null,
                        ),
                      ),
                      if (_isScreenSharing) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.screen_share_rounded,
                                  size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Экран',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),

                  const Spacer(flex: 3),

                  // ─── Controls ─────────────────
                  if (_status != CallStatus.ended &&
                      _status != CallStatus.declined)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.lg),
                      child: Column(
                        children: [
                          // Main controls row
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                            children: [
                              _CallControlButton(
                                icon: _isMuted
                                    ? Icons.mic_off_rounded
                                    : Icons.mic_rounded,
                                label: _isMuted ? 'Вкл.' : 'Откл.',
                                isActive: _isMuted,
                                onPressed: _toggleMute,
                              ),
                              _CallControlButton(
                                icon: _isVideoEnabled
                                    ? Icons.videocam_rounded
                                    : Icons.videocam_off_rounded,
                                label: 'Видео',
                                isActive: _isVideoEnabled,
                                onPressed: _toggleVideo,
                              ),
                              _EndCallButton(onPressed: _endCall),
                              _CallControlButton(
                                icon: _isSpeaker
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_down_rounded,
                                label: 'Динамик',
                                isActive: _isSpeaker,
                                onPressed: _toggleSpeaker,
                              ),
                              _CallControlButton(
                                icon: _isScreenSharing
                                    ? Icons.stop_screen_share_rounded
                                    : Icons.screen_share_rounded,
                                label: _isScreenSharing
                                    ? 'Стоп'
                                    : 'Экран',
                                isActive: _isScreenSharing,
                                onPressed: _toggleScreenShare,
                              ),
                            ],
                          ),
                          // Camera switch button (only for video)
                          if (_isVideoEnabled &&
                              !_isScreenSharing &&
                              _status == CallStatus.active)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: AppSizes.md),
                              child: _CallControlButton(
                                icon: Icons.cameraswitch_rounded,
                                label: 'Камера',
                                isActive: false,
                                onPressed: _switchCamera,
                              ),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: AppSizes.xxl),
                ],
              ),
            ),

            // ─── Local video PiP (top-right) ────
            if (_showVideo)
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                right: 16,
                child: GestureDetector(
                  onTap: _switchCamera,
                  child: Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit
                          .RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Encryption Badge ────────────────────────────────────

class _EncryptionBadge extends StatelessWidget {
  const _EncryptionBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }
}

// ─── Pulsing Dot ─────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                AppColors.accent.withValues(alpha: 0.4 + _ctrl.value * 0.6),
          ),
        );
      },
    );
  }
}

// ─── Call Control Button ─────────────────────────────────

class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VIconButton(
          icon: icon,
          onPressed: onPressed,
          backgroundColor: isActive
              ? AppColors.accent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          color: isActive ? AppColors.accent : AppColors.textPrimary,
        ),
        const SizedBox(height: AppSizes.sm),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color:
                isActive ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── End Call Button ─────────────────────────────────────

class _EndCallButton extends StatefulWidget {
  const _EndCallButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_EndCallButton> createState() => _EndCallButtonState();
}

class _EndCallButtonState extends State<_EndCallButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onPressed();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.9 : 1.0,
            duration: AppSizes.animFast,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.callEnd.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.callEnd.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.call_end_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        const Text(
          'Завершить',
          style: TextStyle(fontSize: 11, color: AppColors.callEnd),
        ),
      ],
    );
  }
}
