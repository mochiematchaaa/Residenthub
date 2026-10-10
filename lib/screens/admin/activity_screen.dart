import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/doc_files.dart';
import '../../widgets/widgets.dart';
import '../shared/document_viewer_screen.dart';

/// Administrator: the full log of what happened in the app.
class AdminActivity extends StatefulWidget {
  const AdminActivity({super.key});

  @override
  State<AdminActivity> createState() => _AdminActivityState();
}

class _AdminActivityState extends State<AdminActivity> {
  String _area = 'All';

  List<DocBlock> _blocks(List<ActivityEntry> list) => [
        const DocBlock.h1('Activity log'),
        const DocBlock.p('City Residences Condominium Corporation'),
        DocBlock.table([
          const ['When', 'Area', 'What happened'],
          for (final a in list) [shortDate(a.at), a.area, a.title],
        ]),
      ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final areas = ['All', ...{for (final a in app.activityLog) a.area}];
        if (!areas.contains(_area)) _area = 'All';
        final shown = app.activityLog.where((a) => _area == 'All' || a.area == _area).toList();
        return SubPage(
          title: 'Activity log',
          subtitle: 'Everything that happened in the community, newest first.',
          children: [
            FilterRow(options: areas, selected: _area, onSelect: (v) => setState(() => _area = v)),
            if (shown.isEmpty)
              const EmptyBox('Nothing has happened yet.', icon: Icons.history_rounded)
            else ...[
              OutlinedButton.icon(
                onPressed: () => runSave(context, 'Excel file', () => exportXlsx('Activity log', _blocks(shown))),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Export to Excel'),
              ),
              RCard(
                child: Column(
                  children: [
                    for (final a in shown)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        subtitle: Text('${a.area} · ${AppState.ago(a.at)}'),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
