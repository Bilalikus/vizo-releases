import 'package:cloud_firestore/cloud_firestore.dart';

/// A single sticker within a pack.
class Sticker {
  final String id;
  final String emoji;
  final String? label;

  const Sticker({
    required this.id,
    required this.emoji,
    this.label,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'emoji': emoji,
        if (label != null) 'label': label,
      };

  factory Sticker.fromMap(Map<String, dynamic> m) => Sticker(
        id: m['id'] as String? ?? '',
        emoji: m['emoji'] as String? ?? '',
        label: m['label'] as String?,
      );
}

/// A sticker pack with name, author, and list of stickers.
class StickerPack {
  final String id;
  final String name;
  final String authorUid;
  final String authorName;
  final List<Sticker> stickers;
  final DateTime createdAt;
  final bool isDefault;

  const StickerPack({
    required this.id,
    required this.name,
    required this.authorUid,
    this.authorName = '',
    required this.stickers,
    required this.createdAt,
    this.isDefault = false,
  });

  factory StickerPack.empty() => StickerPack(
        id: '',
        name: '',
        authorUid: '',
        stickers: const [],
        createdAt: DateTime.now(),
      );

  bool get isEmpty => id.isEmpty;

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'authorUid': authorUid,
        'authorName': authorName,
        'stickers': stickers.map((s) => s.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
        'isDefault': isDefault,
      };

  factory StickerPack.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final raw = data['stickers'] as List<dynamic>? ?? [];
    return StickerPack(
      id: doc.id,
      name: data['name'] as String? ?? '',
      authorUid: data['authorUid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      stickers: raw
          .map((e) => Sticker.fromMap(e as Map<String, dynamic>))
          .toList(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDefault: data['isDefault'] as bool? ?? false,
    );
  }

  /// Default built-in sticker packs.
  static List<StickerPack> get builtInPacks => [
        StickerPack(
          id: 'emotions',
          name: 'Эмоции',
          authorUid: 'system',
          authorName: 'Vizo',
          isDefault: true,
          createdAt: DateTime(2025),
          stickers: [
            const Sticker(id: 'e1', emoji: '😀', label: 'Улыбка'),
            const Sticker(id: 'e2', emoji: '😂', label: 'Смех'),
            const Sticker(id: 'e3', emoji: '🥰', label: 'Любовь'),
            const Sticker(id: 'e4', emoji: '😎', label: 'Крутой'),
            const Sticker(id: 'e5', emoji: '🤔', label: 'Думаю'),
            const Sticker(id: 'e6', emoji: '😢', label: 'Грустно'),
            const Sticker(id: 'e7', emoji: '😡', label: 'Злой'),
            const Sticker(id: 'e8', emoji: '🤗', label: 'Обнимаю'),
            const Sticker(id: 'e9', emoji: '😴', label: 'Сплю'),
            const Sticker(id: 'e10', emoji: '🤯', label: 'Шок'),
            const Sticker(id: 'e11', emoji: '🥳', label: 'Праздник'),
            const Sticker(id: 'e12', emoji: '😏', label: 'Хитрый'),
            const Sticker(id: 'e13', emoji: '🙄', label: 'Ну ладно'),
            const Sticker(id: 'e14', emoji: '😇', label: 'Ангел'),
            const Sticker(id: 'e15', emoji: '🤡', label: 'Клоун'),
            const Sticker(id: 'e16', emoji: '💀', label: 'Мертв'),
          ],
        ),
        StickerPack(
          id: 'gestures',
          name: 'Жесты',
          authorUid: 'system',
          authorName: 'Vizo',
          isDefault: true,
          createdAt: DateTime(2025),
          stickers: [
            const Sticker(id: 'g1', emoji: '👍', label: 'Класс'),
            const Sticker(id: 'g2', emoji: '👎', label: 'Плохо'),
            const Sticker(id: 'g3', emoji: '👏', label: 'Аплодисменты'),
            const Sticker(id: 'g4', emoji: '🤝', label: 'Рукопожатие'),
            const Sticker(id: 'g5', emoji: '✌️', label: 'Победа'),
            const Sticker(id: 'g6', emoji: '🤟', label: 'Рок'),
            const Sticker(id: 'g7', emoji: '💪', label: 'Сила'),
            const Sticker(id: 'g8', emoji: '🙏', label: 'Молитва'),
            const Sticker(id: 'g9', emoji: '👋', label: 'Привет'),
            const Sticker(id: 'g10', emoji: '🫡', label: 'Салют'),
            const Sticker(id: 'g11', emoji: '🤙', label: 'Звони'),
            const Sticker(id: 'g12', emoji: '✊', label: 'Кулак'),
          ],
        ),
        StickerPack(
          id: 'animals',
          name: 'Животные',
          authorUid: 'system',
          authorName: 'Vizo',
          isDefault: true,
          createdAt: DateTime(2025),
          stickers: [
            const Sticker(id: 'a1', emoji: '🐱', label: 'Кот'),
            const Sticker(id: 'a2', emoji: '🐶', label: 'Пёс'),
            const Sticker(id: 'a3', emoji: '🦊', label: 'Лиса'),
            const Sticker(id: 'a4', emoji: '🐻', label: 'Медведь'),
            const Sticker(id: 'a5', emoji: '🐼', label: 'Панда'),
            const Sticker(id: 'a6', emoji: '🦁', label: 'Лев'),
            const Sticker(id: 'a7', emoji: '🐸', label: 'Лягушка'),
            const Sticker(id: 'a8', emoji: '🦋', label: 'Бабочка'),
            const Sticker(id: 'a9', emoji: '🐙', label: 'Осьминог'),
            const Sticker(id: 'a10', emoji: '🦄', label: 'Единорог'),
            const Sticker(id: 'a11', emoji: '🐧', label: 'Пингвин'),
            const Sticker(id: 'a12', emoji: '🐬', label: 'Дельфин'),
          ],
        ),
        StickerPack(
          id: 'food',
          name: 'Еда',
          authorUid: 'system',
          authorName: 'Vizo',
          isDefault: true,
          createdAt: DateTime(2025),
          stickers: [
            const Sticker(id: 'f1', emoji: '🍕', label: 'Пицца'),
            const Sticker(id: 'f2', emoji: '🍔', label: 'Бургер'),
            const Sticker(id: 'f3', emoji: '🍩', label: 'Донат'),
            const Sticker(id: 'f4', emoji: '🍦', label: 'Мороженое'),
            const Sticker(id: 'f5', emoji: '☕', label: 'Кофе'),
            const Sticker(id: 'f6', emoji: '🍷', label: 'Вино'),
            const Sticker(id: 'f7', emoji: '🍰', label: 'Торт'),
            const Sticker(id: 'f8', emoji: '🌮', label: 'Тако'),
            const Sticker(id: 'f9', emoji: '🍣', label: 'Суши'),
            const Sticker(id: 'f10', emoji: '🧁', label: 'Кекс'),
            const Sticker(id: 'f11', emoji: '🍿', label: 'Попкорн'),
            const Sticker(id: 'f12', emoji: '🥤', label: 'Напиток'),
          ],
        ),
      ];
}
