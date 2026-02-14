import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';

/// LiquidGlass card — frosted blur with translucent tint and luminous border.
class VCard extends StatefulWidget {
  const VCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? borderColor;

  @override
  State<VCard> createState() => _VCardState();
}

class _VCardState extends State<VCard> {
  bool _isHovering = false;
  bool _isPressed = false;

  bool get _isActive => _isHovering || _isPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      _isActive ? AppSizes.radiusSmall : AppSizes.radiusLarge,
    );

    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTapDown: widget.onTap != null
              ? (_) => setState(() => _isPressed = true)
              : null,
          onTapUp: widget.onTap != null
              ? (_) {
                  setState(() => _isPressed = false);
                  widget.onTap?.call();
                }
              : null,
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1.0,
            duration: AppSizes.animFast,
            child: AnimatedContainer(
              duration: AppSizes.animNormal,
              curve: Curves.easeOutCubic,
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: widget.padding ?? const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: _isHovering ? 0.14 : 0.08),
                          Colors.white.withValues(alpha: _isHovering ? 0.08 : 0.04),
                        ],
                      ),
                      borderRadius: radius,
                      border: Border.all(
                        color: widget.borderColor ??
                            (_isHovering
                                ? AppColors.accent.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.12)),
                        width: 0.5,
                      ),
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
