import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';

/// LiquidGlass animated button — frosted blur with accent tint.
class VButton extends StatefulWidget {
  const VButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.color,
    this.width,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;
  final double? width;
  final double? height;

  @override
  State<VButton> createState() => _VButtonState();
}

class _VButtonState extends State<VButton> with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  bool _isPressed = false;
  late AnimationController _shimmerController;

  bool get _isActive => _isHovering || _isPressed;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.color ?? AppColors.accent;
    final bool enabled = widget.onPressed != null && !widget.isLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => widget.onPressed?.call() : null,
        onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: enabled
            ? (_) => setState(() => _isPressed = false)
            : null,
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: AppSizes.animNormal,
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: widget.height ?? AppSizes.buttonHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              _isActive ? AppSizes.radiusSmall : AppSizes.radiusDefault,
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
          decoration: BoxDecoration(
            gradient: widget.isOutlined
                ? null
                : (enabled
                    ? LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.7),
                          Color.lerp(accentColor, AppColors.accentLight, 0.3)!.withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null),
            color: widget.isOutlined
                ? Colors.white.withValues(alpha: 0.06)
                : (enabled ? null : accentColor.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(
              _isActive ? AppSizes.radiusSmall : AppSizes.radiusDefault,
            ),
            border: Border.all(
              color: widget.isOutlined
                  ? (enabled
                      ? accentColor.withValues(alpha: 0.5)
                      : accentColor.withValues(alpha: 0.2))
                  : Colors.white.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1.0,
            duration: AppSizes.animFast,
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18,
                            color: widget.isOutlined
                                ? accentColor
                                : AppColors.textPrimary),
                        const SizedBox(width: AppSizes.sm),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: widget.isOutlined
                              ? accentColor
                              : AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
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
