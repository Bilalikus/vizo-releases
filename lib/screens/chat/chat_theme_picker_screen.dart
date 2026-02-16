import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/constants.dart';

/// Chat theme picker — per-chat gradient/accent customization.
class ChatThemePickerScreen extends StatefulWidget {
  const ChatThemePickerScreen({
    super.key,
    required this.chatId,
    this.isGroup = false,
  });

  final String chatId;
  final bool isGroup;

  @override
  State<ChatThemePickerScreen> createState() => _ChatThemePickerScreenState();
}

class _ChatThemePickerScreenState extends State<ChatThemePickerScreen> {
  String _selectedTheme = 'default';

  static const themes = <String, _ThemeData>{
    'default': _ThemeData('По умолчанию', [Color(0xFF0D1B2A), Color(0xFF1B2838)]),
    'midnight': _ThemeData('Полночь', [Color(0xFF0B0E2D), Color(0xFF1A1040)]),
    'ocean': _ThemeData('Океан', [Color(0xFF0A1628), Color(0xFF0D2137)]),
    'forest': _ThemeData('Лес', [Color(0xFF0A1A10), Color(0xFF122A18)]),
    'purple': _ThemeData('Аметист', [Color(0xFF1A0A28), Color(0xFF2D1040)]),
    'crimson': _ThemeData('Рубин', [Color(0xFF2A0A0A), Color(0xFF401010)]),
    'teal': _ThemeData('Бирюза', [Color(0xFF0A2828), Color(0xFF104040)]),
    'gold': _ThemeData('Золото', [Color(0xFF1A1A0A), Color(0xFF2D2D10)]),
    'slate': _ThemeData('Сланец', [Color(0xFF0D0D1A), Color(0xFF15152A)]),
    'rose': _ThemeData('Роза', [Color(0xFF1A0D1A), Color(0xFF2A152A)]),
    'arctic': _ThemeData('Арктика', [Color(0xFF0D1A1A), Color(0xFF152A2A)]),
    'carbon': _ThemeData('Карбон', [Color(0xFF1A1A1A), Color(0xFF2A2A2A)]),
  };

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final collection = widget.isGroup ? 'groups' : 'chats';
    final doc = await FirebaseFirestore.instance
        .collection(collection)
        .doc(widget.chatId)
        .get();
    final theme = doc.data()?['theme'] as String? ?? 'default';
    if (mounted) setState(() => _selectedTheme = theme);
  }

  Future<void> _applyTheme(String theme) async {
    HapticFeedback.selectionClick();
    setState(() => _selectedTheme = theme);
    final collection = widget.isGroup ? 'groups' : 'chats';
    await FirebaseFirestore.instance
        .collection(collection)
        .doc(widget.chatId)
        .set({'theme': theme}, SetOptions(merge: true));
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
              title: const Text('Тема чата',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
        ),
        itemCount: themes.length,
        itemBuilder: (_, i) {
          final key = themes.keys.elementAt(i);
          final data = themes[key]!;
          final selected = key == _selectedTheme;

          return GestureDetector(
            onTap: () => _applyTheme(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: data.colors,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? AppColors.accent
                      : Colors.white.withValues(alpha: 0.08),
                  width: selected ? 2 : 0.5,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  // Gradient overlay with name
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                      child: Text(
                        data.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Checkmark
                  if (selected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  // Sample bubbles
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Привет!',
                          style: TextStyle(
                              fontSize: 10, color: Colors.white70)),
                    ),
                  ),
                  Positioned(
                    top: 36,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Здравствуй!',
                          style: TextStyle(
                              fontSize: 10, color: Colors.white70)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThemeData {
  const _ThemeData(this.name, this.colors);
  final String name;
  final List<Color> colors;
}
