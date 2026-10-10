import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'resident_screens.dart';

class ResMore extends StatelessWidget {
  const ResMore({super.key});

  @override
  Widget build(BuildContext context) {
    final me = app.me!;
    final openGr = app.myGrievances.where((g) => g.stage < 2).length;
    final rec = app.myUnitRec;
    return TabPage(
      title: 'More',
      subtitle: 'Everything else for your unit.',
      children: [
        RCard(
          onTap: () => go(context, const ResSettings()),
          child: Row(
            children: [
              Avatar(initialsOf(me.name), size: 54, photo: me.photo),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.name, style: hd(19)),
                    Text(me.unit, style: TextStyle(color: muted(context))),
                    Text(me.email, style: TextStyle(color: muted(context), fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: muted(context)),
            ],
          ),
        ),
        NavGroup(label: 'My unit', children: [
          NavTile(icon: Icons.calendar_month_rounded, title: 'Calendar', subtitle: 'Events, bookings and due dates', onTap: () => go(context, const CalendarScreen(admin: false))),
          NavTile(icon: Icons.event_note_rounded, title: 'My reservations', subtitle: '${app.myBookings.length} requests and bookings', onTap: () => go(context, const ResReservations())),
          NavTile(icon: Icons.edit_note_rounded, title: 'Grievances', subtitle: openGr == 0 ? 'Nothing open' : '$openGr open', onTap: () => go(context, const ResGrievances())),
          NavTile(
            icon: statusOf(rec?.usage ?? 'owner').icon,
            title: 'Unit status',
            subtitle: rec == null ? 'Post an update on your unit' : 'Now: ${usageLabel(rec.usage)}',
            onTap: () => go(context, const ResUnitStatus()),
          ),
        ]),
        NavGroup(label: 'Documents', children: [
          NavTile(icon: Icons.lock_outline_rounded, title: 'Finance documents', subtitle: 'Statement, payments and receipts', onTap: () => go(context, const ResFinanceDocs())),
          NavTile(icon: Icons.folder_copy_outlined, title: 'Community documents', subtitle: '${app.communityDocs.length} shared files', onTap: () => go(context, const ResDocuments())),
        ]),
        NavGroup(label: 'Account', children: [
          NavTile(icon: Icons.settings_outlined, title: 'Settings', subtitle: 'Profile, password, appearance, devices', onTap: () => go(context, const ResSettings())),
        ]),
        OutlinedButton.icon(
          onPressed: () async {
            if (await confirmDialog(context, 'Log out?', 'You will need to sign in again.', confirm: 'Log out')) app.logout();
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}
