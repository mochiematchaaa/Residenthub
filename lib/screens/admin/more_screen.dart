import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'admin_screens.dart';

class AdminMore extends StatelessWidget {
  const AdminMore({super.key});

  @override
  Widget build(BuildContext context) {
    return TabPage(
      title: 'More',
      subtitle: 'Community tools and administration.',
      children: [
        RCard(
          onTap: () => go(context, const AdminSettings()),
          child: Row(
            children: [
              Avatar(initialsOf(app.adminName), size: 54, photo: app.adminPhoto),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.adminName, style: hd(19)),
                    Text('Owner · Administrator · tap to edit profile', style: TextStyle(color: muted(context), fontSize: 12.5)),
                  ],
                ),
              ),
              IconButton(
                onPressed: app.toggleDark,
                icon: Icon(app.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              ),
            ],
          ),
        ),
        NavGroup(label: 'Community', children: [
          NavTile(icon: Icons.calendar_month_rounded, title: 'Calendar', subtitle: 'Events and facility bookings', onTap: () => go(context, const CalendarScreen(admin: true))),
          NavTile(icon: Icons.campaign_outlined, title: 'Announcements & events', subtitle: '${app.announcements.length} announcements · ${app.events.length} events', onTap: () => go(context, const AdminAnnouncements())),
          NavTile(
            icon: Icons.build_circle_outlined,
            title: 'Grievances',
            subtitle: '${app.openGrievances} open',
            onTap: () => go(context, const AdminGrievances()),
            trailing: app.openGrievances > 0 ? Pill('${app.openGrievances}', tone: Tone.warn) : null,
          ),
          NavTile(
            icon: Icons.home_work_outlined,
            title: 'Unit status',
            subtitle: app.newStatusUpdates == 0 ? 'State of every unit' : '${app.newStatusUpdates} new update(s) from residents',
            onTap: () => go(context, const AdminUnitStatus()),
            trailing: app.newStatusUpdates > 0 ? Pill('${app.newStatusUpdates}', tone: Tone.warn) : null,
          ),
        ]),
        NavGroup(label: 'Money and files', children: [
          NavTile(icon: Icons.north_east_rounded, title: 'Expenses', subtitle: '${app.expenses.length} purchases · ${peso(app.spentThisMonth)} this month · monthly report', onTap: () => go(context, const AdminExpenses())),
          NavTile(icon: Icons.lock_outline_rounded, title: 'Finance documents', subtitle: '${app.financeDocs.length} documents · ${app.payments.length} receipts', onTap: () => go(context, const AdminFinanceDocs())),
          NavTile(icon: Icons.folder_copy_outlined, title: 'Community documents', subtitle: '${app.communityDocs.length} files', onTap: () => go(context, const AdminDocs())),
        ]),
        NavGroup(label: 'Administration', children: [
          NavTile(icon: Icons.admin_panel_settings_outlined, title: 'Manage access', subtitle: '${app.trusted.length + 1} accounts', onTap: () => go(context, const AdminAccess())),
          NavTile(icon: Icons.settings_outlined, title: 'Settings', subtitle: 'Profile, photo, password, appearance', onTap: () => go(context, const AdminSettings())),
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
