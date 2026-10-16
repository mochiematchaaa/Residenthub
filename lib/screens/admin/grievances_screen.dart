// ADMIN page: Grievances.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';

class AdminGrievances extends StatelessWidget {
  const AdminGrievances({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => SubPage(
        title: 'Grievances',
        subtitle: 'Track resident concerns and move them to resolved.',
        children: [
          for (final g in app.grievances)
            RCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(g.title, style: hd(16))),
                    Pill(g.statusLabel),
                  ]),
                  const SizedBox(height: 3),
                  Text('Reported by ${g.by}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                  if (g.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(g.body, style: TextStyle(color: muted(context), fontSize: 13)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(
                          child: Container(
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: i <= g.stage ? (g.stage == 2 ? const Color(0xFF3F8F5B) : lav) : Theme.of(context).colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (g.stage < 2) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => app.advanceGrievance(g.id),
                        child: Text(g.stage == 0 ? 'Start working on it' : 'Mark resolved'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
