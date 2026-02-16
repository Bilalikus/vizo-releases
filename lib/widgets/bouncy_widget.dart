import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive bouncy wrapper — widgets stretch/follow finger when dragged.
/// Provides premium rubber-band feel on press and drag.
class BouncyWidget extends StatefulWidget {
  const BouncyWidget({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.95,
    this.enableDragStretch = true,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final bool enableDragStretch;
  final bool haptic;

  @override
  State<BouncyWidget> createState() => _BouncyWidgetState();
}

class _BouncyWidgetState extends State<BouncyWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  Offset _dragOffset = Offset.zero;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic, reverseCurve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDown(DragStartDetails _) {
    _pressed = true;
    _ctrl.forward();
    if (widget.haptic) HapticFeedback.lightImpact();
  }

  void _onUpdate(DragUpdateDetails details) {
    if (!widget.enableDragStretch) return;
    setState(() {
      _dragOffset += details.delta * 0.3; // damped drag
    });
  }

  void _onEnd(DragEndDetails _) {
    _ctrl.reverse();
    setState(() => _dragOffset = Offset.zero);
    if (_pressed) {
      _pressed = false;
      widget.onTap?.call();
    }
  }

  void _onCancel() {
    _ctrl.reverse();
    _pressed = false;
    setState(() => _dragOffset = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onDown,
      onPanUpdate: _onUpdate,
      onPanEnd: _onEnd,
      onPanCancel: _onCancel,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.translate(
          offset: _dragOffset,
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
