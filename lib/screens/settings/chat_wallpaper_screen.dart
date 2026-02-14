import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/constants.dart';

/// Chat wallpaper selection screen.
class ChatWallpaperScreen extends StatefulWidget {
  const ChatWallpaperScreen({super.key});

  @override
  State<ChatWallpaperScreen> createState() => _ChatWallpaperScreenState();
}

class _ChatWallpaperScreenState extends State<ChatWallpaperScreen> {
  int _selectedIndex = 0;

  static const List<_WallpaperOption> _wallpapers = [
    _WallpaperOption('Нет', null, [Color(0xFF000000), Color(0xFF000000)]),
    _WallpaperOption(
        'Ночь', Icons.nightlight_rounded, [Color(0xFF0D1117), Color(0xFF161B22)]),
    _WallpaperOption(
        'Космос', Icons.auto_awesome, [Color(0xFF0F0C29), Color(0xFF302B63)]),
    _WallpaperOption(
        'Океан', Icons.water_rounded, [Color(0xFF0F2027), Color(0xFF2C5364)]),
    _WallpaperOption(
        'Лес', Icons.forest_rounded, [Color(0xFF0D1F0F), Color(0xFF1B3A1D)]),
    _WallpaperOption(
        'Огонь', Icons.local_fire_department_rounded, [Color(0xFF1A0A00), Color(0xFF3D1A00)]),
    _WallpaperOption(
        'Фиолет', Icons.blur_on_rounded, [Color(0xFF1A002E), Color(0xFF2D0050)]),
    _WallpaperOption(
        'Минимал', Icons.grid_view_rounded, [Color(0xFF111111), Color(0xFF1A1A1A)]),
    _WallpaperOption(
        'Полночь', Icons.dark_mode_rounded, [Color(0xFF000428), Color(0xFF004E92)]),
    _WallpaperOption(
        'Пурпур', Icons.gradient_rounded, [Color(0xFF200122), Color(0xFF6F0000)]),
    _WallpaperOption(
        'Тёмный металл', Icons.hexagon_rounded, [Color(0xFF141E30), Color(0xFF243B55)]),
    _WallpaperOption(
        'Янтарь', Icons.wb_sunny_rounded, [Color(0xFF1A1200), Color(0xFF332600)]),
  ];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final p = await SharedPreferences.getInstance();
    final idx = p.getInt('pref_wallpaper') ?? 0;
    if (idx < _wallpapers.length) {
      setState(() => _selectedIndex = idx);
    }
  }

  Future<void> _select(int index) async {
    setState(() => _selectedIndex = index);
    final p = await SharedPreferences.getInstance();
    await p.setInt('pref_wallpaper', index);
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
              title: const Text('Обои чата',
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
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: _wallpapers.length,
        itemBuilder: (_, i) {
          final w = _wallpapers[i];
          final isSelected = i == _selectedIndex;
          return GestureDetector(
            onTap: () => _select(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: w.colors,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accent
                      : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 2 : 0.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (w.icon != null)
                    Icon(w.icon,
                        size: 32,
                        color: Colors.white.withValues(alpha: 0.6)),
                  const SizedBox(height: 8),
                  Text(w.name,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400)),
                  if (isSelected) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WallpaperOption {
  final String name;
  final IconData? icon;
  final List<Color> colors;

  const _WallpaperOption(this.name, this.icon, this.colors);
}
