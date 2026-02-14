import 'package:cloud_firestore/cloud_firestore.dart';

/// Vizo user model.
class UserModel {
  final String uid;
  final String phoneNumber;
  final String displayName;
  final String status;
  final String? avatarUrl;
  final String? avatarBase64;
  final String? encryptionKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOnline;

  const UserModel({
    required this.uid,
    required this.phoneNumber,
    this.displayName = '',
    this.status = '',
    this.avatarUrl,
    this.avatarBase64,
    this.encryptionKey,
    required this.createdAt,
    required this.updatedAt,
    this.isOnline = false,
  });

  /// The best available avatar — prefers base64, falls back to URL.
  String? get effectiveAvatar => avatarBase64 ?? avatarUrl;

  /// Empty / default user.
  factory UserModel.empty() => UserModel(
        uid: '',
        phoneNumber: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  bool get isEmpty => uid.isEmpty;
  bool get isNotEmpty => uid.isNotEmpty;

  /// From Firestore document.
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      phoneNumber: data['phoneNumber'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      status: data['status'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String?,
      avatarBase64: data['avatarBase64'] as String?,
      encryptionKey: data['encryptionKey'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOnline: data['isOnline'] as bool? ?? false,
    );
  }

  /// To Firestore map.
  Map<String, dynamic> toFirestore() {
    return {
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'status': status,
      'avatarUrl': avatarUrl,
      'avatarBase64': avatarBase64,
      'encryptionKey': encryptionKey,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isOnline': isOnline,
    };
  }

  UserModel copyWith({
    String? uid,
    String? phoneNumber,
    String? displayName,
    String? status,
    String? avatarUrl,
    String? avatarBase64,
    String? encryptionKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOnline,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      encryptionKey: encryptionKey ?? this.encryptionKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
