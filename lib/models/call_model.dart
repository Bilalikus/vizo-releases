/// Call status enum.
enum CallStatus {
  idle,
  ringing,
  connecting,
  active,
  ended,
  missed,
  declined,
}

/// Call model for WebRTC sessions.
class CallModel {
  final String id;
  final String callerId;
  final String callerName;
  final String callerAvatar;
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;
  final CallStatus status;
  final bool isEncrypted;
  final bool isVideoCall;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? offer;
  final String? answer;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerAvatar = '',
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar = '',
    this.status = CallStatus.idle,
    this.isEncrypted = true,
    this.isVideoCall = false,
    required this.startedAt,
    this.endedAt,
    this.offer,
    this.answer,
  });

  factory CallModel.empty() => CallModel(
        id: '',
        callerId: '',
        callerName: '',
        receiverId: '',
        receiverName: '',
        startedAt: DateTime.now(),
      );

  bool get isEmpty => id.isEmpty;

  Duration? get duration {
    if (endedAt == null) return null;
    return endedAt!.difference(startedAt);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverAvatar': receiverAvatar,
      'status': status.name,
      'isEncrypted': isEncrypted,
      'isVideoCall': isVideoCall,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'endedAt': endedAt?.millisecondsSinceEpoch,
      'offer': offer,
      'answer': answer,
    };
  }

  factory CallModel.fromMap(String id, Map<String, dynamic> data) {
    return CallModel(
      id: id,
      callerId: data['callerId'] as String? ?? '',
      callerName: data['callerName'] as String? ?? '',
      callerAvatar: data['callerAvatar'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      receiverName: data['receiverName'] as String? ?? '',
      receiverAvatar: data['receiverAvatar'] as String? ?? '',
      status: CallStatus.values.firstWhere(
        (e) => e.name == (data['status'] as String? ?? 'idle'),
        orElse: () => CallStatus.idle,
      ),
      isEncrypted: data['isEncrypted'] as bool? ?? true,
      isVideoCall: data['isVideoCall'] as bool? ?? false,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
          data['startedAt'] as int? ?? 0),
      endedAt: data['endedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['endedAt'] as int)
          : null,
      offer: data['offer'] as String?,
      answer: data['answer'] as String?,
    );
  }

  CallModel copyWith({
    String? id,
    String? callerId,
    String? callerName,
    String? callerAvatar,
    String? receiverId,
    String? receiverName,
    String? receiverAvatar,
    CallStatus? status,
    bool? isEncrypted,
    bool? isVideoCall,
    DateTime? startedAt,
    DateTime? endedAt,
    String? offer,
    String? answer,
  }) {
    return CallModel(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverAvatar: receiverAvatar ?? this.receiverAvatar,
      status: status ?? this.status,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      isVideoCall: isVideoCall ?? this.isVideoCall,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      offer: offer ?? this.offer,
      answer: answer ?? this.answer,
    );
  }
}
