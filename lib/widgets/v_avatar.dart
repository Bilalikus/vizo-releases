import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/constants.dart';

/// Premium avatar widget with accent glow border.
/// Supports base64 data URIs, network URLs, and initials fallback.
class VAvatar extends StatelessWidget {
  const VAvatar({
    super.key,
    this.imageUrl,
    this.radius = 28,
    this.name,
    this.borderWidth = 2.0,
    this.showGlow = false,
  });

  final String? imageUrl;
  final double radius;
  final String? name;
  final double borderWidth;
  final bool showGlow;

  String get _initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final isBase64 = hasImage && imageUrl!.startsWith('data:');

    Uint8List? base64Bytes;
    if (isBase64) {
      try {
        final split = imageUrl!.split(',');
        if (split.length == 2) {
          base64Bytes = base64Decode(split[1]);
        }
      } catch (_) {}
    }

    return Container(
      width: radius * 2 + borderWidth * 2,
      height: radius * 2 + borderWidth * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, AppColors.accentLight],
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.all(borderWidth),
      child: ClipOval(
        child: base64Bytes != null
            ? Image.memory(
                base64Bytes,
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
                errorBuilder: (_, __, ___) =>
                    _InitialsContent(initials: _initials, radius: radius),
              )
            : hasImage
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _InitialsContent(
                      initials: _initials,
                      radius: radius,
                    ),
                    errorWidget: (_, __, ___) => _InitialsContent(
                      initials: _initials,
                      radius: radius,
                    ),
                  )
                : _InitialsContent(initials: _initials, radius: radius),
      ),
    );
  }
}

class _InitialsContent extends StatelessWidget {
  const _InitialsContent({required this.initials, required this.radius});
  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceBright,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: radius * 0.55,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
