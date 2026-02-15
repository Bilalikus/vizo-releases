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
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageAt,
    this.mutedBy = const [],
    this.bannedUsers = const [],
  });

  bool get isCommunity => isPublic;

  factory GroupModel.empty() => GroupModel(
        id: '',
        name: '',
        creatorUid: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      mutedBy: mutedBy ?? this.mutedBy,
      bannedUsers: bannedUsers ?? this.bannedUsers,
    );
  }
}
