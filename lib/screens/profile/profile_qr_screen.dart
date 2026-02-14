import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';

/// Profile QR code screen — generates a QR-like visual code for sharing.
class ProfileQrScreen extends ConsumerWidget {
  const ProfileQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final phone = user.phoneNumber;
    final name = user.displayName.isNotEmpty ? user.displayName : phone;

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
              // ─── QR Visual ──────────
              Container(
                width: 260,
                height: 260,
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
                child: Center(
                  child: CustomPaint(
                    size: const Size(220, 220),
                    painter: _QrPatternPainter(phone),
                  ),
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
              const SizedBox(height: 32),
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
              Text('Покажите этот код другу для быстрого добавления',
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

/// Custom painter that generates a pseudo-QR pattern from a phone string.
class _QrPatternPainter extends CustomPainter {
  _QrPatternPainter(this.data);
  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 21;
    final paint = Paint()..color = Colors.black;

    // Generate a deterministic grid from the phone number
    final grid = List.generate(21, (row) {
      return List.generate(21, (col) {
        // Corner positioning squares
        if (_isCornerSquare(row, col)) return true;
        // Generate pattern from data hash
        final hash = (data.hashCode + row * 31 + col * 17) & 0x7FFFFFFF;
        return hash % 3 != 0;
      });
    });

    for (int r = 0; r < 21; r++) {
      for (int c = 0; c < 21; c++) {
        if (grid[r][c]) {
          final rect = Rect.fromLTWH(
            c * cellSize,
            r * cellSize,
            cellSize - 0.5,
            cellSize - 0.5,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            paint,
          );
        }
      }
    }

    // Draw Vizo logo in center
    final center = Offset(size.width / 2, size.height / 2);
    final logoPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, cellSize * 2.5, logoPaint);
    final accentPaint = Paint()..color = AppColors.accent;
    canvas.drawCircle(center, cellSize * 2, accentPaint);

    // V letter
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'V',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2),
    );
  }

  bool _isCornerSquare(int row, int col) {
    // Top-left
    if (row < 7 && col < 7) {
      if (row == 0 || row == 6 || col == 0 || col == 6) return true;
      if (row >= 2 && row <= 4 && col >= 2 && col <= 4) return true;
      return false;
    }
    // Top-right
    if (row < 7 && col > 13) {
      final c = col - 14;
      if (row == 0 || row == 6 || c == 0 || c == 6) return true;
      if (row >= 2 && row <= 4 && c >= 2 && c <= 4) return true;
      return false;
    }
    // Bottom-left
    if (row > 13 && col < 7) {
      final r = row - 14;
      if (r == 0 || r == 6 || col == 0 || col == 6) return true;
      if (r >= 2 && r <= 4 && col >= 2 && col <= 4) return true;
      return false;
    }
    return false;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
