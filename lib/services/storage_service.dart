import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Avatar service — stores images as base64 in Firestore.
/// No Firebase Storage needed.
class StorageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Upload an avatar image — stores base64 in user doc.
  Future<String> uploadAvatar({
    required String uid,
    required File file,
  }) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final mime = _mimeType(ext);
    final b64 = base64Encode(bytes);
    final dataUri = 'data:$mime;base64,$b64';

    await _db.collection('users').doc(uid).update({
      'avatarBase64': dataUri,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return dataUri;
  }

  /// Upload a contact avatar — stores base64 in contact doc.
  Future<String> uploadContactAvatar({
    required String uid,
    required String contactId,
    required File file,
  }) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final mime = _mimeType(ext);
    final b64 = base64Encode(bytes);
    final dataUri = 'data:$mime;base64,$b64';

    await _db
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .doc(contactId)
        .update({
      'avatarBase64': dataUri,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return dataUri;
  }

  /// Delete an avatar — no-op for base64 (overwritten on next upload).
  Future<void> deleteAvatar(String url) async {
    debugPrint('deleteAvatar: no-op for base64');
  }

  String _mimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
