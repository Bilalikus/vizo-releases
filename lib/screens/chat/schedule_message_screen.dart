import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Schedule a message to send later.
class ScheduleMessageScreen extends ConsumerStatefulWidget {
  const ScheduleMessageScreen({
    super.key,
    required this.chatId,
    required this.peerId,
    this.isGroup = false,
  });

  final String chatId;
  final String peerId;
  final bool isGroup;

  @override
  ConsumerState<ScheduleMessageScreen> createState() =>
      _ScheduleMessageScreenState();
}

class _ScheduleMessageScreenState
    extends ConsumerState<ScheduleMessageScreen> {
  final _msgCtrl = TextEditingController();
  DateTime _scheduledDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _scheduledTime = TimeOfDay.now();
  bool _sending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.surfaceLight,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() => _scheduledDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.surfaceLight,
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) {
      setState(() => _scheduledTime = time);
    }
  }

  Future<void> _schedule() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите сообщение')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final uid = ref.read(authServiceProvider).effectiveUid;
      final user = ref.read(currentUserProvider);

      final scheduledAt = DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        _scheduledTime.hour,
        _scheduledTime.minute,
      );

      if (scheduledAt.isBefore(DateTime.now())) {
        if (mounted) {
          setState(() => _sending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Время уже прошло')),
          );
        }
        return;
      }

      final collection = widget.isGroup ? 'groups' : 'chats';

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(widget.chatId)
          .collection('scheduled_messages')
          .add({
        'senderId': uid,
        'senderName': user.displayName,
        'text': text,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'isSent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Запланировано на ${scheduledAt.day}.${scheduledAt.month.toString().padLeft(2, '0')} в ${_scheduledTime.format(context)}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_scheduledDate.day}.${_scheduledDate.month.toString().padLeft(2, '0')}.${_scheduledDate.year}';

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
                icon: const Icon(Icons.close_rounded,
                    size: 22, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Запланировать',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              centerTitle: true,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.accent))
                        : const Icon(Icons.schedule_send_rounded,
                            color: AppColors.accent),
                    onPressed: _sending ? null : _schedule,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Message input
          VTextField(
            controller: _msgCtrl,
            hint: 'Текст сообщения...',
            maxLines: 5,
            prefixIcon: const Icon(Icons.message_rounded,
                size: 20, color: AppColors.textHint),
          ),

          const SizedBox(height: 24),

          // Date picker
          VCard(
            enableDragStretch: false,
            onTap: _pickDate,
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 20, color: AppColors.accent),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Дата',
                      style: TextStyle(
                          fontSize: 15, color: AppColors.textPrimary)),
                ),
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.accentLight)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textHint),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Time picker
          VCard(
            enableDragStretch: false,
            onTap: _pickTime,
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 20, color: AppColors.accent),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Время',
                      style: TextStyle(
                          fontSize: 15, color: AppColors.textPrimary)),
                ),
                Text(_scheduledTime.format(context),
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.accentLight)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textHint),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.accent.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Сообщение будет отправлено в указанное время, когда приложение открыто.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
