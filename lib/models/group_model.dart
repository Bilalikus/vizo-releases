import 'package:cloud_firestore/cloud_firestore.dart';

/// Group chat model.
class GroupModel {
  final String id;
  final String name;
  final String description;
  final String? avatarBase64;
  final String creatorUid;
  final List<String> members;
  final List<String> admins;
  final bool isPublic; // community = true
  final String type; // 'group', 'community', 'channel'
  final String region; // 'EU', 'USA', 'RU', 'ASIA', 'OTHER', ''
  final String category; // topic for communities
  final bool isBanned;
  final String banReason;
  final bool isFrozen;
  final List<String> writers; // for channels: who can write
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final List<String> mutedBy;
  final List<String> bannedUsers;

  const GroupModel({
    required this.id,
    required this.name,
    this.description = '',
    this.avatarBase64,
    required this.creatorUid,
    this.members = const [],
    this.admins = const [],
    this.isPublic = false,
    this.type = 'group',
    this.region = '',
    this.category = '',
    this.isBanned = false,
    this.banReason = '',
    this.isFrozen = false,
    this.writers = const [],
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageAt,
    this.mutedBy = const [],
    this.bannedUsers = const [],
  });

  bool get isCommunity => isPublic || type == 'community';
  bool get isChannel => type == 'channel';

  factory GroupModel.empty() => GroupModel(
        id: '',
        name: '',
        creatorUid: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        type: 'group',
      );

  bool get isEmpty => id.isEmpty;

  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GroupModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      avatarBase64: data['avatarBase64'] as String?,
      creatorUid: data['creatorUid'] as String? ?? '',
      members: List<String>.from(data['members'] as List? ?? []),
      admins: List<String>.from(data['admins'] as List? ?? []),
      isPublic: data['isPublic'] as bool? ?? false,
      type: data['type'] as String? ?? (data['isPublic'] == true ? 'community' : 'group'),
      region: data['region'] as String? ?? '',
      category: data['category'] as String? ?? '',
      isBanned: data['isBanned'] as bool? ?? false,
      banReason: data['banReason'] as String? ?? '',
      isFrozen: data['isFrozen'] as bool? ?? false,
      writers: List<String>.from(data['writers'] as List? ?? []),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      mutedBy: List<String>.from(data['mutedBy'] as List? ?? []),
      bannedUsers: List<String>.from(data['bannedUsers'] as List? ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'avatarBase64': avatarBase64,
      'creatorUid': creatorUid,
      'members': members,
      'admins': admins,
      'isPublic': isPublic,
      'type': type,
      'region': region,
      'category': category,
      'isBanned': isBanned,
      'banReason': banReason,
      'isFrozen': isFrozen,
      'writers': writers,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageAt != null)
        'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
      'mutedBy': mutedBy,
      'bannedUsers': bannedUsers,
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? avatarBase64,
    String? creatorUid,
    List<String>? members,
    List<String>? admins,
    bool? isPublic,
    String? type,
    String? region,
    String? category,
    bool? isBanned,
    String? banReason,
    bool? isFrozen,
    List<String>? writers,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
    DateTime? lastMessageAt,
    List<String>? mutedBy,
    List<String>? bannedUsers,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      creatorUid: creatorUid ?? this.creatorUid,
      members: members ?? this.members,
      admins: admins ?? this.admins,
      isPublic: isPublic ?? this.isPublic,
      type: type ?? this.type,
      region: region ?? this.region,
      category: category ?? this.category,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      isFrozen: isFrozen ?? this.isFrozen,
      writers: writers ?? this.writers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      mutedBy: mutedBy ?? this.mutedBy,
      bannedUsers: bannedUsers ?? this.bannedUsers,
    );
  }
}
