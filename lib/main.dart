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

  // MVP는 익명 로그인. 나중에 구글·카카오 로그인으로 계정을 연결할 수 있다.
  final auth = FirebaseAuth.instance;
  final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;

  runApp(
    ProviderScope(
      overrides: [uidProvider.overrideWithValue(user.uid)],
      child: const CostApp(),
    ),
  );
}
