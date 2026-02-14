import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/constants.dart';

/// LiquidGlass animated text field — frosted blur on focus.
class VTextField extends StatefulWidget {
  const VTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.enabled = true,
    this.inputFormatters,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<VTextField> createState() => _VTextFieldState();
}

class _VTextFieldState extends State<VTextField> {
  bool _isFocused = false;
  bool _isHovering = false;

  bool get _isActive => _isFocused || _isHovering;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
        ],
        MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              _isActive ? AppSizes.radiusSmall : AppSizes.radiusDefault,
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _isFocused ? 20 : 12,
                sigmaY: _isFocused ? 20 : 12,
              ),
              child: AnimatedContainer(
            duration: AppSizes.animNormal,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: widget.enabled
                  ? Colors.white.withValues(alpha: _isFocused ? 0.10 : 0.06)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(
                _isActive ? AppSizes.radiusSmall : AppSizes.radiusDefault,
              ),
              border: Border.all(
                color: _isFocused
                    ? AppColors.accent.withValues(alpha: 0.6)
                    : _isHovering
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                width: _isFocused ? 1.0 : 0.5,
              ),
            ),
            child: Focus(
              onFocusChange: (focused) =>
                  setState(() => _isFocused = focused),
              child: TextFormField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                textAlign: widget.textAlign,
                maxLines: widget.maxLines,
                onChanged: widget.onChanged,
                onFieldSubmitted: widget.onSubmitted,
                validator: widget.validator,
                enabled: widget.enabled,
                inputFormatters: widget.inputFormatters,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  letterSpacing: 0.1,
                ),
                cursorColor: AppColors.accent,
                cursorWidth: 1.5,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    color: AppColors.textHint.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                  prefixIcon: widget.prefixIcon,
                  suffixIcon: widget.suffixIcon,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
            ),
          ),
        ),
      ],
    );
  }
}
