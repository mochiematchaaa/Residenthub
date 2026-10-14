import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

/// Passwords are reset by the administrator, who gives the resident a new temporary password.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Forgot password',
      subtitle: 'The administration office resets passwords so that nobody else can take over your account.',
      children: [
        PastelCard(
          color: Pastel.lavender,
          padding: const EdgeInsets.all(18),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassIcon(Icons.support_agent_rounded, size: 42),
              SizedBox(height: 12),
              Text('What to do', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              SizedBox(height: 8),
              Text(
                '1. Contact the administration office and tell them the email of your account.\n'
                '2. The administrator gives you a temporary password.\n'
                '3. Sign in with it. The app then asks you to choose a new password.',
                style: TextStyle(color: inkSoft, fontSize: 13.5, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
