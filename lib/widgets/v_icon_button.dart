import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';

/// LiquidGlass animated icon button — frosted blur background.
class VIconButton extends StatefulWidget {
  const VIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.backgroundColor,
    this.size,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final double? size;
  final String? tooltip;

  @override
  State<VIconButton> createState() => _VIconButtonState();
}

class _VIconButtonState extends State<VIconButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  bool get _isActive => _isHovering || _isPressed;

  @override
  Widget build(BuildContext context) {
    final btnSize = widget.size ?? AppSizes.iconButtonSize;
    final fg = widget.color ?? AppColors.accent;
    final enabled = widget.onPressed != null;

    Widget button = MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _isPressed = false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: () => setState(() => _isPressed = false),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            _isActive ? AppSizes.radiusSmall : AppSizes.radiusDefault,
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
          duration: AppSizes.animNormal,
          curve: Curves.easeOutCubic,
          width: btnSize,
          height: btnSize,
          decoration: BoxDecoration(
            color: _isHovering
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(
              _isActive ? AppSizes.radiusSmall : AppSizes.radiusDefault,
            ),
            border: Border.all(
              color: _isHovering
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          child: AnimatedScale(
            scale: _isPressed ? 0.88 : 1.0,
            duration: AppSizes.animFast,
            child: Icon(
              widget.icon,
              color: enabled ? fg : fg.withValues(alpha: 0.3),
              size: btnSize * 0.42,
            ),
          ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}
