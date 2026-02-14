import 'package:cloud_firestore/cloud_firestore.dart';

/// Contact model with tag system.
class ContactModel {
  final String id;
  final String ownerUid;
  final String name;
  final String phoneNumber;
  final String description;
  final String? avatarUrl;
  final List<String> tags;
  final bool isFavorite;
  final String? linkedUserId;
  final String? notes; // Private notes about contact
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContactModel({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.phoneNumber,
    this.description = '',
    this.avatarUrl,
    this.tags = const [],
    this.isFavorite = false,
    this.linkedUserId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContactModel.empty() => ContactModel(
        id: '',
        ownerUid: '',
        name: '',
        phoneNumber: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  bool get isEmpty => id.isEmpty;

  /// From Firestore document.
  factory ContactModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ContactModel(
      id: doc.id,
      ownerUid: data['ownerUid'] as String? ?? '',
      name: data['name'] as String? ?? '',
      phoneNumber: data['phoneNumber'] as String? ?? '',
      description: data['description'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String?,
      tags: List<String>.from(data['tags'] as List? ?? []),
      isFavorite: data['isFavorite'] as bool? ?? false,
      linkedUserId: data['linkedUserId'] as String?,
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// To Firestore map.
  Map<String, dynamic> toFirestore() {
    return {
      'ownerUid': ownerUid,
      'name': name,
      'phoneNumber': phoneNumber,
      'description': description,
      'avatarUrl': avatarUrl,
      'tags': tags,
      'isFavorite': isFavorite,
      if (linkedUserId != null) 'linkedUserId': linkedUserId,
      if (notes != null) 'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ContactModel copyWith({
    String? id,
    String? ownerUid,
    String? name,
    String? phoneNumber,
    String? description,
    String? avatarUrl,
    List<String>? tags,
    bool? isFavorite,
    String? linkedUserId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ContactModel(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      linkedUserId: linkedUserId ?? this.linkedUserId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
