import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import 'otp_screen.dart';

/// Phone authentication screen — premium, with Vizo icon.
class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController(text: '+7');
  final _phoneFocus = FocusNode();
  bool _loading = false;
  String? _error;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));

    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _countryController.dispose();
    _phoneFocus.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─── Phone mask: XXX-XXX-XX-XX ──────────────────────

  void _onPhoneChanged() {
    final raw = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted = _applyMask(raw);
    if (formatted != _phoneController.text) {
      _phoneController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    // Rebuild so _isPhoneValid is re-evaluated and the button enables/disables.
    setState(() {});
  }

  String _applyMask(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 10; i++) {
      if (i == 3 || i == 6 || i == 8) buf.write('-');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  String get _fullPhoneNumber {
    final country = _countryController.text.trim();
    final phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return '$country$phone';
  }

  bool get _isPhoneValid {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 10;
  }

  Future<void> _sendOtp() async {
    if (!_isPhoneValid) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final authService = ref.read(authServiceProvider);
    final fullPhone = _fullPhoneNumber;

    ref.read(otpStateProvider.notifier).setPhoneNumber(fullPhone);

    await authService.sendOtp(
      phoneNumber: fullPhone,
      onCodeSent: (verificationId) {
        if (!mounted) return;
        setState(() => _loading = false);
        ref.read(otpStateProvider.notifier).setVerificationId(verificationId);
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const OtpScreen(),
            transitionsBuilder: (_, anim, __, child) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: anim,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = error;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: size.height * 0.06),

                    // ─── Icon with glow ────────────
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            blurRadius: 50,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/Icon.png',
                          width: 100,
                          height: 100,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSizes.xl),

                    // ─── Title ─────────────────────
                    const Text(
                      'Vizo',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -1.5,
                      ),
                    ),

                    const SizedBox(height: AppSizes.sm),

                    Text(
                      'Безопасные звонки с E2E шифрованием',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: AppSizes.xxl),

                    // ─── Phone input ──────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Country code
                        SizedBox(
                          width: 80,
                          child: VTextField(
                            controller: _countryController,
                            hint: '+7',
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[+0-9]'),
                              ),
                              LengthLimitingTextInputFormatter(4),
                            ],
                          ),
                        ),

                        const SizedBox(width: AppSizes.sm),

                        // Phone number
                        Expanded(
                          child: VTextField(
                            controller: _phoneController,
                            focusNode: _phoneFocus,
                            hint: '999-123-45-67',
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9\-]'),
                              ),
                              LengthLimitingTextInputFormatter(13),
                            ],
                            onSubmitted: (_) => _sendOtp(),
                          ),
                        ),
                      ],
                    ),

                    // ─── Error ────────────────────
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
                            Icon(Icons.error_outline_rounded,
                                color: AppColors.error, size: 18),
                            const SizedBox(width: AppSizes.sm),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSizes.lg),

                    // ─── Send OTP ─────────────────
                    VButton(
                      label: 'Получить код',
                      onPressed: _isPhoneValid && !_loading ? _sendOtp : null,
                      isLoading: _loading,
                    ),

                    SizedBox(height: size.height * 0.06),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
