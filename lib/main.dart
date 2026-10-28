import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _start();
}

/// 로그인하고 앱을 띄운다.
/// 첫 실행에 인터넷이 없으면 익명 로그인이 실패하므로 다시 시도 화면을 띄운다.
Future<void> _start() async {
  // MVP는 익명 로그인. 나중에 구글·카카오 로그인으로 계정을 연결할 수 있다.
  final auth = FirebaseAuth.instance;
  final User user;
  try {
    user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
  } catch (_) {
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('처음 실행할 때는 인터넷 연결이 필요합니다.'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _start, child: const Text('다시 시도')),
            ],
          ),
        ),
      ),
    ));
    return;
  }

  runApp(
    ProviderScope(
      overrides: [uidProvider.overrideWithValue(user.uid)],
      child: const CostApp(),
    ),
  );
}
