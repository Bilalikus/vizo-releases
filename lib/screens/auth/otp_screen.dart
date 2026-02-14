import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'profile_setup_screen.dart';

/// OTP verification screen — premium style.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _pinFocus = FocusNode();
  bool _loading = false;
  String? _error;
  String? _testCode;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    // Fetch the test code from Firestore to display it
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTestCode());
  }

  Future<void> _loadTestCode() async {
    final otpState = ref.read(otpStateProvider);
    final authService = ref.read(authServiceProvider);
    final code = await authService.getTestCode(otpState.phoneNumber);
    if (mounted && code != null) {
      setState(() => _testCode = code);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp(String code) async {
    if (code.length < 6) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final otpState = ref.read(otpStateProvider);
      final authService = ref.read(authServiceProvider);

      final user = await authService.verifyOtp(
        verificationId: otpState.verificationId,
        smsCode: code,
      );

      if (!mounted) return;

      if (user != null) {
        // Load user profile
        ref.read(currentUserProvider.notifier).setUser(user);

        if (!mounted) return;

        // Check if profile is already set up (returning user)
        final profileComplete =
            await authService.isProfileComplete();

        if (!mounted) return;

        if (profileComplete) {
          // Returning user — go straight to app
          ref.read(desktopSignedInProvider.notifier).state = true;
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          // New user — show profile setup
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const ProfileSetupScreen(),
            ),
          );
        }
      } else {
        setState(() {
          _loading = false;
          _error = 'Не удалось войти';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final otpState = ref.read(otpStateProvider);
    final authService = ref.read(authServiceProvider);

    await authService.sendOtp(
      phoneNumber: otpState.phoneNumber,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        ref.read(otpStateProvider.notifier).setVerificationId(verificationId);
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Код отправлен повторно')),
        );
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = error;
        });
      },
      resendToken: otpState.resendToken,
    );
  }

  @override
  Widget build(BuildContext context) {
    final otpState = ref.watch(otpStateProvider);

    final defaultPinTheme = PinTheme(
      width: 52,
      height: 58,
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.radiusDefault),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSizes.radiusDefault),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.6), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.12),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: FadeTransition(
            opacity: _fade,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ─── Lock icon ──────────────
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.accentGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),

                  const SizedBox(height: AppSizes.lg),

                  const Text(
                    'Код подтверждения',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: AppSizes.sm),

                  Text(
                    'Отправлен на ${otpState.phoneNumber}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),

                  // ─── Test code banner ───────
                  if (_testCode != null) ...[
                    const SizedBox(height: AppSizes.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: AppSizes.sm + 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusSmall),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bug_report_rounded,
                              color: AppColors.success, size: 18),
                          const SizedBox(width: AppSizes.sm),
                          Text(
                            'Тестовый код: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.success.withValues(alpha: 0.8),
                            ),
                          ),
                          Text(
                            _testCode!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSizes.xl),

                  // ─── PIN input ──────────────
                  Pinput(
                    controller: _pinController,
                    focusNode: _pinFocus,
                    length: 6,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    submittedPinTheme: defaultPinTheme,
                    showCursor: true,
                    cursor: Container(
                      width: 2,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    onCompleted: _verifyOtp,
                  ),

                  // ─── Error ──────────────────
                  if (_error != null) ...[
                    const SizedBox(height: AppSizes.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: AppSizes.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusSmall),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.error, size: 18),
                          const SizedBox(width: AppSizes.sm),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSizes.lg),

                  // ─── Verify button ──────────
                  VButton(
                    label: 'Подтвердить',
                    onPressed: !_loading
                        ? () => _verifyOtp(_pinController.text)
                        : null,
                    isLoading: _loading,
                  ),

                  const SizedBox(height: AppSizes.md),

                  // ─── Resend ─────────────────
                  TextButton(
                    onPressed: !_loading ? _resendOtp : null,
                    child: Text(
                      'Отправить код повторно',
                      style: TextStyle(
                        color: _loading
                            ? AppColors.textHint
                            : AppColors.accentLight,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
