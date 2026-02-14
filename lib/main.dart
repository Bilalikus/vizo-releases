import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'providers/providers.dart';
import 'screens/screens.dart';
import 'services/incoming_call_listener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: VizoApp()));
}

class VizoApp extends ConsumerStatefulWidget {
  const VizoApp({super.key});

  @override
  ConsumerState<VizoApp> createState() => _VizoAppState();
}

class _VizoAppState extends ConsumerState<VizoApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _incomingCallListener = IncomingCallListener();
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _tryRestoreSession();
  }

  @override
  void dispose() {
    _incomingCallListener.dispose();
    super.dispose();
  }

  Future<void> _tryRestoreSession() async {
    final authService = ref.read(authServiceProvider);
    final restored = await authService.tryRestoreSession();
    if (restored) {
      // Load user profile into provider
      final user = await authService.getCurrentUserModel();
      if (user != null) {
        ref.read(currentUserProvider.notifier).setUser(user);
      }
      ref.read(desktopSignedInProvider.notifier).state = true;
    }
    if (mounted) setState(() => _initializing = false);
  }

  void _startListeningForCalls(String uid) {
    _incomingCallListener.startListening(
      uid: uid,
      navigatorKey: _navigatorKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(desktopSignedInProvider);

    return MaterialApp(
      title: 'Vizo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      navigatorKey: _navigatorKey,
      home: _initializing
          ? const _SplashScreen()
          : isSignedIn
              ? _buildApp()
              : const PhoneAuthScreen(),
    );
  }

  Widget _buildApp() {
    final uid = ref.read(authServiceProvider).effectiveUid;
    if (uid.isNotEmpty) {
      _startListeningForCalls(uid);
    }
    return const AppShell();
  }
}

/// Simple splash screen shown while restoring session.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset('assets/Icon.png', width: 80, height: 80),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
