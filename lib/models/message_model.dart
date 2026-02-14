import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat message model with edit/delete/reply/forward/media/pin/schedule support.
class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final bool isRead;
  final bool isEdited;
  final bool isDeleted;
  final bool isStarred;
  final bool isPinned;
  final String? reaction;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;
  final String? forwardedFrom;

  // Media fields
  final String? mediaUrl;
  final String? mediaType; // 'image', 'file', 'voice', 'contact', 'location'
  final String? mediaName;
  final int? mediaSize;

  // Auto-destroy / scheduled
  final DateTime? autoDestroyAt;
  final DateTime? scheduledAt;

  // Link preview
  final String? linkUrl;
  final String? linkTitle;
  final String? linkDescription;
  final String? linkImage;

  // Contact sharing
  final String? sharedContactName;
  final String? sharedContactPhone;

  // Location sharing
  final double? locationLat;
  final double? locationLng;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName = '',
    required this.text,
    required this.createdAt,
    this.isRead = false,
    this.isEdited = false,
    this.isDeleted = false,
    this.isStarred = false,
    this.isPinned = false,
    this.reaction,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.forwardedFrom,
    this.mediaUrl,
    this.mediaType,
    this.mediaName,
    this.mediaSize,
    this.autoDestroyAt,
    this.scheduledAt,
    this.linkUrl,
    this.linkTitle,
    this.linkDescription,
    this.linkImage,
    this.sharedContactName,
    this.sharedContactPhone,
    this.locationLat,
    this.locationLng,
  });

  factory MessageModel.empty() => MessageModel(
        id: '',
        chatId: '',
        senderId: '',
        text: '',
        createdAt: DateTime.now(),
      );

  bool get isEmpty => id.isEmpty;

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get hasLink => linkUrl != null && linkUrl!.isNotEmpty;
  bool get hasSharedContact =>
      sharedContactName != null && sharedContactName!.isNotEmpty;
  bool get hasLocation => locationLat != null && locationLng != null;

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? createdAt,
    bool? isRead,
    bool? isEdited,
    bool? isDeleted,
    bool? isStarred,
    bool? isPinned,
    String? reaction,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
    String? forwardedFrom,
    String? mediaUrl,
    String? mediaType,
    String? mediaName,
    int? mediaSize,
    DateTime? autoDestroyAt,
    DateTime? scheduledAt,
    String? linkUrl,
    String? linkTitle,
    String? linkDescription,
    String? linkImage,
    String? sharedContactName,
    String? sharedContactPhone,
    double? locationLat,
    double? locationLng,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      isStarred: isStarred ?? this.isStarred,
      isPinned: isPinned ?? this.isPinned,
      reaction: reaction ?? this.reaction,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      replyToSender: replyToSender ?? this.replyToSender,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      mediaName: mediaName ?? this.mediaName,
      mediaSize: mediaSize ?? this.mediaSize,
      autoDestroyAt: autoDestroyAt ?? this.autoDestroyAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      linkUrl: linkUrl ?? this.linkUrl,
      linkTitle: linkTitle ?? this.linkTitle,
      linkDescription: linkDescription ?? this.linkDescription,
      linkImage: linkImage ?? this.linkImage,
      sharedContactName: sharedContactName ?? this.sharedContactName,
      sharedContactPhone: sharedContactPhone ?? this.sharedContactPhone,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
    );
  }

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MessageModel(
      id: doc.id,
      chatId: data['chatId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      isEdited: data['isEdited'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
      isStarred: data['isStarred'] as bool? ?? false,
      isPinned: data['isPinned'] as bool? ?? false,
      reaction: data['reaction'] as String?,
      replyToId: data['replyToId'] as String?,
      replyToText: data['replyToText'] as String?,
      replyToSender: data['replyToSender'] as String?,
      forwardedFrom: data['forwardedFrom'] as String?,
      mediaUrl: data['mediaUrl'] as String?,
      mediaType: data['mediaType'] as String?,
      mediaName: data['mediaName'] as String?,
      mediaSize: data['mediaSize'] as int?,
      autoDestroyAt:
          (data['autoDestroyAt'] as Timestamp?)?.toDate(),
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate(),
      linkUrl: data['linkUrl'] as String?,
      linkTitle: data['linkTitle'] as String?,
      linkDescription: data['linkDescription'] as String?,
      linkImage: data['linkImage'] as String?,
      sharedContactName: data['sharedContactName'] as String?,
      sharedContactPhone: data['sharedContactPhone'] as String?,
      locationLat: (data['locationLat'] as num?)?.toDouble(),
      locationLng: (data['locationLng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'isStarred': isStarred,
      'isPinned': isPinned,
      if (reaction != null) 'reaction': reaction,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSender != null) 'replyToSender': replyToSender,
      if (forwardedFrom != null) 'forwardedFrom': forwardedFrom,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaType != null) 'mediaType': mediaType,
      if (mediaName != null) 'mediaName': mediaName,
      if (mediaSize != null) 'mediaSize': mediaSize,
      if (autoDestroyAt != null)
        'autoDestroyAt': Timestamp.fromDate(autoDestroyAt!),
      if (scheduledAt != null)
        'scheduledAt': Timestamp.fromDate(scheduledAt!),
      if (linkUrl != null) 'linkUrl': linkUrl,
      if (linkTitle != null) 'linkTitle': linkTitle,
      if (linkDescription != null) 'linkDescription': linkDescription,
      if (linkImage != null) 'linkImage': linkImage,
      if (sharedContactName != null) 'sharedContactName': sharedContactName,
      if (sharedContactPhone != null)
        'sharedContactPhone': sharedContactPhone,
      if (locationLat != null) 'locationLat': locationLat,
      if (locationLng != null) 'locationLng': locationLng,
    };
  }
}
