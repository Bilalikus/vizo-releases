import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'firestore_service.dart';

/// WebRTC service for voice/video calling with screen sharing
/// and Firestore signaling.
class WebRTCService {
  final FirestoreService _firestoreService;
  final _uuid = const Uuid();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  MediaStream? _screenStream;

  StreamSubscription? _callSubscription;
  StreamSubscription? _candidatesSubscription;
  Timer? _ringTimeout;

  String? _currentCallId;
  bool _isCaller = false;
  bool _isEnding = false;
  bool _isVideoCall = false;
  bool _isVideoEnabled = false;
  bool _isScreenSharing = false;

  // Callbacks
  void Function(MediaStream stream)? onLocalStream;
  void Function(MediaStream stream)? onRemoteStream;
  void Function(CallStatus status)? onCallStatusChanged;
  void Function()? onCallEnded;
  void Function(bool isScreenSharing)? onScreenShareChanged;
  void Function(bool isVideoEnabled)? onVideoStateChanged;

  WebRTCService({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  String? get currentCallId => _currentCallId;
  bool get isVideoCall => _isVideoCall;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isScreenSharing => _isScreenSharing;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  // ─── ICE Servers Configuration ──────────────────────

  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
  };

  // ─── Initialize Media ──────────────────────────────

  Future<MediaStream> _getUserMedia({bool video = false}) async {
    final constraints = <String, dynamic>{
      'audio': true,
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    };
    final stream = await navigator.mediaDevices.getUserMedia(constraints);
    _localStream = stream;
    _isVideoEnabled = video;
    onLocalStream?.call(stream);
    return stream;
  }

  // ─── Create Peer Connection ─────────────────────────

  Future<RTCPeerConnection> _createPeerConnection() async {
    final pc = await createPeerConnection(_iceServers);

    // Add local tracks
    final stream = await _getUserMedia(video: _isVideoCall);
    for (final track in stream.getTracks()) {
      await pc.addTrack(track, stream);
    }

    // Listen for remote tracks
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStream?.call(event.streams[0]);
      }
    };

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          onCallStatusChanged?.call(CallStatus.active);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          onCallStatusChanged?.call(CallStatus.ended);
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          break;
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          break;
        default:
          break;
      }
    };

    _peerConnection = pc;
    return pc;
  }

  // ─── Make a Call (Caller) ──────────────────────────

  Future<String> makeCall({
    required String callerId,
    required String callerName,
    String callerAvatar = '',
    required String receiverId,
    required String receiverName,
    String receiverAvatar = '',
    bool isVideoCall = false,
  }) async {
    _isCaller = true;
    _isEnding = false;
    _isVideoCall = isVideoCall;
    _currentCallId = _uuid.v4();

    final pc = await _createPeerConnection();

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _firestoreService.addIceCandidate(
        callId: _currentCallId!,
        collection: 'callerCandidates',
        candidate: candidate.toMap(),
      );
    };

    final offer = await pc.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': isVideoCall,
    });
    await pc.setLocalDescription(offer);

    final call = CallModel(
      id: _currentCallId!,
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverAvatar: receiverAvatar,
      status: CallStatus.ringing,
      isEncrypted: true,
      isVideoCall: isVideoCall,
      startedAt: DateTime.now(),
      offer: offer.sdp,
    );
    await _firestoreService.createCall(call);

    onCallStatusChanged?.call(CallStatus.ringing);

    _ringTimeout?.cancel();
    _ringTimeout = Timer(const Duration(seconds: 45), () async {
      if (_currentCallId != null) {
        try {
          await _firestoreService.updateCall(_currentCallId!, {
            'status': CallStatus.missed.name,
          });
        } catch (_) {}
        await endCall();
      }
    });

    _callSubscription = _firestoreService
        .callStream(_currentCallId!)
        .listen((callModel) async {
      if (callModel == null) {
        await endCall();
        return;
      }

      if (callModel.answer != null &&
          pc.signalingState !=
              RTCSignalingState.RTCSignalingStateStable) {
        _ringTimeout?.cancel();
        final answer = RTCSessionDescription(callModel.answer!, 'answer');
        await pc.setRemoteDescription(answer);
        onCallStatusChanged?.call(CallStatus.connecting);
      }

      if (callModel.status == CallStatus.ended ||
          callModel.status == CallStatus.declined) {
        await endCall();
      }
    });

    _candidatesSubscription = _firestoreService
        .iceCandidatesStream(
          callId: _currentCallId!,
          collection: 'receiverCandidates',
        )
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          pc.addCandidate(RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ));
        }
      }
    });

    return _currentCallId!;
  }

  // ─── Answer a Call (Receiver) ──────────────────────

  Future<void> answerCall(CallModel call) async {
    _isCaller = false;
    _isEnding = false;
    _isVideoCall = call.isVideoCall;
    _currentCallId = call.id;

    final pc = await _createPeerConnection();

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _firestoreService.addIceCandidate(
        callId: _currentCallId!,
        collection: 'receiverCandidates',
        candidate: candidate.toMap(),
      );
    };

    final offer = RTCSessionDescription(call.offer!, 'offer');
    await pc.setRemoteDescription(offer);

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    await _firestoreService.updateCall(_currentCallId!, {
      'answer': answer.sdp,
      'status': CallStatus.connecting.name,
    });

    onCallStatusChanged?.call(CallStatus.connecting);

    _candidatesSubscription = _firestoreService
        .iceCandidatesStream(
          callId: _currentCallId!,
          collection: 'callerCandidates',
        )
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          pc.addCandidate(RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ));
        }
      }
    });

    _callSubscription = _firestoreService
        .callStream(_currentCallId!)
        .listen((callModel) async {
      if (callModel == null ||
          callModel.status == CallStatus.ended ||
          callModel.status == CallStatus.declined) {
        await endCall();
      }
    });
  }

  // ─── Decline a Call ────────────────────────────────

  Future<void> declineCall(String callId) async {
    await _firestoreService.updateCall(callId, {
      'status': CallStatus.declined.name,
    });
  }

  // ─── End Call ──────────────────────────────────────

  Future<void> endCall() async {
    if (_isEnding) return;
    _isEnding = true;

    _ringTimeout?.cancel();
    _ringTimeout = null;

    await _callSubscription?.cancel();
    _callSubscription = null;
    await _candidatesSubscription?.cancel();
    _candidatesSubscription = null;

    if (_isScreenSharing) {
      await _stopScreenShare();
    }

    try {
      await _peerConnection?.close();
    } catch (_) {}
    _peerConnection = null;

    try {
      _localStream?.getTracks().forEach((track) => track.stop());
      _localStream?.dispose();
    } catch (_) {}
    _localStream = null;
    _remoteStream = null;

    if (_currentCallId != null) {
      try {
        await _firestoreService.updateCall(_currentCallId!, {
          'status': CallStatus.ended.name,
          'endedAt': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (_) {}
    }

    _isVideoEnabled = false;
    _isScreenSharing = false;
    onCallStatusChanged?.call(CallStatus.ended);
    onCallEnded?.call();
    _currentCallId = null;
    _isEnding = false;
  }

  // ─── Toggle Mute ──────────────────────────────────

  bool toggleMute() {
    if (_localStream == null) return false;
    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isEmpty) return false;
    final enabled = !audioTracks[0].enabled;
    audioTracks[0].enabled = enabled;
    return !enabled;
  }

  // ─── Toggle Speaker ───────────────────────────────

  Future<void> toggleSpeaker(bool speakerOn) async {
    if (_localStream == null) return;
    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isEmpty) return;
    await Helper.setSpeakerphoneOn(speakerOn);
  }

  // ─── Toggle Video ─────────────────────────────────

  bool toggleVideo() {
    if (_localStream == null) return false;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return false;
    final enabled = !videoTracks[0].enabled;
    videoTracks[0].enabled = enabled;
    _isVideoEnabled = enabled;
    onVideoStateChanged?.call(enabled);
    return enabled;
  }

  // ─── Switch Camera ────────────────────────────────

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;
    await Helper.switchCamera(videoTracks[0]);
  }

  // ─── Start Screen Sharing ─────────────────────────

  Future<bool> startScreenShare() async {
    if (_peerConnection == null || _isScreenSharing) return false;

    try {
      MediaStream screenStream;

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        screenStream = await navigator.mediaDevices.getDisplayMedia({
          'video': true,
          'audio': false,
        });
      } else {
        screenStream = await navigator.mediaDevices.getDisplayMedia({
          'video': {'deviceId': 'broadcast'},
          'audio': false,
        });
      }

      _screenStream = screenStream;

      final senders = await _peerConnection!.getSenders();
      RTCRtpSender? videoSender;
      for (final s in senders) {
        if (s.track?.kind == 'video') {
          videoSender = s;
          break;
        }
      }

      if (videoSender == null && senders.isNotEmpty) {
        videoSender = senders.first;
      }

      final screenTrack = screenStream.getVideoTracks().first;

      screenTrack.onEnded = () {
        stopScreenShare();
      };

      if (videoSender != null) {
        await videoSender.replaceTrack(screenTrack);
      }

      _isScreenSharing = true;
      onScreenShareChanged?.call(true);
      return true;
    } catch (e) {
      debugPrint('Screen share error: $e');
      return false;
    }
  }

  // ─── Stop Screen Sharing ──────────────────────────

  Future<void> stopScreenShare() async {
    await _stopScreenShare();
    onScreenShareChanged?.call(false);
  }

  Future<void> _stopScreenShare() async {
    if (!_isScreenSharing || _peerConnection == null) return;

    try {
      if (_localStream != null) {
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          final senders = await _peerConnection!.getSenders();
          for (final s in senders) {
            if (s.track?.kind == 'video') {
              await s.replaceTrack(videoTracks.first);
              break;
            }
          }
        }
      }

      _screenStream?.getTracks().forEach((t) => t.stop());
      _screenStream?.dispose();
      _screenStream = null;
    } catch (e) {
      debugPrint('Stop screen share error: $e');
    }

    _isScreenSharing = false;
  }

  // ─── Dispose ──────────────────────────────────────

  Future<void> dispose() async {
    await endCall();
  }
}
