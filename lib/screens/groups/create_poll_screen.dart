import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

/// Create a poll in a group or community chat.
class CreatePollScreen extends ConsumerStatefulWidget {
  const CreatePollScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends ConsumerState<CreatePollScreen> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _sending = false;
  bool _anonymous = false;
  bool _multipleChoice = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionCtrls.length >= 10) return;
    setState(() => _optionCtrls.add(TextEditingController()));
    HapticFeedback.selectionClick();
  }

  void _removeOption(int index) {
    if (_optionCtrls.length <= 2) return;
    setState(() {
      _optionCtrls[index].dispose();
      _optionCtrls.removeAt(index);
    });
  }

  Future<void> _createPoll() async {
    final question = _questionCtrl.text.trim();
    final options = _optionCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите вопрос')),
      );
      return;
    }
    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Минимум 2 варианта')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final uid = ref.read(authServiceProvider).effectiveUid;
      final user = ref.read(currentUserProvider);

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add({
        'senderId': uid,
        'senderName': user.displayName,
        'text': '📊 $question',
        'type': 'poll',
        'pollQuestion': question,
        'pollOptions': options,
        'pollVotes': <String, dynamic>{},
        'pollAnonymous': _anonymous,
        'pollMultiple': _multipleChoice,
        'isDeleted': false,
        'reactions': <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Опрос создан ✓')),
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
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              size: 22, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Создать опрос',
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
                  : const Icon(Icons.check_rounded,
                      color: AppColors.accent),
              onPressed: _sending ? null : _createPoll,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Question
          VTextField(
            controller: _questionCtrl,
            hint: 'Вопрос опроса',
            prefixIcon: const Icon(Icons.help_outline_rounded,
                size: 20, color: AppColors.textHint),
            maxLines: 3,
          ),

          const SizedBox(height: 20),

          // Options header
          Row(
            children: [
              Text('Варианты ответа',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent.withValues(alpha: 0.7))),
              const Spacer(),
              Text('${_optionCtrls.length}/10',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint.withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 8),

          // Options list
          ...List.generate(_optionCtrls.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: VTextField(
                      controller: _optionCtrls[i],
                      hint: 'Вариант ${i + 1}',
                    ),
                  ),
                  if (_optionCtrls.length > 2)
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline_rounded,
                          size: 20,
                          color: AppColors.error.withValues(alpha: 0.6)),
                      onPressed: () => _removeOption(i),
                    ),
                ],
              ),
            );
          }),

          // Add option button
          if (_optionCtrls.length < 10)
            GestureDetector(
              onTap: _addOption,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded,
                        size: 18, color: AppColors.accent),
                    SizedBox(width: 6),
                    Text('Добавить вариант',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.accent)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Options toggles
          VCard(
            enableDragStretch: false,
            child: Row(
              children: [
                const Icon(Icons.visibility_off_rounded,
                    size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Анонимное голосование',
                      style: TextStyle(
                          fontSize: 15, color: AppColors.textPrimary)),
                ),
                Switch.adaptive(
                  value: _anonymous,
                  activeTrackColor: AppColors.accent,
                  onChanged: (v) => setState(() => _anonymous = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          VCard(
            enableDragStretch: false,
            child: Row(
              children: [
                const Icon(Icons.checklist_rounded,
                    size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Множественный выбор',
                      style: TextStyle(
                          fontSize: 15, color: AppColors.textPrimary)),
                ),
                Switch.adaptive(
                  value: _multipleChoice,
                  activeTrackColor: AppColors.accent,
                  onChanged: (v) => setState(() => _multipleChoice = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
