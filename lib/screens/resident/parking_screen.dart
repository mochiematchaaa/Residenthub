import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

/// Resident: the parking slot of the unit, the request, and which slots are free.
class ResParking extends StatelessWidget {
  /// True when shown as a tab of the bottom bar (no back arrow).
  final bool tab;
  const ResParking({super.key, this.tab = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final mine = app.slotOf(app.myUnit);
        final requested = app.parkingRequested && mine == null;
        final free = app.slots.length - app.slotsUsed;
        final cs = Theme.of(context).colorScheme;
        final kids = <Widget>[
            PastelCard(
              color: mine != null ? Pastel.mint : (requested ? Pastel.butter : Pastel.sky),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GlassIcon(Icons.two_wheeler_rounded, size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mine != null ? 'Your parking slot' : (requested ? 'Request sent' : 'No parking slot yet'),
                              style: const TextStyle(color: inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(mine != null ? mine.id : (requested ? 'Waiting for the office' : app.myUnit), style: hd(23)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    mine != null
                        ? 'Assigned to ${app.myUnit}.${app.motorRate > 0 ? ' Rental: ${peso(app.motorRate)} per month, paid under Dues.' : ''}'
                        : requested
                            ? 'The office will assign you a slot when one is free. You will get a notice.'
                            : (app.slots.isEmpty
                                ? 'The office has not set up the parking slots yet. You can still send a request.'
                                : '$free of ${app.slots.length} slots are free right now.'),
                    style: const TextStyle(color: inkSoft, height: 1.4),
                  ),
                  if (mine == null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: requested
                          ? OutlinedButton(
                              onPressed: () async {
                                final ok = await confirmDialog(context, 'Cancel your parking request?', 'You can send a new request any time.', confirm: 'Cancel request', destructive: true);
                                if (ok) app.cancelMyParkingRequest();
                              },
                              child: const Text('Cancel my request'),
                            )
                          : FilledButton(
                              onPressed: () {
                                app.requestParking();
                                msg(context, 'Parking slot request sent to the administrator.');
                              },
                              child: const Text('Request a parking slot'),
                            ),
                    ),
                  ],
                ],
              ),
            ),
            if (app.slots.isNotEmpty)
              RCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Parking map', style: hd(18))),
                        Text('$free of ${app.slots.length} free', style: TextStyle(color: muted(context), fontSize: 12.5)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.45,
                      children: [
                        for (final s in app.slots)
                          Builder(builder: (context) {
                            final isMine = s.unit == app.myUnit;
                            final t = toneOf(context, s.used ? Tone.bad : Tone.good);
                            return Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: isMine ? ink : t.bg, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(s.id, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isMine ? Colors.white : t.fg)),
                                  Text(isMine ? 'Yours' : (s.used ? 'Taken' : 'Free'),
                                      style: TextStyle(fontSize: 10.5, color: isMine ? lav : t.fg)),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ],
                ),
              ),
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How it works', style: hd(18)),
                  const SizedBox(height: 8),
                  for (final line in [
                    'Tap Request a parking slot. One request per unit.',
                    'The office assigns a free slot to your unit.',
                    'The monthly rental${app.motorRate > 0 ? ' (${peso(app.motorRate)})' : ''} is paid under Dues, like any other charge.',
                    'When you no longer need the slot, tell the office and it will be released.',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 18, color: cs.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(child: Text(line, style: TextStyle(color: muted(context), fontSize: 13, height: 1.4))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ];
        return tab
            ? TabPage(title: 'Motor parking', subtitle: 'Your parking slot, your request, and which slots are free.', children: kids)
            : SubPage(title: 'Motor parking', subtitle: 'Your parking slot, your request, and which slots are free.', children: kids);
      },
    );
  }
}
