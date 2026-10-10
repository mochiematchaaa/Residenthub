import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/profile_widgets.dart';

class ResSettings extends StatefulWidget {
  const ResSettings({super.key});

  @override
  State<ResSettings> createState() => _ResSettingsState();
}

class _ResSettingsState extends State<ResSettings> {
  late final name = TextEditingController(text: app.me!.name);
  late final email = TextEditingController(text: app.me!.email);
  late final phone = TextEditingController(text: app.me!.phone);
  final cur = TextEditingController();
  final nw = TextEditingController();
  final conf = TextEditingController();

  @override
  void dispose() {
    for (final c in [name, email, phone, cur, nw, conf]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => SubPage(
        title: 'Settings',
        children: [
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile', style: hd(18)),
                const SizedBox(height: 4),
                Text('Your unit assignment can only be changed by the administrator.', style: TextStyle(color: muted(context), fontSize: 12.5)),
                const SizedBox(height: 14),
                ProfilePhotoEditor(
                  initials: initialsOf(app.me!.name),
                  photo: app.me!.photo,
                  onChange: app.setMyPhoto,
                ),
                const SizedBox(height: 14),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 10),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address')),
                const SizedBox(height: 10),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
                const SizedBox(height: 10),
                TextField(enabled: false, controller: TextEditingController(text: app.me!.unit), decoration: const InputDecoration(labelText: 'Unit (set by administrator)')),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
                        msg(context, 'Full name and email are required.');
                        return;
                      }
                      app.saveProfile(name.text, email.text, phone.text);
                      msg(context, 'Profile updated.');
                    },
                    child: const Text('Save changes'),
                  ),
                ),
              ],
            ),
          ),
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Security', style: hd(18)),
                const SizedBox(height: 4),
                Text('Change the password used to sign in.', style: TextStyle(color: muted(context), fontSize: 12.5)),
                const SizedBox(height: 14),
                TextField(controller: cur, obscureText: true, decoration: const InputDecoration(labelText: 'Current password', hintText: 'Leave blank if you signed in without one')),
                const SizedBox(height: 10),
                TextField(controller: nw, obscureText: true, decoration: const InputDecoration(labelText: 'New password', hintText: 'At least 6 characters')),
                const SizedBox(height: 10),
                TextField(controller: conf, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password')),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final err = app.changePassword(cur.text, nw.text, conf.text);
                      if (err == null) {
                        cur.clear();
                        nw.clear();
                        conf.clear();
                      }
                      msg(context, err ?? 'Password updated.');
                    },
                    child: const Text('Update password'),
                  ),
                ),
              ],
            ),
          ),
          RCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Easier on the eyes at night'),
              value: app.dark,
              activeThumbColor: lavDeep,
              onChanged: (_) => app.toggleDark(),
            ),
          ),
          RCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(child: Text("Where you're signed in", style: hd(18))),
                  ]),
                ),
                for (final s in app.sessions)
                  ListTile(
                    leading: Icon(s.current ? Icons.smartphone_rounded : Icons.devices_other_rounded),
                    title: Row(children: [
                      Flexible(child: Text(s.device, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                      if (s.current) ...[const SizedBox(width: 6), const Pill('This device', tone: Tone.good)],
                    ]),
                    subtitle: Text('${s.location} · ${s.when}'),
                    trailing: s.current ? null : TextButton(onPressed: () => app.logoutSession(s.id), child: const Text('Log out', style: TextStyle(color: danger))),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                  child: Text('Your sign-in is kept on this device only.', style: TextStyle(color: muted(context), fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
