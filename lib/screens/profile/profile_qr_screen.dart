import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';

/// Profile QR code screen — generates a real scannable QR code.
class ProfileQrScreen extends ConsumerWidget {
  const ProfileQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final phone = user.phoneNumber;
    final name = user.displayName.isNotEmpty ? user.displayName : phone;
    final uid = user.uid;

    // QR data: vizo://user/<uid>?phone=<phone>&name=<name>
    final qrData = 'vizo://user/$uid?phone=${Uri.encodeComponent(phone)}&name=${Uri.encodeComponent(name)}';

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
              title: const Text('Мой QR-код',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── QR Code ──────────
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 248,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF8A2BE2),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Color(0xFF1A1A1A),
                  ),
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: 24),
              Text(name,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(phone,
                  style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary
                          .withValues(alpha: 0.7))),
              const SizedBox(height: 8),
              // ─── @Name tag ──────────
              if (name != phone)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '@$name',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              // ─── Share button ──────────
              GestureDetector(
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: 'Vizo: $phone'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          const Text('Контакт скопирован в буфер'),
                      backgroundColor:
                          AppColors.accent.withValues(alpha: 0.9),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.7),
                        AppColors.accentLight.withValues(alpha: 0.5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.share_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text('Поделиться',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Покажите этот QR-код для быстрого добавления в контакты',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textHint.withValues(alpha: 0.5))),
            ],
          ),
        ),
      ),
    );
  }
}
