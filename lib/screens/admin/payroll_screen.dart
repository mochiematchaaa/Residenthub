import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/doc_files.dart';
import '../../widgets/widgets.dart';
import '../shared/document_viewer_screen.dart';

/// Payroll: the staff list, monthly payroll runs, payroll registers and payslips.
class AdminPayroll extends StatelessWidget {
  const AdminPayroll({super.key});

  void _editEmployee(BuildContext context, [Employee? e]) {
    showFormSheet(
      context,
      title: e == null ? 'Add employee' : 'Edit employee',
      subtitle: 'Deductions are typed in by you (for example SSS, PhilHealth, Pag-IBIG or tax). Enter the total per month.',
      choices: [ChoiceSpec('role', 'Position', staffRoles, e != null && staffRoles.contains(e.role) ? e.role : staffRoles.first)],
      fields: [
        FieldSpec('name', 'Full name', initial: e?.name ?? ''),
        FieldSpec('salary', 'Monthly salary (₱)', type: TextInputType.number, initial: e == null ? '' : e.salary.toStringAsFixed(0)),
        FieldSpec('ded', 'Monthly deductions (₱, optional)', type: TextInputType.number, initial: e == null || e.deductions == 0 ? '' : e.deductions.toStringAsFixed(0)),
      ],
      submit: e == null ? 'Add employee' : 'Save',
      onSubmit: (v) => app.saveEmployee(e, v['name'] as String, v['role'] as String, v['salary'] as String, v['ded'] as String),
    );
  }

  void _run(BuildContext context) {
    final now = DateTime.now();
    final months = [DateTime(now.year, now.month, 1), DateTime(now.year, now.month - 1, 1)];
    final labels = [for (final m in months) app.monthLabel(m)];
    showFormSheet(
      context,
      title: 'Run payroll',
      subtitle: 'Pays all ${app.employees.length} employee${app.employees.length == 1 ? '' : 's'} for the month you choose and creates the payroll register and payslips.',
      choices: [ChoiceSpec('period', 'Pay period', labels, labels.first)],
      submit: 'Run payroll',
      onSubmit: (v) {
        final m = months[labels.indexOf(v['period'] as String)];
        final err = app.runPayroll(m.year, m.month);
        if (err == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) msg(context, 'Payroll for ${app.monthLabel(m)} is done. Open it to see the register and payslips.');
          });
        }
        return err;
      },
    );
  }

  void _openRun(BuildContext context, PayrollRun r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.period, style: hd(22)),
            const SizedBox(height: 4),
            Text('${r.lines.length} employees · net pay ${peso(r.net)} · paid ${r.paidOn}', style: TextStyle(color: muted(ctx), fontSize: 12.5)),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const IconBadge(Icons.table_chart_outlined, accent: true),
              title: const Text('Payroll register', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Open it, or download as Word or Excel'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                go(context, DocViewer(DocItem('Payroll register ${r.period}', 'Finance', r.paidOn, live: () => payrollRegisterBlocks(r))));
              },
            ),
            const Divider(),
            Text('Payslips', style: hd(17)),
            for (final l in r.lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const IconBadge(Icons.receipt_long_outlined, accent: true),
                title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${l.role} · net ${peso(l.net)}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  go(context, DocViewer(DocItem('Payslip ${l.name} ${r.period}', 'Finance', r.paidOn, live: () => payslipBlocks(r, l))));
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final staff = app.employees;
        final gross = staff.fold<num>(0, (s, e) => s + e.salary);
        final ded = staff.fold<num>(0, (s, e) => s + e.deductions);
        final runs = app.payrollRuns;
        return SubPage(
          title: 'Payroll',
          subtitle: 'Staff list, monthly payroll, registers and payslips.',
          fab: FloatingActionButton.extended(
            backgroundColor: lav,
            foregroundColor: ink,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add employee'),
            onPressed: () => _editEmployee(context),
          ),
          children: [
            PastelCard(
              color: Pastel.mint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MONTHLY NET PAYROLL', style: TextStyle(color: inkSoft, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text(peso(gross - ded), style: hd(32, color: ink)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 28,
                    runSpacing: 8,
                    children: [
                      _stat('Employees', '${staff.length}'),
                      _stat('Gross pay', peso(gross)),
                      _stat('Deductions', peso(ded)),
                    ],
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: staff.isEmpty ? () => msg(context, 'Add at least one employee first.') : () => _run(context),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Run payroll'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => runSave(context, 'Excel file', () => exportXlsx('Payroll summary', payrollSummaryBlocks(app.payrollRuns))),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Summary (Excel)'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => runSave(context, 'Word file', () => exportDocx('Payroll summary', payrollSummaryBlocks(app.payrollRuns))),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Summary (Word)'),
                ),
              ],
            ),
            Text('Employees', style: hd(18)),
            if (staff.isEmpty)
              const EmptyBox('No employees yet. Tap Add employee to build the staff list.', icon: Icons.groups_outlined),
            for (final e in staff)
              RCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const IconBadge(Icons.badge_outlined, accent: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('${e.role} · salary ${peso(e.salary)} · deductions ${peso(e.deductions)}',
                              style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.35)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => _editEmployee(context, e), icon: const Icon(Icons.edit_outlined)),
                    IconButton(
                      onPressed: () async {
                        final ok = await confirmDialog(context, 'Remove employee?', '${e.name} will be taken off the staff list. Past payslips are kept.',
                            confirm: 'Remove', destructive: true);
                        if (ok) app.removeEmployee(e);
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            Text('Payroll runs', style: hd(18)),
            if (runs.isEmpty) const EmptyBox('No payroll run yet.', icon: Icons.payments_outlined),
            for (final r in runs)
              RCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () => _openRun(context, r),
                child: Row(
                  children: [
                    const IconBadge(Icons.event_available_outlined, accent: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.period, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('${r.lines.length} employees · paid ${r.paidOn}', style: TextStyle(color: muted(context), fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Text(peso(r.net), style: hd(16)),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _stat(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v, style: hd(17, color: ink)),
          Text(k, style: const TextStyle(color: inkSoft, fontSize: 12)),
        ],
      );
}
