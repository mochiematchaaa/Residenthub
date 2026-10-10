import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'resident_screens.dart';

class ResBook extends StatefulWidget {
  const ResBook({super.key});

  @override
  State<ResBook> createState() => _ResBookState();
}

class _ResBookState extends State<ResBook> {
  int fac = 0;
  int? pick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TabPage(
      title: 'Book a facility',
      subtitle: 'Check availability and send a reservation request.',
      children: [
        Row(
          children: [
            for (var i = 0; i < AppState.facilities.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    fac = i;
                    pick = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: fac == i ? ink : cs.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: fac == i ? ink : cs.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(i == 0 ? Icons.pool_rounded : Icons.celebration_rounded, color: fac == i ? lav : cs.onSurfaceVariant),
                        const SizedBox(height: 10),
                        Text(AppState.facilities[i][0], style: TextStyle(fontWeight: FontWeight.w800, color: fac == i ? Colors.white : cs.onSurface)),
                        const SizedBox(height: 2),
                        Text(AppState.facilities[i][1], style: TextStyle(fontSize: 11.5, color: fac == i ? const Color(0xFFB9C3DC) : cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (fac == 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: toneOf(context, Tone.good).bg, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: toneOf(context, Tone.good).fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Free for you as a resident. Guests pay ₱150 per visit, collected at the gate.',
                    style: TextStyle(color: toneOf(context, Tone.good).fg, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${AppState.facilities[fac][0]} · today', style: hd(18)),
              const SizedBox(height: 2),
              Text('Tap an open slot to request it', style: TextStyle(color: muted(context), fontSize: 12.5)),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
                children: [
                  for (var i = 0; i < AppState.slotTimes.length; i++) _slot(context, i),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _legend(context, Tone.good, 'Open'),
                  const SizedBox(width: 14),
                  _legend(context, Tone.bad, 'Booked'),
                  const SizedBox(width: 14),
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Text('Selected', style: TextStyle(fontSize: 12, color: muted(context))),
                ],
              ),
            ],
          ),
        ),
        if (pick != null)
          PastelCard(
          color: Pastel.lavender,
          child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your request', style: TextStyle(color: inkSoft, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text('${AppState.facilities[fac][0]}, ${AppState.slotTimes[pick!]}', style: hd(17, color: ink)),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    app.submitBooking(fac, pick!);
                    setState(() => pick = null);
                    msg(context, 'Request sent. Track it under My reservations.');
                  },
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
        NavTile(
          icon: Icons.list_alt_rounded,
          title: 'My reservations',
          subtitle: '${app.myBookings.length} on record',
          onTap: () => go(context, const ResReservations()),
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, Tone t, String label) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: toneOf(context, t).fg, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: muted(context))),
    ]);
  }

  Widget _slot(BuildContext context, int i) {
    final booked = app.slotBooked(fac, i);
    final picked = pick == i;
    final t = toneOf(context, booked ? Tone.bad : Tone.good);
    return GestureDetector(
      onTap: booked ? null : () => setState(() => pick = picked ? null : i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: picked ? ink : t.bg,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(AppState.slotTimes[i], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: picked ? Colors.white : t.fg)),
            Text(booked ? 'Booked' : picked ? 'Selected' : 'Open', style: TextStyle(fontSize: 11, color: picked ? lav : t.fg)),
          ],
        ),
      ),
    );
  }
}
