import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// ─── Service Providers ─────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

final storageServiceProvider =
    Provider<StorageService>((ref) => StorageService());

final webrtcServiceProvider = Provider<WebRTCService>((ref) {
  final firestoreService = ref.read(firestoreServiceProvider);
  return WebRTCService(firestoreService: firestoreService);
});

// ─── Auth State ────────────────────────────────────────

/// Sign-in flag — set to `true` after successful OTP verification.
/// Used by main.dart to decide between PhoneAuthScreen and AppShell.
final desktopSignedInProvider = StateProvider<bool>((ref) => false);

// ─── Current User Profile ──────────────────────────────

final currentUserProvider =
    StateNotifierProvider<CurrentUserNotifier, UserModel>((ref) {
  final firestoreService = ref.read(firestoreServiceProvider);
  final authService = ref.read(authServiceProvider);
  return CurrentUserNotifier(
    firestoreService: firestoreService,
    authService: authService,
  );
});

class CurrentUserNotifier extends StateNotifier<UserModel> {
  final FirestoreService firestoreService;
  final AuthService authService;

  CurrentUserNotifier({
    required this.firestoreService,
    required this.authService,
  }) : super(UserModel.empty()) {
    _init();
  }

  Future<void> _init() async {
    final uid = authService.uid;
    if (uid.isEmpty) return;
    final user = await firestoreService.getUser(uid);
    if (user != null) state = user;
  }

  Future<void> loadUser() async {
    final uid = authService.uid;
    if (uid.isEmpty) return;
    final user = await firestoreService.getUser(uid);
    if (user != null) state = user;
  }

  Future<void> updateProfile({
    String? displayName,
    String? status,
    String? avatarUrl,
    String? avatarBase64,
  }) async {
    final uid = authService.uid;
    if (uid.isEmpty) return;

    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (status != null) updates['status'] = status;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
    if (avatarBase64 != null) updates['avatarBase64'] = avatarBase64;

    await firestoreService.updateUser(uid, updates);

    state = state.copyWith(
      displayName: displayName ?? state.displayName,
      status: status ?? state.status,
      avatarUrl: avatarUrl ?? state.avatarUrl,
      avatarBase64: avatarBase64 ?? state.avatarBase64,
      updatedAt: DateTime.now(),
    );
  }

  void setUser(UserModel user) => state = user;

  void clear() => state = UserModel.empty();
}

// ─── Contacts ──────────────────────────────────────────

final contactsStreamProvider = StreamProvider<List<ContactModel>>((ref) {
  final authService = ref.read(authServiceProvider);
  final firestoreService = ref.read(firestoreServiceProvider);
  final uid = authService.uid;
  if (uid.isEmpty) return const Stream.empty();
  return firestoreService.contactsStream(uid);
});

final contactsProvider =
    StateNotifierProvider<ContactsNotifier, List<ContactModel>>((ref) {
  final firestoreService = ref.read(firestoreServiceProvider);
  final storageService = ref.read(storageServiceProvider);
  final authService = ref.read(authServiceProvider);
  return ContactsNotifier(
    firestoreService: firestoreService,
    storageService: storageService,
    uid: authService.uid,
  );
});

class ContactsNotifier extends StateNotifier<List<ContactModel>> {
  final FirestoreService firestoreService;
  final StorageService storageService;
  final String uid;

  ContactsNotifier({
    required this.firestoreService,
    required this.storageService,
    required this.uid,
  }) : super([]);

  Future<ContactModel> addContact(ContactModel contact) async {
    final newContact = await firestoreService.addContact(
      contact.copyWith(ownerUid: uid),
    );
    state = [...state, newContact];
    return newContact;
  }

  Future<void> updateContact(ContactModel contact) async {
    await firestoreService.updateContact(contact);
    state = [
      for (final c in state)
        if (c.id == contact.id)
          contact.copyWith(updatedAt: DateTime.now())
        else
          c,
    ];
  }

  Future<void> deleteContact(String contactId) async {
    await firestoreService.deleteContact(uid, contactId);
    state = state.where((c) => c.id != contactId).toList();
  }

  void setContacts(List<ContactModel> contacts) => state = contacts;
}

// ─── Call State ────────────────────────────────────────

final callStateProvider =
    StateNotifierProvider<CallStateNotifier, CallModel>((ref) {
  return CallStateNotifier();
});

class CallStateNotifier extends StateNotifier<CallModel> {
  CallStateNotifier() : super(CallModel.empty());

  void setCall(CallModel call) => state = call;

  void updateStatus(CallStatus status) =>
      state = state.copyWith(status: status);

  void clear() => state = CallModel.empty();
}

// ─── OTP Verification State ───────────────────────────

final otpStateProvider =
    StateNotifierProvider<OtpStateNotifier, OtpState>((ref) {
  return OtpStateNotifier();
});

class OtpState {
  final String verificationId;
  final String phoneNumber;
  final bool isLoading;
  final String? error;
  final int? resendToken;

  const OtpState({
    this.verificationId = '',
    this.phoneNumber = '',
    this.isLoading = false,
    this.error,
    this.resendToken,
  });

  OtpState copyWith({
    String? verificationId,
    String? phoneNumber,
    bool? isLoading,
    String? error,
    int? resendToken,
  }) =>
      OtpState(
        verificationId: verificationId ?? this.verificationId,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        resendToken: resendToken ?? this.resendToken,
      );
}

class OtpStateNotifier extends StateNotifier<OtpState> {
  OtpStateNotifier() : super(const OtpState());

  void setVerificationId(String id) =>
      state = state.copyWith(verificationId: id);

  void setPhoneNumber(String phone) =>
      state = state.copyWith(phoneNumber: phone);

  void setLoading(bool loading) =>
      state = state.copyWith(isLoading: loading);

  void setError(String? error) => state = state.copyWith(error: error);

  void setResendToken(int? token) =>
      state = state.copyWith(resendToken: token);

  void clear() => state = const OtpState();
}
