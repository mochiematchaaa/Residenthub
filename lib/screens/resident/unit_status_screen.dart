import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

/// Resident posts the current state of their unit; the administrator sees it right away.
class ResUnitStatus extends StatefulWidget {
  const ResUnitStatus({super.key});

  @override
  State<ResUnitStatus> createState() => _ResUnitStatusState();
}

class _ResUnitStatusState extends State<ResUnitStatus> {
  String sel = 'owner';
  final note = TextEditingController();
  String? error;

  @override
  void initState() {
    super.initState();
    final r = app.myUnitRec;
    if (r != null && r.usage.isNotEmpty) sel = r.usage;
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final rec = app.myUnitRec;
        final cur = statusOf(rec?.usage ?? 'owner');
        final history = app.myStatusUpdates;
        final opt = statusOf(sel);
        return SubPage(
          title: 'Unit status',
          subtitle: 'Keep the administrator updated on the state of your unit.',
          children: [
            // --- current status
            PastelCard(
              color: cur.color,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GlassIcon(cur.icon, size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${app.myUnit} is currently', style: const TextStyle(color: inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(cur.label, style: hd(23)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (rec != null && rec.statusNote.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(rec.statusNote, style: const TextStyle(color: inkSoft, height: 1.35)),
                  ],
                  if (rec != null && rec.statusDate.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Last updated ${rec.statusDate}', style: const TextStyle(color: inkSoft, fontSize: 12)),
                  ],
                  if (rec != null && rec.needsApproval) ...[
                    const SizedBox(height: 14),
                    _approval(rec),
                  ],
                ],
              ),
            ),

            // --- post an update
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Post an update', style: hd(18)),
                  const SizedBox(height: 4),
                  Text('Pick the new state. It reaches the administrator immediately.', style: TextStyle(color: muted(context), fontSize: 12.5)),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.25,
                    children: [for (final o in statusOptions) _tile(context, o)],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: note,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: 'Note', hintText: opt.hint),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(error!, style: const TextStyle(color: danger, fontSize: 12.5)),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final err = app.postMyStatus(sel, note.text);
                        setState(() => error = err);
                        if (err == null) {
                          final needs = sel == 'shortterm' || sel == 'business';
                          note.clear();
                          msg(context, needs ? "Sent. The administrator will review it, and you will see the decision here." : 'Status updated. The administrator can see it now.');
                        }
                      },
                      child: const Text('Post update'),
                    ),
                  ),
                ],
              ),
            ),

            // --- history
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Update history', style: hd(18)),
                  const SizedBox(height: 10),
                  if (history.isEmpty)
                    Text('No updates yet.', style: TextStyle(color: muted(context)))
                  else
                    for (var i = 0; i < history.length; i++) _historyRow(context, history[i], last: i == history.length - 1),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Short-term rentals and home businesses wait for the administrator's decision.
  Widget _approval(Unit rec) {
    final st = rec.usageStatus.isEmpty ? 'pending' : rec.usageStatus;
    final decided = st != 'pending';
    final rejected = st == 'rejected';
    Widget step(String label, bool done, {bool bad = false}) => Expanded(
          child: Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: bad ? danger : (done ? ink : Colors.white.withAlpha(190)), shape: BoxShape.circle),
                child: Icon(bad ? Icons.close_rounded : (done ? Icons.check_rounded : Icons.more_horiz_rounded),
                    size: 16, color: done || bad ? Colors.white : ink),
              ),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withAlpha(150), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            step('Declared', true),
            step('Under review', decided),
            step(rejected ? 'Not approved' : 'Approved', decided, bad: rejected),
          ]),
          const SizedBox(height: 10),
          Text(
            st == 'pending'
                ? 'Waiting for the administrator to review this.'
                : st == 'approved'
                    ? 'The administrator approved this.'
                    : 'Not approved. ${rec.usageRemark}',
            style: const TextStyle(fontSize: 12.5, height: 1.35, color: inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _historyRow(BuildContext context, StatusUpdate u, {required bool last}) {
    final o = statusOf(u.key);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: o.color.color, shape: BoxShape.circle, border: Border.all(color: lavDeep, width: 2)),
              ),
              if (!last) Expanded(child: Container(width: 2, color: Theme.of(context).colorScheme.outlineVariant)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Pill(o.label, tone: o.tone),
                      const Spacer(),
                      Text(u.date, style: TextStyle(color: muted(context), fontSize: 12)),
                    ],
                  ),
                  if (u.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(u.note, style: const TextStyle(fontSize: 13.5, height: 1.35)),
                  ],
                  const SizedBox(height: 2),
                  Text('Posted by ${u.by}', style: TextStyle(color: muted(context), fontSize: 11.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, StatusOption o) {
    final active = sel == o.key;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() {
        sel = o.key;
        error = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? o.color.color : cs.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? ink : cs.outlineVariant, width: active ? 2 : 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(o.icon, color: active ? ink : cs.onSurfaceVariant),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: active ? ink : cs.onSurface)),
                const SizedBox(height: 2),
                Text(o.help, style: TextStyle(fontSize: 11.5, height: 1.25, color: active ? inkSoft : cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
