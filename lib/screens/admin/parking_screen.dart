import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

/// Administrator: the motor parking slots and the residents asking for one.
class AdminParking extends StatelessWidget {
  const AdminParking({super.key});

  void _slotSheet(BuildContext context, ParkingSlot s) {
    if (s.used) {
      confirmDialog(context, 'Release ${s.id}?', 'Take the slot back from ${s.unit}.', confirm: 'Release', destructive: true).then((ok) {
        if (ok) app.releaseSlot(s);
      });
      return;
    }
    final unitsList = [for (final u in app.units) if (app.slotOf(u.unit) == null) u.unit];
    if (unitsList.isEmpty) {
      msg(context, 'Every unit already has a slot.');
      return;
    }
    showFormSheet(
      context,
      title: 'Assign ${s.id}',
      subtitle: 'Choose the unit that gets this slot.',
      choices: [ChoiceSpec('unit', 'Unit', unitsList, unitsList.first)],
      submit: 'Assign slot',
      onSubmit: (v) {
        app.assignSlot(s, v['unit'] as String);
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final waiting = app.parking.where((p) => !p.confirmed).toList();
        final free = app.slots.length - app.slotsUsed;
        return SubPage(
          title: 'Motor parking',
          subtitle: 'Assign slots to residents and release them when they are done.',
          children: [
            PastelCard(
              color: Pastel.peach,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: StatsRow([
                ['In use', '${app.slotsUsed}'],
                ['Free', '$free'],
                ['Waiting', '${waiting.length}'],
                ['Rate', peso(app.motorRate)],
              ]),
            ),
            Text('Requests', style: hd(18)),
            if (waiting.isEmpty)
              const EmptyBox('No requests waiting.', icon: Icons.two_wheeler_outlined)
            else
              RCard(
                child: Column(
                  children: [
                    for (final p in waiting)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${p.unit} · ${p.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(app.freeSlot == null ? 'No free slot right now' : 'Next free slot: ${app.freeSlot!.id}'),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            TextButton(onPressed: () => app.declineParking(p), child: const Text('Decline')),
                            FilledButton(
                              style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                              onPressed: () {
                                final err = app.assignRequest(p);
                                if (err != null) msg(context, err);
                              },
                              child: const Text('Assign'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(child: Text('Slots', style: hd(18))),
                TextButton.icon(
                  onPressed: () => showFormSheet(
                    context,
                    title: 'Add parking slots',
                    subtitle: app.slots.isEmpty ? 'How many motor parking slots does the building have?' : 'You have ${app.slots.length} slots. How many more should be added?',
                    fields: const [FieldSpec('n', 'Number of slots', type: TextInputType.number, hint: 'e.g. 24')],
                    submit: 'Add slots',
                    onSubmit: (v) => app.addSlots(v['n'] as String),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add slots'),
                ),
              ],
            ),
            if (app.slots.isEmpty)
              const EmptyBox('No slots yet. Tap "Add slots" to set up the parking area.', icon: Icons.local_parking_rounded)
            else
              Text('Tap a slot to assign or release it.', style: TextStyle(color: muted(context), fontSize: 12.5)),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                for (final s in app.slots)
                  Builder(builder: (context) {
                    final t = toneOf(context, s.used ? Tone.bad : Tone.good);
                    return GestureDetector(
                      onTap: () => _slotSheet(context, s),
                      child: Container(
                        decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(s.id, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: t.fg)),
                            Text(s.used ? s.unit.replaceFirst('Unit ', '') : 'Free',
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: t.fg)),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
            RCard(
              child: Text(
                'Change the monthly rate under Finance. Residents request a slot from their Dues page.',
                style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        );
      },
    );
  }
}
