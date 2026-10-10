import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

class AdminAccess extends StatefulWidget {
  const AdminAccess({super.key});

  @override
  State<AdminAccess> createState() => _AdminAccessState();
}

class _AdminAccessState extends State<AdminAccess> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = q.trim().toLowerCase();
        final list = app.trusted.where((t) => s.isEmpty || '${t.name} ${t.email} ${t.unit} ${t.role}'.toLowerCase().contains(s)).toList();
        return SubPage(
          title: 'Manage access',
          subtitle: 'Only the owner can create accounts. There is no public sign-up: every resident account is added by hand.',
          fab: FloatingActionButton.extended(
            backgroundColor: lav,
            foregroundColor: ink,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('New account'),
            onPressed: () => showFormSheet(
              context,
              title: 'Create a new account',
              fields: const [
                FieldSpec('name', 'Full name', hint: 'e.g. Ana Reyes'),
                FieldSpec('email', 'Email address', type: TextInputType.emailAddress, hint: 'e.g. ana.reyes@cityresidences.ph'),
                FieldSpec('phone', 'Phone number', type: TextInputType.phone, hint: 'e.g. 0917 555 0000'),
                FieldSpec('unit', 'Unit (confirms ownership/tenancy)', hint: 'e.g. Unit 12A'),
              ],
              submit: 'Create account',
              onSubmit: (v) {
                final err = app.addAccount(v['name'] as String, v['email'] as String, v['phone'] as String, 'Resident', (v['unit'] ?? '') as String);
                if (err == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) msg(context, 'Account created. Temporary password: resident123. Ask the resident to change it in Settings.');
                  });
                }
                return err;
              },
            ),
          ),
          children: [
            TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: const InputDecoration(hintText: 'Search name, email or unit…', prefixIcon: Icon(Icons.search_rounded)),
            ),
            RCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Avatar(initialsOf(app.adminName), size: 42, photo: app.adminPhoto),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.adminName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('owner (cannot be revoked)', style: TextStyle(color: muted(context), fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const Pill('Owner', tone: Tone.info),
                ],
              ),
            ),
            for (final t in list)
              Opacity(
                opacity: t.suspended ? 0.6 : 1,
                child: RCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Avatar(initialsOf(t.name), size: 42, bg: lavDeep),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(t.email, style: TextStyle(color: muted(context), fontSize: 12.5)),
                                Text('${t.phone}${t.unit != '—' ? ' · ${t.unit}' : ''} · Added ${t.added}', style: TextStyle(color: muted(context), fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Pill(t.role, tone: Tone.good),
                              const SizedBox(height: 4),
                              Pill(t.suspended ? 'Suspended' : 'Active'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await confirmDialog(context, 'Reset password?', 'This replaces ${t.name}\'s password with a temporary one. Share it with them privately.', confirm: 'Reset');
                            if (!ok || !context.mounted) return;
                            final tmp = app.resetPassword(t);
                            await showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                                title: const Text('Temporary password'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.email, style: TextStyle(color: muted(ctx), fontSize: 13)),
                                    const SizedBox(height: 10),
                                    SelectableText(tmp, style: hd(24)),
                                    const SizedBox(height: 10),
                                    Text('Ask them to change it in Settings after signing in.', style: TextStyle(color: muted(ctx), fontSize: 13)),
                                  ],
                                ),
                                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
                              ),
                            );
                          },
                          icon: const Icon(Icons.lock_reset_rounded),
                          label: const Text('Reset password'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: () => app.toggleSuspend(t), child: Text(t.suspended ? 'Reactivate' : 'Suspend'))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: danger),
                              onPressed: () async {
                                if (await confirmDialog(context, 'Revoke access?', 'Permanently revoke access for ${t.name}? This removes their account and cannot be undone.', confirm: 'Revoke', destructive: true)) {
                                  app.revoke(t);
                                }
                              },
                              child: const Text('Revoke'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (s.isNotEmpty && list.isEmpty) EmptyBox('No accounts match "$q".', icon: Icons.search_off_rounded),
            Text('Suspend keeps the account on file but blocks sign-in; Revoke permanently removes it and asks for confirmation first.',
                style: TextStyle(color: muted(context), fontSize: 12)),
          ],
        );
      },
    );
  }
}
