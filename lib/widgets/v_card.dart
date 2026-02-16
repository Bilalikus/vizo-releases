import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/constants.dart';

/// LiquidGlass card — frosted blur with translucent tint, luminous border,
/// and interactive bouncy drag-stretch effect.
class VCard extends StatefulWidget {
  const VCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.borderColor,
    this.enableDragStretch = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? borderColor;
  final bool enableDragStretch;

  @override
  State<VCard> createState() => _VCardState();
}

class _VCardState extends State<VCard> with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  bool _isPressed = false;
  Offset _dragOffset = Offset.zero;
  late AnimationController _bounceCtrl;

  bool get _isActive => _isHovering || _isPressed;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails _) {
    if (!widget.enableDragStretch) return;
    setState(() => _isPressed = true);
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.enableDragStretch) return;
    setState(() {
      // Rubberband: damped drag offset
      _dragOffset = Offset(
        (_dragOffset.dx + details.delta.dx * 0.35).clamp(-40.0, 40.0),
        (_dragOffset.dy + details.delta.dy * 0.25).clamp(-20.0, 20.0),
      );
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (!widget.enableDragStretch) {
      setState(() => _isPressed = false);
      return;
    }
    // Spring back to center
    setState(() {
      _isPressed = false;
      _dragOffset = Offset.zero;
    });
    // Call tap if drag was minimal
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      _isActive ? AppSizes.radiusSmall : AppSizes.radiusLarge,
    );

    // Compute subtle rotation from drag offset
    final rotationX = _dragOffset.dy * 0.002;
    final rotationY = -_dragOffset.dx * 0.002;

    Widget cardContent = ClipRRect(
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
                  HapticFeedback.lightImpact();
                  widget.onTap?.call();
                }
              : null,
          onTapCancel: () => setState(() {
            _isPressed = false;
            _dragOffset = Offset.zero;
          }),
          onLongPress: widget.onLongPress,
          onPanStart: widget.enableDragStretch ? _onPanStart : null,
          onPanUpdate: widget.enableDragStretch ? _onPanUpdate : null,
          onPanEnd: widget.enableDragStretch ? _onPanEnd : null,
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1.0,
            duration: AppSizes.animFast,
            child: AnimatedContainer(
              duration: _isPressed ? AppSizes.animFast : const Duration(milliseconds: 400),
              curve: _isPressed ? Curves.easeOutCubic : Curves.elasticOut,
              transform: Matrix4.identity()
                ..setEntry(0, 3, _dragOffset.dx)
                ..setEntry(1, 3, _dragOffset.dy)
                ..rotateX(rotationX)
                ..rotateY(rotationY),
              transformAlignment: Alignment.center,
              child: cardContent,
            ),
          ),
        ),
      ),
    );
  }
}
