import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';

/// Shown to a new resident before anything else: confirm the email address and the mobile
/// number with two 6-digit codes (one by email, one by text message).
class VerifyContactScreen extends StatefulWidget {
  const VerifyContactScreen({super.key});

  @override
  State<VerifyContactScreen> createState() => _VerifyContactScreenState();
}

class _VerifyContactScreenState extends State<VerifyContactScreen> {
  final _email = TextEditingController();
  final _sms = TextEditingController();
  bool _busy = false, _sent = false;
  String? _error;
  String _sentEmail = '', _sentPhone = '';
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _sms.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _wait = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = _wait > 0 ? _wait - 1 : 0);
      if (_wait == 0) t.cancel();
    });
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await session.sendVerificationCodes();
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.alreadyDone) return;
    if (r.error != null) {
      setState(() => _error = r.error);
      return;
    }
    _email.clear();
    _sms.clear();
    setState(() {
      _sent = true;
      _sentEmail = r.email;
      _sentPhone = r.phone;
    });
    _startCountdown(r.cooldown);
  }

  Future<void> _check() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await session.checkVerificationCodes(_email.text, _sms.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: RCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Verify your account', style: hd(22)),
                  const SizedBox(height: 6),
                  Text(
                    _sent
                        ? 'We sent a code to $_sentEmail and a text message to $_sentPhone. Enter both codes. They expire in 10 minutes.'
                        : 'For your security, confirm your email address and mobile number. We will send one code by email and one by text message.',
                    style: TextStyle(color: muted(context), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (!_sent)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(onPressed: _busy ? null : _send, child: Text(_busy ? 'Sending…' : 'Send the codes')),
                    )
                  else ...[
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: const InputDecoration(labelText: 'Code from your email', prefixIcon: Icon(Icons.mail_outline_rounded), counterText: ''),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _sms,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _check(),
                      decoration: const InputDecoration(labelText: 'Code from the text message', prefixIcon: Icon(Icons.sms_outlined), counterText: ''),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_error!, style: const TextStyle(color: danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  if (_sent) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(onPressed: _busy ? null : _check, child: Text(_busy ? 'Checking…' : 'Verify')),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: (_busy || _wait > 0) ? null : _send,
                        child: Text(_wait > 0 ? 'Send new codes in $_wait s' : 'Send new codes'),
                      ),
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: session.signOut, child: const Text('Sign out')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
