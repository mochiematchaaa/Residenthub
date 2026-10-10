import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

/// Resident password reset: mobile number -> 6-digit code -> new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _pass = TextEditingController();
  final _conf = TextEditingController();
  bool _codeStep = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _pass.dispose();
    _conf.dispose();
    super.dispose();
  }

  String get _masked {
    final n = AppState.normalizePhone(_phone.text);
    if (n.length < 11) return _phone.text;
    return '${n.substring(0, 4)} *** ${n.substring(7)}';
  }

  void _sendCode() {
    FocusScope.of(context).unfocus();
    final err = app.startPasswordReset(_phone.text);
    setState(() {
      _error = err;
      if (err == null) {
        _codeStep = true;
        _code.clear();
      }
    });
    if (err == null) msg(context, 'If that number is registered, a 6-digit code was sent by SMS.');
  }

  void _reset() {
    FocusScope.of(context).unfocus();
    final err = app.finishPasswordReset(_code.text, _pass.text, _conf.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Password updated. Sign in with your new password.')));
  }

  @override
  Widget build(BuildContext context) {
    final test = AppState.showTestCode ? app.pendingTestCode : null;
    return SubPage(
      title: 'Forgot password',
      subtitle: _codeStep
          ? 'Enter the 6-digit code we sent to $_masked and choose a new password.'
          : 'Enter the mobile number registered to your resident account. We will text you a verification code.',
      children: [
        if (!_codeStep)
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _sendCode(),
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    hintText: 'e.g. 0917 555 0112',
                    prefixIcon: Icon(Icons.phone_android_rounded),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!, style: const TextStyle(color: danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: _sendCode, child: const Text('Send code'))),
              ],
            ),
          )
        else ...[
          if (test != null)
            PastelCard(
              color: Pastel.butter,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const GlassIcon(Icons.sms_outlined, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SMS gateway not connected yet', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        const Text('Your test code is:', style: TextStyle(color: inkSoft, fontSize: 12.5)),
                        SelectableText(test, style: hd(26)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: const InputDecoration(labelText: '6-digit code', counterText: '', prefixIcon: Icon(Icons.pin_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: !_show,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    labelText: 'New password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _show = !_show),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _conf,
                  obscureText: !_show,
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _reset(),
                  decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_reset_rounded)),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!, style: const TextStyle(color: danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: _reset, child: const Text('Reset password'))),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(onPressed: _sendCode, child: const Text('Resend code')),
                    TextButton(
                      onPressed: () => setState(() {
                        _codeStep = false;
                        _error = null;
                      }),
                      child: const Text('Use a different number'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
