import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

class AdminFacility extends StatefulWidget {
  const AdminFacility({super.key});

  @override
  State<AdminFacility> createState() => _AdminFacilityState();
}

class _AdminFacilityState extends State<AdminFacility> {
  int fac = 0;

  @override
  Widget build(BuildContext context) {
    final reqs = app.bookings.where((b) => b.status != 'Completed').toList();
    return TabPage(
      title: 'Facility booking',
      subtitle: 'Check availability and approve or deny reservation requests.',
      children: [
        FilterRow(
          options: [for (final f in AppState.facilities) f[0]],
          selected: AppState.facilities[fac][0],
          onSelect: (v) => setState(() => fac = AppState.facilities.indexWhere((f) => f[0] == v)),
        ),
        if (fac == 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: toneOf(context, Tone.good).bg, borderRadius: BorderRadius.circular(14)),
            child: Text('Free for residents. Guests/visitors pay ₱150 per visit, collected at the gate.',
                style: TextStyle(color: toneOf(context, Tone.good).fg, fontSize: 12.5)),
          ),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${AppState.facilities[fac][0]} · availability today', style: hd(18)),
              Text('Hours ${AppState.facilities[fac][1]} · tap a slot to open or block it', style: TextStyle(color: muted(context), fontSize: 12.5)),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
                children: [
                  for (var i = 0; i < AppState.slotTimes.length; i++)
                    Builder(builder: (context) {
                      final booked = app.slotBooked(fac, i);
                      final t = toneOf(context, booked ? Tone.bad : Tone.good);
                      return GestureDetector(
                        onTap: () => app.toggleSlot(fac, i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(AppState.slotTimes[i], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: t.fg)),
                              Text(booked ? 'Booked' : 'Open', style: TextStyle(fontSize: 11, color: t.fg)),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
        ),
        SectionHeader('Booking requests', action: '${app.pendingBookings} pending'),
        for (final r in reqs)
          RCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconBadge(r.place == 'Swimming Pool' ? Icons.pool_rounded : Icons.celebration_rounded, accent: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.who, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${r.place} · ${r.when}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                        ],
                      ),
                    ),
                    if (r.status != 'Pending') Pill(r.status),
                  ],
                ),
                if (r.status == 'Pending') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: FilledButton(onPressed: () => app.bookAct(r.id, 'Approved'), child: const Text('Approve'))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton(onPressed: () => app.bookAct(r.id, 'Denied'), child: const Text('Deny'))),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
