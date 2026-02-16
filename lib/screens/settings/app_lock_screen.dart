import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/constants.dart';
import '../../widgets/widgets.dart';

/// App lock — PIN or biometric lock.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _lockEnabled = false;
  // ignore: unused_field
  String _pin = '';
  String _enteredPin = '';
  bool _isSettingUp = false;
  String _firstPin = '';

  @override
  void initState() {
    super.initState();
    _loadLock();
  }

  Future<void> _loadLock() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _lockEnabled = p.getBool('app_lock_enabled') ?? false;
      _pin = p.getString('app_lock_pin') ?? '';
    });
  }

  Future<void> _saveLock(bool enabled, String pin) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('app_lock_enabled', enabled);
    await p.setString('app_lock_pin', pin);
    setState(() {
      _lockEnabled = enabled;
      _pin = pin;
    });
  }

  void _onDigit(int digit) {
    if (_enteredPin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() => _enteredPin += '$digit');

    if (_enteredPin.length == 4) {
      if (_isSettingUp) {
        if (_firstPin.isEmpty) {
          // First entry
          _firstPin = _enteredPin;
          setState(() => _enteredPin = '');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Повторите PIN')),
          );
        } else {
          // Confirm
          if (_enteredPin == _firstPin) {
            _saveLock(true, _enteredPin);
            setState(() {
              _isSettingUp = false;
              _firstPin = '';
              _enteredPin = '';
            });
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PIN установлен ✓')),
            );
          } else {
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PIN не совпадает')),
            );
            setState(() {
              _firstPin = '';
              _enteredPin = '';
            });
          }
        }
      }
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() => _enteredPin =
          _enteredPin.substring(0, _enteredPin.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
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
              title: const Text('Блокировка',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: _isSettingUp
          ? _buildPinEntry()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                VCard(
                  enableDragStretch: false,
                  child: Row(
                    children: [
                      const Icon(Icons.lock_rounded,
                          size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('PIN-блокировка',
                            style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textPrimary)),
                      ),
                      Switch.adaptive(
                        value: _lockEnabled,
                        activeTrackColor: AppColors.accent,
                        onChanged: (v) {
                          if (v) {
                            setState(() {
                              _isSettingUp = true;
                              _enteredPin = '';
                              _firstPin = '';
                            });
                          } else {
                            _saveLock(false, '');
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                if (_lockEnabled) ...[
                  VCard(
                    enableDragStretch: false,
                    onTap: () {
                      setState(() {
                        _isSettingUp = true;
                        _enteredPin = '';
                        _firstPin = '';
                      });
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.edit_rounded,
                            size: 20, color: AppColors.textSecondary),
                        SizedBox(width: 12),
                        Text('Изменить PIN',
                            style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textPrimary)),
                        Spacer(),
                        Icon(Icons.chevron_right_rounded,
                            size: 20, color: AppColors.textHint),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            AppColors.accent.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18,
                          color:
                              AppColors.accent.withValues(alpha: 0.6)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'PIN-код запрашивается при каждом запуске приложения.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPinEntry() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _firstPin.isEmpty ? 'Введите PIN' : 'Повторите PIN',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 32),

        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final filled = i < _enteredPin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: filled ? 16 : 14,
              height: filled ? 16 : 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? AppColors.accent
                    : Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: filled
                      ? AppColors.accent
                      : Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 48),

        // Number pad
        ...List.generate(3, (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (col) {
                final digit = row * 3 + col + 1;
                return _PinButton(
                  label: '$digit',
                  onTap: () => _onDigit(digit),
                );
              }),
            ),
          );
        }),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            _PinButton(label: '0', onTap: () => _onDigit(0)),
            SizedBox(
              width: 80,
              height: 60,
              child: GestureDetector(
                onTap: _onDelete,
                child: const Center(
                  child: Icon(Icons.backspace_outlined,
                      color: AppColors.textSecondary, size: 22),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        TextButton(
          onPressed: () => setState(() {
            _isSettingUp = false;
            _enteredPin = '';
            _firstPin = '';
          }),
          child: const Text('Отмена',
              style: TextStyle(color: AppColors.textHint)),
        ),
      ],
    );
  }
}

class _PinButton extends StatelessWidget {
  const _PinButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
