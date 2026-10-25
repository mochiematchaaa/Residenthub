// DEMO ONLY - ADMIN page: Maintenance (preventive schedule, equipment list, maintenance staff).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/maintenance_widgets.dart';

class AdminMaintenance extends StatefulWidget {
  const AdminMaintenance({super.key});

  @override
  State<AdminMaintenance> createState() => _AdminMaintenanceState();
}

class _AdminMaintenanceState extends State<AdminMaintenance> {
  static const _tabs = ['Schedule', 'Equipment', 'Staff'];
  String tab = 'Schedule';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, maint]),
      builder: (context, _) {
        return SubPage(
          title: 'Maintenance',
          subtitle: 'Preventive maintenance schedule, equipment, and the staff who do the work.',
          fab: FloatingActionButton.extended(
            backgroundColor: lav,
            foregroundColor: ink,
            onPressed: () {
              if (tab == 'Schedule') {
                showTaskSheet(context);
              } else if (tab == 'Equipment') {
                showEquipmentSheet(context);
              } else {
                showStaffSheet(context);
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(tab == 'Schedule' ? 'Task' : tab == 'Equipment' ? 'Equipment' : 'Staff'),
          ),
          children: [
            Row(
              children: [
                Expanded(child: MaintStat('Overdue', maint.overdueCount, tone: maint.overdueCount > 0 ? Tone.bad : null)),
                const SizedBox(width: 10),
                Expanded(child: MaintStat('Due in 7 days', maint.dueThisWeekCount, tone: maint.dueThisWeekCount > 0 ? Tone.warn : null)),
                const SizedBox(width: 10),
                Expanded(child: MaintStat('To fix', maint.equipmentToFix, tone: maint.equipmentToFix > 0 ? Tone.bad : null)),
              ],
            ),
            FilterRow(options: _tabs, selected: tab, onSelect: (t) => setState(() => tab = t)),
            if (tab == 'Schedule') ..._schedule(context),
            if (tab == 'Equipment') ..._equipment(context),
            if (tab == 'Staff') ..._staff(context),
          ],
        );
      },
    );
  }

  List<Widget> _schedule(BuildContext context) {
    final list = maint.sortedTasks;
    if (list.isEmpty) return const [EmptyBox('No maintenance tasks yet. Tap Task to add one.', icon: Icons.handyman_outlined)];
    return [
      for (final t in list)
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(t.title, style: hd(16))),
                Pill(taskState(t).$1, tone: toneFromLevel(taskState(t).$2)),
              ]),
              const SizedBox(height: 3),
              Text('${maint.equipOf(t).isEmpty ? 'No equipment' : maint.equipOf(t)} · ${t.every}', style: TextStyle(color: muted(context), fontSize: 12.5)),
              const SizedBox(height: 6),
              Text('Next due ${shortDate(t.due)}${t.lastDone == null ? '' : ' · last done ${shortDate(t.lastDone!)}'}', style: const TextStyle(fontSize: 13)),
              Text(maint.assigneeOf(t).isEmpty ? 'Not assigned yet' : 'Assigned to ${maint.assigneeOf(t)}',
                  style: TextStyle(color: muted(context), fontSize: 13)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      maint.markDone(t, app);
                      msg(context, 'Marked done. Next due ${shortDate(t.due)}.');
                    },
                    child: const Text('Mark done'),
                  ),
                ),
                IconButton(tooltip: 'Edit', onPressed: () => showTaskSheet(context, task: t), icon: const Icon(Icons.edit_outlined)),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () async {
                    final ok = await confirmDialog(context, 'Delete task', 'Delete “${t.title}”? This cannot be undone.', confirm: 'Delete', destructive: true);
                    if (ok) maint.deleteTask(t, app);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: danger),
                ),
              ]),
            ],
          ),
        ),
    ];
  }

  List<Widget> _equipment(BuildContext context) {
    final list = [...maint.equipment]..sort((a, b) => a.name.compareTo(b.name));
    if (list.isEmpty) return const [EmptyBox('No equipment listed yet. Tap Equipment to add one.', icon: Icons.precision_manufacturing_outlined)];
    return [
      for (final e in list)
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(e.name, style: hd(16))),
                Pill(e.status, tone: equipmentTone(e.status)),
              ]),
              const SizedBox(height: 3),
              Text('${e.category} · ${e.location}', style: TextStyle(color: muted(context), fontSize: 12.5)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(e.lastService == null ? 'Never serviced' : 'Last service ${shortDate(e.lastService!)}', style: const TextStyle(fontSize: 13)),
                if (maint.openRepairsFor(app, e.id) > 0) Pill('${maint.openRepairsFor(app, e.id)} open repair', tone: Tone.warn),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                TextButton.icon(onPressed: () => showEquipmentSheet(context, item: e), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await confirmDialog(context, 'Delete equipment', 'Delete “${e.name}”? This cannot be undone.', confirm: 'Delete', destructive: true);
                    if (!ok || !context.mounted) return;
                    final problem = maint.deleteEquipment(e, app);
                    if (problem != null) msg(context, problem);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: danger),
                  label: const Text('Delete', style: TextStyle(color: danger)),
                ),
              ]),
            ],
          ),
        ),
    ];
  }

  List<Widget> _staff(BuildContext context) {
    final list = [...maint.staff]..sort((a, b) => a.name.compareTo(b.name));
    if (list.isEmpty) return const [EmptyBox('No maintenance staff yet. Tap Staff to add one.', icon: Icons.engineering_outlined)];
    return [
      for (final s in list)
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.name, style: hd(16)),
              const SizedBox(height: 3),
              Text('${s.role}${s.phone.isEmpty ? '' : ' · ${s.phone}'}', style: TextStyle(color: muted(context), fontSize: 12.5)),
              const SizedBox(height: 6),
              Text('${maint.openWorkOf(s, app)} open assignment(s)', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              Row(children: [
                TextButton.icon(onPressed: () => showStaffSheet(context, person: s), icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await confirmDialog(context, 'Delete staff member', 'Delete “${s.name}”? This cannot be undone.', confirm: 'Delete', destructive: true);
                    if (!ok || !context.mounted) return;
                    final problem = maint.deleteStaff(s, app);
                    if (problem != null) msg(context, problem);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: danger),
                  label: const Text('Delete', style: TextStyle(color: danger)),
                ),
              ]),
            ],
          ),
        ),
    ];
  }
}
