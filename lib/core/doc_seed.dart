import 'app_state.dart';
import 'doc_model.dart';
import 'expenses.dart';
import 'payments.dart';

String _n(int v) => peso(v);

/// Documents that ship with the app. Replace the wording with the association's real text.
List<DocItem> seedDocs() => [
      DocItem(
        'House Rules and Regulations',
        'Policy',
        'Updated Sep 1',
        blocks: const [
          DocBlock.h1('House Rules and Regulations'),
          DocBlock.p('City Residences Condominium Corporation. These rules apply to all unit owners, tenants, household members and guests.'),
          DocBlock.h2('1. Quiet hours'),
          DocBlock.bullet('Quiet hours are 10:00 PM to 6:00 AM every day.'),
          DocBlock.bullet('Renovation and drilling work is allowed Monday to Saturday, 8:00 AM to 5:00 PM only.'),
          DocBlock.bullet('Parties and gatherings in a unit must not disturb neighbours.'),
          DocBlock.h2('2. Common areas'),
          DocBlock.bullet('Keep hallways, stairwells and fire exits clear at all times.'),
          DocBlock.bullet('Dispose of garbage only in the designated bins and during collection hours.'),
          DocBlock.bullet('Smoking is not allowed in enclosed common areas.'),
          DocBlock.h2('3. Pets'),
          DocBlock.bullet('Pets must be leashed in common areas and their waste cleaned up immediately.'),
          DocBlock.bullet('Pets are not allowed inside the pool, gym or function hall.'),
          DocBlock.h2('4. Parking'),
          DocBlock.bullet('Park only in your assigned slot. Visitor parking is first come, first served.'),
          DocBlock.bullet('Motor parking is a monthly rental; request a slot through the app.'),
          DocBlock.h2('5. Move-in, move-out and deliveries'),
          DocBlock.bullet('Notify the administration office at least 2 working days before moving in or out.'),
          DocBlock.bullet('Use the service elevator for furniture and bulky items.'),
          DocBlock.h2('6. Violations'),
          DocBlock.p('Residents who breach these rules receive a written reminder. Repeated violations are referred to the Board, which may impose the penalties allowed by the association by-laws.'),
        ],
      ),
      DocItem(
        '2026 Association Dues Schedule',
        'Finance',
        'Updated Aug 15',
        live: duesSchedule,
      ),
      DocItem(
        'Annual Budget 2026',
        'Finance',
        'Updated Aug 15',
        blocks: [
          const DocBlock.h1('Annual Budget 2026'),
          const DocBlock.p('Approved by the Board of Directors. Figures are in Philippine pesos.'),
          DocBlock.table([
            const ['Category', 'Annual budget', 'Share'],
            for (final r in const [
              ['Security services', 960000],
              ['Common-area utilities', 540000],
              ['Janitorial and maintenance', 420000],
              ['Repairs and improvements', 300000],
              ['Insurance', 120000],
              ['Administration and reserve fund', 180000],
            ])
              [r[0] as String, _n(r[1] as int), '${((r[1] as int) / 2520000 * 100).round()}%'],
            ['Total', _n(2520000), '100%'],
          ]),
          const DocBlock.p('Any spending above the approved amount for a category needs Board approval and is reported at the next general assembly.'),
        ],
      ),
      DocItem(
        'Collection Report',
        'Finance',
        'Live report',
        audience: 'admin',
        live: collectionReport,
      ),
      DocItem(
        'My Statement of Account',
        'Finance',
        'Live statement',
        audience: 'resident',
        live: statementOfAccount,
      ),
      DocItem(
        'Payment History (all units)',
        'Finance',
        'Live record',
        audience: 'admin',
        live: () => paymentHistoryBlocks('Payment history', app.payments),
      ),
      DocItem(
        'My Payment History',
        'Finance',
        'Live record',
        audience: 'resident',
        live: () => paymentHistoryBlocks('Payment history ${app.myUnit}', app.myPayments),
      ),
      DocItem(
        'Monthly Expense Report',
        'Finance',
        'Live report',
        audience: 'admin',
        live: () {
          final n = DateTime.now();
          return monthlyExpenseBlocks(app.expenses, DateTime(n.year, n.month, 1), app.collectedThisMonth);
        },
      ),
      DocItem(
        'Expense Report',
        'Finance',
        'Live report',
        audience: 'admin',
        live: () => expenseReportBlocks(app.expenses, app.totalCollected),
      ),
      DocItem(
        'Facility Reservation Form',
        'Form',
        'Updated Jul 20',
        blocks: const [
          DocBlock.h1('Facility Reservation Form'),
          DocBlock.p('Reservations are made in the app (Book tab). Use this form if you need to reserve in person at the administration office.'),
          DocBlock.table([
            ['Field', 'Details'],
            ['Resident name', ''],
            ['Unit number', ''],
            ['Contact number', ''],
            ['Facility (Function Hall / Swimming Pool / Gym)', ''],
            ['Date', ''],
            ['Time from / to', ''],
            ['Number of guests', ''],
          ]),
          DocBlock.h2('Conditions'),
          DocBlock.bullet('The unit must have no overdue dues to reserve a facility.'),
          DocBlock.bullet('Requests are approved by the administrator; you will be notified in the app.'),
          DocBlock.bullet('Leave the facility clean. Damages are charged to the reserving unit.'),
          DocBlock.bullet('Cancel at least 24 hours ahead so another resident can use the slot.'),
        ],
      ),
      DocItem(
        'Fire Safety Advisory',
        'Notice',
        'Sep 10',
        blocks: const [
          DocBlock.h1('Fire Safety Advisory'),
          DocBlock.p('The building fire drill and equipment inspection are scheduled this month. Please review the reminders below.'),
          DocBlock.h2('Before an emergency'),
          DocBlock.bullet('Know the two nearest exits from your unit and floor.'),
          DocBlock.bullet('Never store items in stairwells or block fire doors.'),
          DocBlock.bullet('Keep a small fire extinguisher and a flashlight in your unit.'),
          DocBlock.h2('During a fire'),
          DocBlock.bullet('Activate the nearest alarm and call the front desk or emergency services.'),
          DocBlock.bullet('Use the stairs, never the elevators.'),
          DocBlock.bullet('Stay low if there is smoke and close doors behind you.'),
          DocBlock.h2('Emergency contacts'),
          DocBlock.table([
            ['Contact', 'Number'],
            ['Front desk / security', 'Local 100'],
            ['Administration office', 'Local 101'],
            ['Fire and emergency services', '911'],
          ]),
        ],
      ),
      DocItem(
        'Board Meeting Minutes, August',
        'Minutes',
        'Aug 30',
        blocks: const [
          DocBlock.h1('Board Meeting Minutes - August'),
          DocBlock.p('Held at the Function Hall, 6:00 PM. Quorum was present.'),
          DocBlock.h2('Agenda'),
          DocBlock.bullet('Approval of the previous minutes'),
          DocBlock.bullet('Financial report and dues collection'),
          DocBlock.bullet('Facility maintenance and the elevator inspection'),
          DocBlock.bullet('Upcoming events: community clean-up drive and general assembly'),
          DocBlock.h2('Resolutions'),
          DocBlock.table([
            ['No.', 'Resolution', 'Status'],
            ['1', 'Minutes of the July meeting approved.', 'Approved'],
            ['2', 'Elevator B inspection to be scheduled in October.', 'Approved'],
            ['3', 'Send payment reminders to units with overdue dues.', 'Approved'],
            ['4', 'General assembly set for October 18.', 'Approved'],
          ]),
          DocBlock.p('The meeting adjourned at 8:15 PM. Minutes recorded by the association secretary.'),
        ],
      ),
    ];

/// Live: every unit's dues status, rebuilt each time it is opened.
List<DocBlock> collectionReport() {
  final dues = app.dues;
  final paid = dues.where((d) => d.paid).fold<int>(0, (s, d) => s + d.amt);
  final unpaid = dues.where((d) => !d.paid).fold<int>(0, (s, d) => s + d.amt);
  return [
    const DocBlock.h1('Dues collection report'),
    DocBlock.p('As of ${longDate(DateTime.now())}.'),
    DocBlock.table([
      const ['Unit', 'Household', 'Months overdue', 'Amount', 'Status'],
      for (final d in dues) [d.unit, d.name, d.isCharge ? d.note : '${d.months}', peso(d.amt), d.paid ? 'Paid' : 'Unpaid'],
    ]),
    const DocBlock.h2('Summary'),
    DocBlock.table([
      const ['Item', 'Amount'],
      ['Recorded as paid', peso(paid)],
      ['Still outstanding', peso(unpaid)],
      ['Total on this report', peso(paid + unpaid)],
    ]),
    DocBlock.p('${dues.where((d) => !d.paid).length} of ${dues.length} units still have an open balance.'),
  ];
}

/// Live: the signed-in resident's own dues.
List<DocBlock> statementOfAccount() {
  final rows = app.myDueRows;
  return [
    const DocBlock.h1('Statement of account'),
    DocBlock.p('${app.myUnit} - ${app.myHousehold}'),
    DocBlock.p('As of ${longDate(DateTime.now())}.'),
    DocBlock.table([
      const ['Month', 'Due date', 'Amount', 'Status'],
      for (final r in rows) [r.month, r.due, peso(r.amt), r.status],
    ]),
    DocBlock.p('Balance due: ${peso(app.myBalance)}'),
  ];
}

/// Built when opened (not at start-up) because it quotes the current motor parking rate.
List<DocBlock> duesSchedule() => [
          const DocBlock.h1('2026 Association Dues Schedule'),
          const DocBlock.p('Monthly association dues are collected from every unit to fund security, utilities for common areas, maintenance and the reserve fund.'),
          const DocBlock.h2('Rates'),
          DocBlock.table([
            const ['Item', 'Rate', 'Due date'],
            ['Monthly association dues (per unit)', _n(450), '15th of each month'],
            ['Motor parking rental (per slot)', peso(app.motorRate), '15th of each month'],
          ]),
          const DocBlock.h2('Monthly calendar'),
          DocBlock.table([
            const ['Month', 'Amount', 'Due date'],
            for (final m in const [
              'January', 'February', 'March', 'April', 'May', 'June', 'July',
              'August', 'September', 'October', 'November', 'December'
            ])
              [m, _n(450), '$m 15, 2026'],
          ]),
          const DocBlock.h2('How to pay'),
          const DocBlock.bullet('Pay at the administration office, by bank transfer, GCash or Maya. The account details are under Dues & payment in the app.'),
          const DocBlock.bullet('After paying online, send your reference number under Dues & payment. The administrator records it and you can download the receipt as Word or Excel.'),
          const DocBlock.bullet('Units with overdue balances receive reminders; unresolved balances are referred to the Board.'),
        ];
