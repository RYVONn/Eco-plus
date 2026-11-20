import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'session.dart';

/// Registers this phone for push messages once a real user is signed in.
/// Everything is guarded: without Firebase config files (google-services.json / GoogleService-Info.plist),
/// on web or desktop, or when the user says no, the app simply runs without push.
final pushProvider = Provider<void>((ref) {
  final user = ref.watch(sessionProvider).value;
  if (user == null || user.isDemo || kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
  _register(ref);
});

Future<void> _register(Ref ref) async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    Future<void> send(String token) async {
      try {
        await ref.read(dioProvider).post('/me/device-tokens', data: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'});
      } catch (_) {}
    }

    final token = await messaging.getToken();
    if (token != null) await send(token);
    messaging.onTokenRefresh.listen(send);
  } catch (e) {
    debugPrint('Push is off: $e');
  }
}
