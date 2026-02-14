import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/constants.dart';

/// Full-screen image viewer with zoom & pan.
/// Supports: network URLs, base64 bytes, local file paths.
class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    this.imageUrl,
    this.imageBytes,
    this.senderName,
    this.timestamp,
    this.heroTag,
  });

  final String? imageUrl;
  final Uint8List? imageBytes;
  final String? senderName;
  final DateTime? timestamp;
  final String? heroTag;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen>
    with SingleTickerProviderStateMixin {
  final _transformCtrl = TransformationController();
  late AnimationController _fadeCtrl;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
    if (_showOverlay) {
      _fadeCtrl.forward();
    } else {
      _fadeCtrl.reverse();
    }
  }

  Widget _buildImage() {
    // Priority 1: raw bytes (from base64 decode)
    if (widget.imageBytes != null) {
      return Image.memory(
        widget.imageBytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _errorWidget(),
      );
    }

    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return _errorWidget();

    // Priority 2: local file path
    if (url.startsWith('/') || url.startsWith('file:')) {
      final file = File(url.replaceFirst('file://', ''));
      return Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _errorWidget(),
      );
    }

    // Priority 3: network URL
    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded /
                    progress.expectedTotalBytes!
                : null,
            color: AppColors.accent,
            strokeWidth: 2,
          ),
        );
      },
      errorBuilder: (_, __, ___) => _errorWidget(),
    );
  }

  Widget _errorWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_rounded,
            size: 64,
            color: AppColors.textHint.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text('Не удалось загрузить',
            style: TextStyle(
                color: AppColors.textHint.withValues(alpha: 0.6))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = widget.timestamp != null
        ? '${widget.timestamp!.day}.${widget.timestamp!.month.toString().padLeft(2, '0')}.${widget.timestamp!.year} ${widget.timestamp!.hour.toString().padLeft(2, '0')}:${widget.timestamp!.minute.toString().padLeft(2, '0')}'
        : '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Zoomable Image ──────────
          GestureDetector(
            onTap: _toggleOverlay,
            child: InteractiveViewer(
              transformationController: _transformCtrl,
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(child: _buildImage()),
            ),
          ),

          // ─── Top Bar ──────────
          FadeTransition(
            opacity: _fadeCtrl,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 8,
                    right: 16,
                    bottom: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.senderName != null)
                              Text(widget.senderName!,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            if (timeStr.isNotEmpty)
                              Text(timeStr,
                                  style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.6),
                                      fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── Bottom actions ──────────
          FadeTransition(
            opacity: _fadeCtrl,
            child: Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                      top: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.black.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _BottomAction(
                          icon: Icons.zoom_in_rounded,
                          label: 'Увеличить',
                          onTap: () {
                            final current = _transformCtrl.value.clone();
                            current.scale(1.5);
                            _transformCtrl.value = current;
                          },
                        ),
                        _BottomAction(
                          icon: Icons.zoom_out_rounded,
                          label: 'Уменьшить',
                          onTap: () {
                            _transformCtrl.value = Matrix4.identity();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
        ],
      ),
    );
  }
}
