import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';

/// Reusable LiquidGlass container — frosted glass effect with blur,
/// tinted translucency and subtle luminous border.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.blur = 24.0,
    this.opacity = 0.12,
    this.tint,
    this.borderOpacity = 0.15,
    this.borderWidth = 0.5,
    this.shape = BoxShape.rectangle,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double blur;
  final double opacity;
  final Color? tint;
  final double borderOpacity;
  final double borderWidth;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppSizes.radiusLarge);
    final bg = tint ?? Colors.white;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: shape == BoxShape.circle
            ? BorderRadius.circular(999)
            : radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: bg.withValues(alpha: opacity),
              borderRadius: shape == BoxShape.circle ? null : radius,
              shape: shape,
              border: Border.all(
                color: Colors.white.withValues(alpha: borderOpacity),
                width: borderWidth,
              ),
              // Subtle inner highlight at the top edge
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: opacity + 0.04),
                  bg.withValues(alpha: opacity - 0.02),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
