import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/session.dart';

/// "01012345678" or "+201012345678" -> "+201012345678". Returns null when it is not an Egyptian mobile number.
String? normalizeEgyptPhone(String input) {
  final digits = input.replaceAll(RegExp(r'[\s\-]'), '');
  if (RegExp(r'^01[0-9]{9}$').hasMatch(digits)) return '+20${digits.substring(1)}';
  if (RegExp(r'^\+201[0-9]{9}$').hasMatch(digits)) return digits;
  return null;
}

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});
  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  String? get _normalized => normalizeEgyptPhone(_phone.text);

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _wait = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _wait <= 1) {
        t.cancel();
        if (mounted) setState(() => _wait = 0);
      } else {
        setState(() => _wait--);
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      final err = ApiError.from(e);
      if (mounted) setState(() => _error = err.isNetwork ? s.noConnection : err.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final phone = _normalized;
    if (phone == null) return;
    await _run(() async {
      await ref.read(sessionProvider.notifier).requestOtp(phone);
      if (mounted) setState(() => _sent = true);
      _startCountdown(30);
    });
  }

  Future<void> _verify() async {
    final phone = _normalized;
    if (phone == null || _code.text.length != 6) return;
    await _run(() => ref.read(sessionProvider.notifier).loginWithOtp(phone, _code.text, name: _name.text.trim()).then((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final c = context.eco;
    final t = Theme.of(context).textTheme;
    final ar = s.ar;
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.go('/login'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_sent ? (ar ? 'اكتب الكود' : 'Enter the code') : (ar ? 'رقم موبايلك' : 'Your phone number'), style: t.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  _sent ? (ar ? 'بعتناه على ${_normalized ?? ''}' : 'Sent to ${_normalized ?? ''}') : (ar ? 'هنبعتلك كود تأكيد من 6 أرقام.' : 'We will text you a 6-digit code.'),
                  style: t.bodyMedium?.copyWith(color: c.inkSoft),
                ),
                const SizedBox(height: 20),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(children: [
                    Container(width: 84, height: 56, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(14)), child: const Text('+20')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phone,
                        enabled: !_sent,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(hintText: '01X XXXX XXXX', counterText: ''),
                      ),
                    ),
                  ]),
                ),
                if (_sent) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: t.headlineSmall?.copyWith(letterSpacing: 8),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _verify(),
                    decoration: const InputDecoration(hintText: '------', counterText: ''),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _name, decoration: InputDecoration(labelText: ar ? 'اسمك (لو حسابك جديد)' : 'Your name (for a new account)')),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Icon(Icons.error_outline_rounded, size: 18, color: c.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: t.bodyMedium?.copyWith(color: c.danger))),
                  ]),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy || (_sent ? _code.text.length != 6 : _normalized == null) ? null : (_sent ? _verify : _send),
                  child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : Text(_sent ? (ar ? 'تأكيد' : 'Verify') : (ar ? 'ابعت الكود' : 'Send code')),
                ),
                if (_sent)
                  Center(
                    child: TextButton(
                      onPressed: _busy || _wait > 0 ? null : _send,
                      child: Text(_wait > 0 ? (ar ? 'ابعت تاني بعد $_wait ث' : 'Resend in ${_wait}s') : (ar ? 'ابعت الكود تاني' : 'Resend code')),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
