import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';

/// Forgot password: a code is emailed and another is texted to the mobile number on the account.
/// With both codes the person chooses a new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _ec = TextEditingController();
  final _sc = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false, _sent = false, _show = false;
  String? _error;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _ec, _sc, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  void _countdown(int seconds) {
    _timer?.cancel();
    setState(() => _wait = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = _wait > 0 ? _wait - 1 : 0);
      if (_wait == 0) t.cancel();
    });
  }

  Future<void> _request() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await session.requestPasswordReset(_email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err == null) _sent = true;
    });
    if (err == null) _countdown(60);
  }

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await session.confirmPasswordReset(_email.text, _ec.text, _sc.text, _pw.text, _pw2.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) {
      final m = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      m.hideCurrentSnackBar();
      m.showSnackBar(const SnackBar(content: Text('Password changed. Sign in with your new password.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Forgot password',
      subtitle: 'We send one code to your email and one to your mobile number, so nobody else can take over your account.',
      children: [
        RCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _email,
                enabled: !_sent,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() => _error = null),
                decoration: const InputDecoration(labelText: 'Email of your account', prefixIcon: Icon(Icons.alternate_email_rounded)),
              ),
              if (!_sent) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(onPressed: _busy ? null : _request, child: Text(_busy ? 'Sending…' : 'Send the codes')),
                ),
              ] else ...[
                const SizedBox(height: 10),
                Text(
                  'If that email belongs to an account, we sent a code to it and a text message to the mobile number on file. The codes expire in 10 minutes.',
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ec,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: const InputDecoration(labelText: 'Code from your email', prefixIcon: Icon(Icons.mail_outline_rounded), counterText: ''),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _sc,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: const InputDecoration(labelText: 'Code from the text message', prefixIcon: Icon(Icons.sms_outlined), counterText: ''),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pw,
                  obscureText: !_show,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    labelText: 'New password (at least 8 characters)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _show = !_show),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pw2,
                  obscureText: !_show,
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _confirm(),
                  decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_reset_rounded)),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: const TextStyle(color: danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              if (_sent) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(onPressed: _busy ? null : _confirm, child: Text(_busy ? 'Saving…' : 'Change password')),
                ),
                TextButton(
                  onPressed: (_busy || _wait > 0) ? null : _request,
                  child: Text(_wait > 0 ? 'Send new codes in $_wait s' : 'Send new codes'),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'No code arrived, or the mobile number changed? Contact the administration office. They can give you a temporary password.',
            style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
          ),
        ),
      ],
    );
  }
}
