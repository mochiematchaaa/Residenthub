import '../core/core.dart';

/// Demo build: `flutter build web --dart-define=DEMO=true`.
///
/// The demo is NOT connected to any database. It starts with made-up people, units, dues, bookings
/// and announcements (the same sample data as the website demo, with dates built around today).
/// Everything the visitor changes stays in memory and is gone when the page is closed.
const bool kDemo = bool.fromEnvironment('DEMO');

const String kDemoPassword = 'Demo@1234';
const String kDemoAdminEmail = 'admin@demo.test';
const String kDemoResidentEmail = 'resident@demo.test';
const String kDemoResidentUnit = 'Unit 3B';

/// Message for things that need a real server (passwords, accounts, text-message codes).
const String kDemoOff = 'This is a demo, so this is turned off.';

/// Signs in as the demo administrator or the demo resident. Returns an error message, or null.
String? demoSignIn(String emailRaw, String pass) {
  final email = emailRaw.trim().toLowerCase();
  if (email.isEmpty) return 'Enter your email.';
  if (pass.isEmpty) return 'Enter your password.';
  if (pass != kDemoPassword || (email != kDemoAdminEmail && email != kDemoResidentEmail)) {
    return 'Demo logins: $kDemoAdminEmail or $kDemoResidentEmail, password $kDemoPassword.';
  }
  startDemo(email == kDemoAdminEmail ? Role.admin : Role.resident);
  return null;
}

/// Opens the app as the demo administrator or the demo resident (Maria Reyes, Unit 3B).
void startDemo(Role role) {
  final admin = role == Role.admin;
  final unit = admin ? '' : kDemoResidentUnit;
  app.enterSession(
    role: role,
    id: admin ? 'demo-admin' : 'demo-u2',
    name: admin ? 'Demo Administrator' : 'Maria Reyes',
    email: admin ? kDemoAdminEmail : kDemoResidentEmail,
    phone: admin ? '0917 000 0000' : '0917 000 1103',
    unit: unit,
    mustChange: false,
    verified: true,
  );
  final rows = <CRow>[
    for (final r in _demoRows())
      if (admin || _residentMaySee(r, unit)) r,
  ];
  importRows(app, rows);
  if (admin) app.setAccounts(_demoAccounts());
  app.changed();
}

/// What a resident could read from the real database: public rows and their own unit's rows.
bool _residentMaySee(CRow r, String unit) {
  if (r.unit == '__admin') return false;
  if (r.unit.isEmpty) return true;
  const open = {'announcement', 'event', 'doc', 'poll', 'vendor', 'slot', 'setting', 'booking', 'rsvp', 'vote'};
  if (open.contains(r.kind)) return true;
  return r.unit == unit;
}

// ------------------------------------------------------------------ sample data

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monLong = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'
];

String _two(int n) => n < 10 ? '0$n' : '$n';
String _sd(DateTime d) => '${_mon[d.month - 1]} ${d.day}, ${d.year}';
String _dk(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
DateTime _off(int days) {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day + days, 12);
}

String _clock(int min) {
  final h = (min ~/ 60) % 24, m = min % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12${m == 0 ? '' : ':${_two(m)}'}';
}

String _ap(int min) => ((min ~/ 60) % 24) >= 12 ? 'PM' : 'AM';

/// "6–8 PM" or "10 AM–12 PM" for the i-th time of an amenity.
String _slotLabel(int open, int mins, int i) {
  final s = open + i * mins, e = s + mins;
  return _ap(s) == _ap(e)
      ? '${_clock(s)}–${_clock(e)} ${_ap(s)}'
      : '${_clock(s)} ${_ap(s)}–${_clock(e)} ${_ap(e)}';
}

List<Account> _demoAccounts() {
  final added = _sd(_off(-60));
  Account a(String id, String name, String email, String phone, String unit) =>
      Account(id, name, email, phone, unit, 'Resident', added, verified: true);
  return [
    a('demo-u0', 'Elena Santos', 'elena.santos@demo.test', '0917 000 1101', 'Unit 1A'),
    a('demo-u1', 'Paolo Dela Cruz', 'paolo.delacruz@demo.test', '0917 000 1102', 'Unit 2B'),
    a('demo-u2', 'Maria Reyes', kDemoResidentEmail, '0917 000 1103', 'Unit 3B'),
    a('demo-u3', 'Carlo Garcia', 'carlo.garcia@demo.test', '0917 000 1104', 'Unit 5A'),
    a('demo-u4', 'Liza Mendoza', 'liza.mendoza@demo.test', '0917 000 1105', 'Unit 5C'),
    a('demo-u5', 'Rico Bautista', 'rico.bautista@demo.test', '0917 000 1106', 'Unit 7C'),
    a('demo-u6', 'Joy Aquino', 'joy.aquino@demo.test', '0917 000 1107', 'Unit 8A'),
    a('demo-u7', 'Grace Lim', 'grace.lim@demo.test', '0917 000 1108', 'Unit 9B'),
  ];
}

List<CRow> _demoRows() {
  final now = DateTime.now();
  final year = now.year;
  final rows = <CRow>[];
  var seq = 0;
  int tid() => now.millisecondsSinceEpoch - 1000000 + (++seq);
  void r(String kind, Object id, String unit, Map<String, dynamic> value) => rows.add(CRow(kind, '$id', unit, value));

  // ---- units: [label, household, type, status, contact]
  const units = <List<String>>[
    ['Unit 1A', 'Santos Family', 'Owner', 'Occupied', '0917 000 1101'],
    ['Unit 2B', 'Dela Cruz Household', 'Owner', 'Occupied', '0917 000 1102'],
    ['Unit 3B', 'Reyes Household', 'Owner', 'Occupied', '0917 000 1103'],
    ['Unit 5A', 'Garcia Family', 'Tenant', 'Occupied', '0917 000 1104'],
    ['Unit 5C', 'Mendoza Household', 'Owner', 'Occupied', '0917 000 1105'],
    ['Unit 7C', 'Bautista Family', 'Owner', 'Occupied', '0917 000 1106'],
    ['Unit 8A', 'Aquino Household', 'Tenant', 'Occupied', '0917 000 1107'],
    ['Unit 9B', 'Lim Household', 'Owner', 'Occupied', '0917 000 1108'],
    ['Unit 10A', 'Tan Family', 'Owner', 'Occupied', '0917 000 1109'],
    ['Unit 11C', 'Ramos Household', 'Owner', 'Vacant', '0917 000 1110'],
    ['Unit 12A', 'Navarro Family', 'Owner', 'Occupied', '0917 000 1111'],
    ['Unit 12B', 'Cruz Household', 'Owner', 'Vacant', '0917 000 1112'],
  ];
  final byUnit = <String, Map<String, dynamic>>{};
  for (final u in units) {
    byUnit[u[0]] = <String, dynamic>{
      'unit': u[0],
      'name': u[1],
      'type': u[2],
      'status': u[3],
      'contact': u[4],
      'usage': u[2] == 'Tenant' ? 'tenant' : 'owner',
    };
  }
  byUnit['Unit 5A']!['usageStatus'] = 'approved';
  byUnit['Unit 5A']!['usageInfo'] = <String, dynamic>{
    'tname': 'Carlo Garcia',
    'tphone': '0917 000 1104',
    'occupants': '3',
    'start': _dk(_off(-200)),
    'end': _dk(_off(165)),
    'emerg': 'Ana Garcia, 0917 000 2204',
    'plates': 'ABC 1234',
    'agree': true,
  };
  byUnit['Unit 8A']!['usageStatus'] = 'pending';
  byUnit['Unit 8A']!['usageInfo'] = <String, dynamic>{
    'tname': 'Joy Aquino',
    'tphone': '0917 000 1107',
    'occupants': '2',
    'start': _dk(_off(5)),
    'end': _dk(_off(370)),
    'emerg': 'Ben Aquino, 0917 000 2207',
    'agree': true,
  };
  byUnit['Unit 9B']!['usage'] = 'shortterm';
  byUnit['Unit 9B']!['usageStatus'] = 'approved';
  byUnit['Unit 9B']!['usageInfo'] = <String, dynamic>{
    'platform': 'Airbnb',
    'contact': 'Grace Lim',
    'phone': '0917 000 1108',
    'maxGuests': '4',
    'start': _dk(_off(-120)),
    'listing': 'Cozy studio near the park',
    'agree': true,
  };
  byUnit['Unit 12A']!['usage'] = 'renovation';
  byUnit['Unit 12A']!['usageStatus'] = 'pending';
  byUnit['Unit 12A']!['usageInfo'] = <String, dynamic>{
    'work': 'New tiles in the kitchen and bathroom',
    'contractor': 'J. Villanueva Builders',
    'phone': '0917 000 3312',
    'start': _dk(_off(8)),
    'end': _dk(_off(30)),
    'agree': true,
  };
  for (final u in units) {
    r('unit', u[0], u[0], byUnit[u[0]]!);
  }

  // ---- settings
  r('setting', 'dues_rate', '', {'rate': 2500});
  r('setting', 'motor_rate', '', {'rate': 1500});
  r('setting', 'motor_rate_daily', '', {'rate': 100});
  r('setting', 'paymethods', '', {
    'list': [
      {'name': 'Cash or check at the office', 'details': 'Pay at the administration office, Monday to Saturday, 8 AM to 5 PM.', 'enabled': true},
      {'name': 'Bank transfer', 'details': 'Account name: City Residences Condominium Corp. (sample)\nBank: Sample Bank\nAccount no.: 0000-0000-00', 'enabled': true},
      {'name': 'GCash', 'details': 'Account name: City Residences (sample)\nNumber: 0917 000 0000', 'enabled': true},
    ],
  });
  const amenities = <Map<String, dynamic>>[
    {'id': 'pool', 'name': 'Swimming Pool', 'open': '06:00', 'close': '20:00', 'mins': 120, 'note': 'Free for residents. Guests pay ₱150 per visit, collected at the gate.'},
    {'id': 'hall', 'name': 'Function Hall', 'open': '08:00', 'close': '22:00', 'mins': 120, 'note': 'Good for up to 60 guests. Clean the hall after use.'},
    {'id': 'gym', 'name': 'Gym', 'open': '06:00', 'close': '22:00', 'mins': 120, 'note': 'Bring a towel and wipe the equipment after use.'},
    {'id': 'game', 'name': 'Game Room', 'open': '10:00', 'close': '22:00', 'mins': 120, 'note': 'Billiards, table tennis and board games.'},
  ];
  r('setting', 'amenities', '', {'list': amenities});
  r('setting', 'directory', '', {
    'contacts': [
      {'name': 'Security desk', 'note': 'Open 24 hours', 'tel': 'Local 101'},
      {'name': 'Administration office', 'note': 'Mon to Sat, 8 AM to 5 PM', 'tel': 'Local 110'},
      {'name': 'Building engineer', 'note': 'Repairs and maintenance', 'tel': 'Local 120'},
      {'name': 'Emergency hotline', 'note': 'Fire, medical, police', 'tel': '911'},
    ],
    'rules': [
      ['Quiet hours', 'Please keep noise down from 10 PM to 6 AM.'],
      ['Garbage', 'Bag your garbage and put it in the chute room on your floor. No bulky items.'],
      ['Visitors', 'Visitors must register at the lobby and leave a valid ID.'],
      ['Pets', 'Pets must be on a leash in the common areas.'],
    ],
  });

  // ---- dues and payments: two months paid, this month open (a few units already paid this month)
  final houses = units.where((u) => u[3] == 'Occupied').toList();
  const paidThisMonth = ['Unit 1A', 'Unit 2B', 'Unit 5C', 'Unit 9B', 'Unit 10A'];
  var receipt = 0;
  for (var hi = 0; hi < houses.length; hi++) {
    final u = houses[hi];
    for (final off in [-2, -1, 0]) {
      final dd = DateTime(now.year, now.month + off, 25, 12);
      final note = 'Association dues - ${_monLong[dd.month - 1]} ${dd.year}';
      final idn = DateTime(dd.year, dd.month, 1, 9).millisecondsSinceEpoch + hi;
      final paid = (off < 0 && !(u[0] == 'Unit 5A' && off == -1)) || (off == 0 && paidThisMonth.contains(u[0]));
      r('due', idn, u[0], {
        'id': idn,
        'unit': u[0],
        'name': u[1],
        'amount': 2500,
        'note': note,
        'dueDate': _sd(dd),
        if (paid) 'paid': true,
      });
      if (paid) {
        var pd = DateTime(dd.year, dd.month, 8 + (hi * 2) % 15, 12);
        if (pd.isAfter(now)) {
          pd = DateTime(now.year, now.month, now.day - hi > 0 ? now.day - hi : 1, 12);
        }
        receipt++;
        final no = 'OR-$year-${receipt.toString().padLeft(4, '0')}';
        final method = const ['Cash or check at the office', 'GCash', 'Bank transfer'][(hi + off + 2) % 3];
        final ref = method == 'Cash or check at the office' ? '—' : 'REF${700000 + receipt * 37}';
        r('payment', idn + 5, u[0], {
          'id': idn + 5,
          'receiptNo': no,
          'unit': u[0],
          'payer': u[1],
          'forText': note,
          'method': method,
          'reference': ref,
          'date': _sd(pd),
          'amount': 2500,
        });
        r('proof', idn + 7, u[0], {
          'id': idn + 7,
          'unit': u[0],
          'payer': u[1],
          'forText': note,
          'method': method,
          'reference': ref,
          'amount': 2500,
          'date': _sd(pd),
          'status': 'Confirmed',
          'receiptNo': no,
          'confirmedOn': _sd(pd),
        });
      }
    }
  }
  final sid = tid();
  r('due', sid, 'Unit 3B', {
    'id': sid,
    'unit': 'Unit 3B',
    'name': 'Reyes Household',
    'amount': 800,
    'note': 'Special assessment - elevator repair',
    'dueDate': _sd(_off(9)),
  });
  final thisMonth = DateTime(now.year, now.month, 25, 12);
  final note12 = 'Association dues - ${_monLong[thisMonth.month - 1]} ${thisMonth.year}';
  final p12 = tid();
  r('proof', p12, 'Unit 12A', {
    'id': p12,
    'unit': 'Unit 12A',
    'payer': 'Navarro Family',
    'forText': note12,
    'method': 'GCash',
    'reference': 'GC${year * 1000000 + 101401}',
    'amount': 2500,
    'date': _sd(_off(-1)),
    'status': 'Pending',
  });

  // ---- expenses (administrator only)
  const exp = <List<Object>>[
    ['Security guards - monthly contract', 'Security services', 'Whole building', 'SafeGuard Agency (sample)', 1, 38000, -3],
    ['Common-area electricity', 'Common-area utilities', 'Lobby and common areas', 'Sample Power Co.', 1, 21450.5, -5],
    ['Water bill (common areas and pool)', 'Common-area utilities', 'Swimming pool', 'Sample Water District', 1, 8920, -6],
    ['Janitorial supplies', 'Janitorial and maintenance', 'Whole building', 'CleanPro Supplies', 12, 310, -9],
    ['Elevator B servicing', 'Repairs and improvements', 'Elevators', 'LiftCare Services', 1, 15500, -14],
    ['Light bulbs for hallways', 'Supplies and equipment', 'Lobby and common areas', 'Hardware Depot', 24, 85.5, -18],
    ['Pool chemicals', 'Supplies and equipment', 'Swimming pool', 'AquaPure Trading', 6, 640, -25],
    ['Building insurance (quarterly)', 'Insurance', 'Whole building', 'Sample Insurance', 1, 27500, -33],
    ['Security guards - monthly contract', 'Security services', 'Whole building', 'SafeGuard Agency (sample)', 1, 38000, -33],
    ['Parking lot repainting', 'Repairs and improvements', 'Parking', 'ColorWorks Painting', 1, 12400, -47],
    ['Reserve fund deposit', 'Administration and reserve fund', 'Whole building', 'Bank deposit', 1, 20000, -62],
  ];
  for (var i = 0; i < exp.length; i++) {
    final e = exp[i];
    final id = tid();
    r('expense', id, '__admin', {
      'id': id,
      'item': e[0],
      'category': e[1],
      'area': e[2],
      'payee': e[3],
      'receiptNo': 'R-${4100 + i * 7}',
      'qty': e[4],
      'unitPrice': e[5],
      'date': _dk(_off(e[6] as int)),
    });
  }

  // ---- announcements, events, polls
  void ann(String title, String body, String type, int off, [String status = 'Published']) {
    final id = tid();
    r('announcement', id, '', {'id': id, 'title': title, 'body': body, 'date': _sd(_off(off)), 'status': status, 'type': type});
  }

  ann('Water interruption this Saturday', 'The water supply will be shut off from 9 AM to 3 PM for the cleaning of the water tank. Please store enough water.', 'Maintenance', -1);
  ann('Elevator B maintenance', 'Elevator B will be out of service next Tuesday from 8 AM to 12 NN. Please use Elevator A.', 'Maintenance', -3);
  ann('Reminder: dues are due on the 25th', 'Association dues are due every 25th of the month. Pay online in the Dues page or at the office.', 'General', -4);
  ann('Fire drill next week', "A building-wide fire drill will be held next Thursday at 2 PM. Please follow the guards' instructions.", 'Warning', -6);
  ann('Halloween trick-or-treat in the lobby', 'Kids are welcome to trick-or-treat on October 31 from 4 to 6 PM. Costumes encouraged!', 'General', -8);
  ann('Year-end party planning', 'Draft: we are collecting ideas for the year-end party. Details to follow.', 'General', -1, 'Draft');

  int evt(String title, int off, String time, String place, String about) {
    final id = tid();
    r('event', id, '', {'id': id, 'title': title, 'date': '${_sd(_off(off))} · $time', 'place': place, 'about': about});
    return id;
  }

  final e1 = evt('Community clean-up drive', 8, '7:00 AM', 'Lobby', 'Bring gloves and a reusable bag. Snacks provided.');
  final e2 = evt('Kids Halloween party', 15, '4:00 PM', 'Function Hall', 'Games, costumes and treats for the kids of the building.');
  evt('Quarterly general assembly', 25, '6:00 PM', 'Function Hall', 'Updates on the budget and the lobby repainting.');
  for (final x in [
    ['Unit 1A', e1],
    ['Unit 3B', e2],
    ['Unit 5C', e1],
    ['Unit 7C', e2],
    ['Unit 9B', e2],
    ['Unit 3B', e1],
  ]) {
    r('rsvp', '${x[0]}|${x[1]}', x[0] as String, {'event': x[1]});
  }
  final p1 = tid(), p2 = tid();
  r('poll', p1, '', {
    'id': p1,
    'question': 'Should the lobby be repainted this year?',
    'open': true,
    'closes': _sd(_off(6)),
    'options': ['Yes, with a new color', 'Yes, same color', 'No, not needed'],
  });
  r('poll', p2, '', {
    'id': p2,
    'question': 'Best day for the quarterly general assembly?',
    'open': false,
    'closes': _sd(_off(-12)),
    'options': ['Saturday morning', 'Saturday evening', 'Sunday afternoon'],
  });
  for (final x in [['Unit 1A', 0], ['Unit 2B', 1], ['Unit 5A', 0], ['Unit 5C', 0], ['Unit 7C', 2], ['Unit 9B', 1]]) {
    r('vote', '${x[0]}|$p1', x[0] as String, {'poll': p1, 'option': x[1]});
  }
  for (final x in [['Unit 1A', 1], ['Unit 2B', 1], ['Unit 3B', 0], ['Unit 5C', 1], ['Unit 7C', 2], ['Unit 8A', 1], ['Unit 9B', 0]]) {
    r('vote', '${x[0]}|$p2', x[0] as String, {'poll': p2, 'option': x[1]});
  }

  // ---- bookings: [unit, amenity index, time index, day offset, status]
  const bookings = <List<Object>>[
    ['Unit 3B', 0, 2, 6, 'Approved'],
    ['Unit 3B', 1, 0, 3, 'Pending'],
    ['Unit 1A', 0, 0, 7, 'Approved'],
    ['Unit 2B', 0, 1, 2, 'Pending'],
    ['Unit 5C', 1, 4, 0, 'Approved'],
    ['Unit 7C', 2, 1, 3, 'Pending'],
    ['Unit 9B', 0, 3, 1, 'Denied'],
    ['Unit 10A', 3, 2, 4, 'Approved'],
    ['Unit 1A', 0, 0, -3, 'Approved'],
    ['Unit 5A', 2, 1, -2, 'Approved'],
    ['Unit 3B', 0, 4, -6, 'Approved'],
    ['Unit 7C', 3, 3, 5, 'Pending'],
    ['Unit 2B', 2, 5, 9, 'Approved'],
    ['Unit 8A', 0, 3, 12, 'Pending'],
  ];
  int toMin(String t) {
    final p = t.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  for (final b in bookings) {
    final a = amenities[b[1] as int];
    final d = _off(b[3] as int);
    final id = tid();
    final unit = b[0] as String;
    r('booking', id, unit, {
      'id': id,
      'who': byUnit[unit]!['name'],
      'unit': unit,
      'place': a['name'],
      'when': '${_sd(d)}, ${_slotLabel(toMin(a['open'] as String), a['mins'] as int, b[2] as int)}',
      'status': b[4],
      'day': _dk(d),
      'slot': b[2],
    });
  }

  // ---- grievances: stage 0 open, 1 in progress, 2 resolved
  const griev = <List<Object>>[
    ['Unit 3B', 'Leaking pipe in the 3rd floor hallway', 'Water drips from the ceiling near the elevator.', 1],
    ['Unit 3B', 'Broken hallway light', 'The light outside Unit 3B keeps flickering.', 2],
    ['Unit 5C', 'Noise from a late-night gathering', 'Loud music past midnight on the weekend.', 0],
    ['Unit 7C', 'Parking gate sensor not working', 'The gate sometimes does not open for residents.', 1],
    ['Unit 9B', 'Treadmill in the gym is broken', 'The second treadmill stops after a few minutes.', 0],
  ];
  for (var i = 0; i < griev.length; i++) {
    final g = griev[i];
    final id = tid() - i * 86400000;
    r('grievance', id, g[0] as String, {'id': id, 'title': g[1], 'body': g[2], 'by': g[0], 'stage': g[3]});
  }

  // ---- motor parking
  const rented = ['M-02', 'M-04', 'M-08'];
  for (var i = 1; i <= 12; i++) {
    final id = 'M-${_two(i)}';
    if (!rented.contains(id)) r('slot', id, '', {'id': id});
  }
  void rent(String id, String unit, String plan, int off, int days, int amount) {
    r('slot', id, '', {'id': id, 'unit': unit, 'plan': plan, 'from': _dk(_off(off)), 'until': _dk(_off(off + days - 1)), 'amount': amount});
  }

  rent('M-02', 'Unit 1A', 'month', -10, 30, 1500);
  rent('M-04', 'Unit 9B', 'day', -1, 4, 400);
  rent('M-08', 'Unit 2B', 'month', -20, 30, 1500);
  r('request', 'Unit 7C', 'Unit 7C', {
    'unit': 'Unit 7C',
    'who': 'Bautista Family',
    'when': '1 hour ago',
    'at': now.millisecondsSinceEpoch - 3600000,
    'slot': 'M-05',
    'plan': 'month',
    'days': 1,
    'amount': 1500,
    'confirmed': false,
  });
  final rp = tid();
  r('proof', rp, 'Unit 7C', {
    'id': rp,
    'unit': 'Unit 7C',
    'payer': 'Bautista Family',
    'forText': 'Motor parking rental',
    'method': 'GCash',
    'reference': 'GC${year * 1000000 + 101403}',
    'amount': 1500,
    'date': _sd(now),
    'status': 'Pending',
    'slot': 'M-05',
  });

  // ---- documents (readable inside the app)
  void doc(String name, String cat, String aud, List<Map<String, dynamic>> blocks, int off) {
    final id = tid();
    r('doc', id, aud == 'admin' ? '__admin' : '', {
      'id': id,
      'name': name,
      'cat': cat,
      'date': _sd(_off(off)),
      'audience': aud,
      'ext': '',
      'blocks': blocks,
    });
  }

  doc('House Rules and Regulations', 'Policy', 'all', [
    {'k': 'h1', 't': 'House Rules and Regulations (sample)'},
    {'k': 'h2', 't': '1. Quiet hours'},
    {'k': 'p', 't': 'Keep noise down from 10 PM to 6 AM.'},
    {'k': 'h2', 't': '2. Common areas'},
    {'k': 'bullet', 't': 'Do not leave belongings in the hallways.'},
    {'k': 'bullet', 't': 'Clean the amenity after you use it.'},
  ], -60);
  doc('Financial statement (sample)', 'Finance', 'all', [
    {'k': 'h1', 't': 'Statement of collections and expenses (sample numbers)'},
    {
      'k': 'table',
      'r': [
        ['Item', 'Amount'],
        ['Dues collected', '₱ 240,000'],
        ['Operating expenses', '₱ 168,000'],
        ['Reserve fund', '₱ 72,000'],
      ],
    },
  ], -20);
  doc('Move-in and move-out form', 'Form', 'all', [
    {'k': 'h1', 't': 'Move-in / move-out form (sample)'},
    {'k': 'p', 't': 'Fill this in and submit it to the office three days before moving.'},
  ], -90);
  doc('Minutes of the last general assembly', 'Minutes', 'all', [
    {'k': 'h1', 't': 'Minutes (sample)'},
    {'k': 'bullet', 't': 'The budget was approved.'},
    {'k': 'bullet', 't': 'The lobby repainting will be put to a vote.'},
  ], -45);
  doc('Board notes (admin only)', 'Other', 'admin', [
    {'k': 'h1', 't': 'Board notes (sample)'},
    {'k': 'p', 't': 'Only the administrator can see this document.'},
  ], -5);

  // ---- activity log (administrator)
  const acts = <List<Object>>[
    ['Payment recorded, Unit 1A', 'Finance', 0.2],
    ['Booking approved, Unit 1A', 'Facilities', 0.4],
    ['Announcement published: Water interruption this Saturday', 'Announcements', 1.1],
    ['Expense added: Security guards - monthly contract', 'Expenses', 2.2],
    ['Grievance in progress: Leaking pipe in the 3rd floor hallway', 'Requests', 2.6],
    ['Unit usage declaration received, Unit 8A', 'Units', 3.0],
    ['Event added: Community clean-up drive', 'Events', 3.4],
    ['Poll created: Should the lobby be repainted this year?', 'Polls', 4.1],
    ['Charge posted to every occupied unit: October dues', 'Finance', 5.2],
    ['Parking rented: M-02 to Unit 1A', 'Parking', 6.3],
    ['Amenity updated: Gym', 'Facilities', 7.2],
    ['Account created for Unit 9B', 'Access', 9.5],
  ];
  for (final a in acts) {
    final at = now.millisecondsSinceEpoch - ((a[2] as double) * 86400000).round();
    r('activity', at, '__admin', {'title': a[0], 'area': a[1], 'at': at});
  }
  return rows;
}
