import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import 'admin_screens.dart';

class AdminUnits extends StatefulWidget {
  const AdminUnits({super.key});

  @override
  State<AdminUnits> createState() => _AdminUnitsState();
}

class _AdminUnitsState extends State<AdminUnits> {
  static const filters = ['All units', 'Vacant', 'Overdue dues', 'Rented / business'];
  String filter = filters[0];
  String q = '';

  @override
  Widget build(BuildContext context) {
    final rows = app.units.where((u) {
      final okFilter = filter == filters[0] ||
          (filter == filters[1] && u.status == 'Vacant') ||
          (filter == filters[2] && u.overdue > 0) ||
          (filter == filters[3] && const ['tenant', 'shortterm', 'business'].contains(u.usage));
      final s = q.trim().toLowerCase();
      return okFilter && (s.isEmpty || '${u.unit} ${u.name} ${u.contact}'.toLowerCase().contains(s));
    }).toList();

    return TabPage(
      title: 'Units & residents',
      subtitle: 'Maintain unit, occupancy and resident records.',
      children: [
        TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: const InputDecoration(hintText: 'Search unit, name or contact…', prefixIcon: Icon(Icons.search_rounded)),
        ),
        FilterRow(options: filters, selected: filter, onSelect: (v) => setState(() => filter = v)),
        Text('${rows.length} of ${app.units.length} units on record', style: TextStyle(color: muted(context), fontWeight: FontWeight.w600)),
        if (rows.isEmpty) const EmptyBox('No units match your search.', icon: Icons.search_off_rounded),
        for (final u in rows)
          RCard(
            onTap: () => _unitSheet(context, u),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(color: u.status == 'Vacant' ? toneOf(context, Tone.warn).bg : ink, borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: Text(u.unit.replaceFirst('Unit ', ''), style: TextStyle(fontWeight: FontWeight.w800, color: u.status == 'Vacant' ? toneOf(context, Tone.warn).fg : lav)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${u.type} · ${u.contact}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                      const SizedBox(height: 6),
                      Pill(usageLabel(u.usage), tone: statusOf(u.usage).tone),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Pill(u.status, tone: u.status == 'Vacant' ? Tone.warn : Tone.good),
                    if (u.overdue > 0) ...[
                      const SizedBox(height: 6),
                      Text('${u.overdue} mo overdue', style: const TextStyle(color: danger, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _unitSheet(BuildContext context, Unit u) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(u.unit, style: hd(24)),
            Text(u.name, style: TextStyle(color: muted(context))),
            const SizedBox(height: 14),
            _kv(context, 'Occupancy', u.type),
            _kv(context, 'Status', u.status),
            _kv(context, 'Contact', u.contact),
            _kv(context, 'Overdue dues', u.overdue == 0 ? 'None' : '${u.overdue} month(s) · ${peso(u.overdue * 450)}'),
            _kv(context, 'Unit state', usageLabel(u.usage)),
            if (u.statusNote.isNotEmpty) _kv(context, 'Note', u.statusNote),
            if (u.statusDate.isNotEmpty) _kv(context, 'Updated', u.statusDate),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  showAdminStatusSheet(context, u);
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Update status'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


Widget _kv(BuildContext context, String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(k, style: TextStyle(color: muted(context), fontWeight: FontWeight.w600))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
