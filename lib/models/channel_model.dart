import 'package:cloud_firestore/cloud_firestore.dart';

/// Channel model — only creator and designated writers can post.
class ChannelModel {
  final String id;
  final String name;
  final String description;
  final String? avatarBase64;
  final String creatorUid;
  final List<String> subscribers; // everyone who reads
  final List<String> writers; // creator + designated users who can post
  final bool isBanned;
  final String banReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final List<String> mutedBy;

  const ChannelModel({
    required this.id,
    required this.name,
    this.description = '',
    this.avatarBase64,
    required this.creatorUid,
    this.subscribers = const [],
    this.writers = const [],
    this.isBanned = false,
    this.banReason = '',
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageAt,
    this.mutedBy = const [],
  });

  bool canWrite(String uid) => uid == creatorUid || writers.contains(uid);

  factory ChannelModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChannelModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      avatarBase64: data['avatarBase64'] as String?,
      creatorUid: data['creatorUid'] as String? ?? '',
      subscribers: List<String>.from(data['subscribers'] as List? ?? []),
      writers: List<String>.from(data['writers'] as List? ?? []),
      isBanned: data['isBanned'] as bool? ?? false,
      banReason: data['banReason'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      mutedBy: List<String>.from(data['mutedBy'] as List? ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'avatarBase64': avatarBase64,
      'creatorUid': creatorUid,
      'subscribers': subscribers,
      'writers': writers,
      'isBanned': isBanned,
      'banReason': banReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      if (lastMessage != null) 'lastMessage': lastMessage,
      if (lastMessageAt != null) 'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
      'mutedBy': mutedBy,
    };
  }

  ChannelModel copyWith({
    String? id,
    String? name,
    String? description,
    String? avatarBase64,
    String? creatorUid,
    List<String>? subscribers,
    List<String>? writers,
    bool? isBanned,
    String? banReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
    DateTime? lastMessageAt,
    List<String>? mutedBy,
  }) {
    return ChannelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      creatorUid: creatorUid ?? this.creatorUid,
      subscribers: subscribers ?? this.subscribers,
      writers: writers ?? this.writers,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      mutedBy: mutedBy ?? this.mutedBy,
    );
  }
}
