import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/constants.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../call/call_screen.dart';
import '../chat/chat_screen.dart';
import 'contact_editor_screen.dart';
import 'contact_notes_screen.dart';

/// Contacts list — premium design with search, call, and chat actions.
class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key});

  @override
  ConsumerState<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ContactModel> _filter(List<ContactModel> contacts) {
    var result = List<ContactModel>.from(contacts);
    // Sort favorites to top
    result.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    if (_query.isEmpty) return result;
    final q = _query.toLowerCase();
    return result.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.phoneNumber.contains(q) ||
          c.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _callContact(ContactModel contact, {bool isVideoCall = false}) async {
    final authService = ref.read(authServiceProvider);
    final firestoreService = ref.read(firestoreServiceProvider);
    final currentUser = ref.read(currentUserProvider);

    // Look up receiver in Vizo
    final receiver =
        await firestoreService.findUserByPhone(contact.phoneNumber);

    if (receiver != null && receiver.uid.isNotEmpty) {
      // In-app call
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callerId: authService.effectiveUid,
            callerName: currentUser.displayName.isNotEmpty
                ? currentUser.displayName
                : currentUser.phoneNumber,
            receiverId: receiver.uid,
            receiverName: contact.name,
            receiverAvatarUrl: receiver.effectiveAvatar,
            isVideoCall: isVideoCall,
          ),
        ),
      );
    } else {
      // Not on Vizo — show snackbar
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${contact.name} не зарегистрирован в Vizo'),
        ),
      );
    }
  }

  Future<void> _chatWithContact(ContactModel contact) async {
    final firestoreService = ref.read(firestoreServiceProvider);
    final receiver =
        await firestoreService.findUserByPhone(contact.phoneNumber);

    if (receiver != null && receiver.uid.isNotEmpty) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            peerId: receiver.uid,
            peerName: contact.name,
            peerAvatarUrl: receiver.effectiveAvatar,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пользователь не зарегистрирован в Vizo для чата'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(contactsProvider);
    final filtered = _filter(contacts);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: CustomScrollView(
        slivers: [
          // ─── Header ─────────────────────────
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.sm),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Контакты',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                    VIconButton(
                      icon: Icons.person_add_rounded,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContactEditorScreen(),
                        ),
                      ),
                      tooltip: 'Добавить контакт',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Search ─────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.lg, vertical: AppSizes.sm),
              child: VTextField(
                controller: _searchCtrl,
                hint: 'Поиск контактов...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textHint, size: 20),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),

          // ─── List ───────────────────────────
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline_rounded,
                        size: 56,
                        color: AppColors.textHint.withValues(alpha: 0.4)),
                    const SizedBox(height: AppSizes.md),
                    Text(
                      contacts.isEmpty
                          ? 'Нет контактов'
                          : 'Ничего не найдено',
                      style: TextStyle(
                        color: AppColors.textHint.withValues(alpha: 0.6),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              sliver: SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) => _ContactTile(
                  contact: filtered[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ContactEditorScreen(contact: filtered[i]),
                    ),
                  ),
                  onCall: () => _callContact(filtered[i]),
                  onVideoCall: () => _callContact(filtered[i], isVideoCall: true),
                  onChat: () => _chatWithContact(filtered[i]),
                  onToggleFavorite: () async {
                    final c = filtered[i];
                    final fs = ref.read(firestoreServiceProvider);
                    await fs.updateContact(c.copyWith(
                      isFavorite: !c.isFavorite,
                    ));
                  },
                  onNotes: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ContactNotesScreen(contact: filtered[i]),
                    ),
                  ),
                ),
              ),
            ),

          SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ─── Contact Tile ────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.onTap,
    required this.onCall,
    required this.onChat,
    required this.onToggleFavorite,
    this.onVideoCall,
    this.onNotes,
  });

  final ContactModel contact;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onChat;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onVideoCall;
  final VoidCallback? onNotes;

  @override
  Widget build(BuildContext context) {
    // Real-time check if contact is registered in Vizo
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: contact.phoneNumber)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        final isInVizo = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        bool isOnline = false;
        String? peerAvatar;
        if (isInVizo) {
          final data =
              snapshot.data!.docs.first.data() as Map<String, dynamic>?;
          isOnline = data?['isOnline'] as bool? ?? false;
          peerAvatar = data?['avatarBase64'] as String? ??
              data?['avatarUrl'] as String?;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.xs),
          child: VCard(
            onTap: onTap,
            child: Row(
              children: [
                Stack(
                  children: [
                    VAvatar(
                      imageUrl: peerAvatar ?? contact.avatarUrl,
                      name: contact.name,
                      radius: 22,
                    ),
                    // Online indicator
                    if (isInVizo)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? AppColors.success
                                : AppColors.textHint,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.black,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contact.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isInVizo)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                    AppSizes.radiusSmall),
                                border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.2),
                                  width: 0.5,
                                ),
                              ),
                              child: const Text(
                                'Vizo',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accentLight,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contact.phoneNumber,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                      if (contact.tags.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: contact.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radiusSmall),
                                border: Border.all(
                                  color: AppColors.accent.withValues(alpha: 0.15),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.accentLight,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (contact.notes != null &&
                          contact.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.note_rounded,
                                size: 12,
                                color: AppColors.accent.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Text('Есть заметка',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.accent
                                        .withValues(alpha: 0.5))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                if (onNotes != null)
                  GestureDetector(
                    onTap: onNotes,
                    child: Icon(
                      Icons.note_add_outlined,
                      size: 20,
                      color: AppColors.textHint.withValues(alpha: 0.5),
                    ),
                  ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onToggleFavorite,
                  child: Icon(
                    contact.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 22,
                    color: contact.isFavorite
                        ? Colors.amber
                        : AppColors.textHint.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 4),
                if (isInVizo)
                  VIconButton(
                    icon: Icons.chat_rounded,
                    onPressed: onChat,
                    color: AppColors.accent,
                    size: 38,
                    tooltip: 'Чат',
                  ),
                if (isInVizo && onVideoCall != null)
                  VIconButton(
                    icon: Icons.videocam_rounded,
                    onPressed: onVideoCall!,
                    color: AppColors.accentLight,
                    size: 38,
                    tooltip: 'Видеозвонок',
                  ),
                VIconButton(
                  icon: Icons.call_rounded,
                  onPressed: onCall,
                  color: AppColors.success,
                  size: 42,
                  tooltip: 'Позвонить',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
