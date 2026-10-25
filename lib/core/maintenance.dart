// DEMO ONLY: maintenance management (preventive schedule, equipment list, maintenance staff, repair assignment).
//
// Nothing here is saved to the database. The screens that use it are only shown in the demo build
// (`--dart-define=DEMO=true`), and the data lives in memory until the page is closed.

import 'package:flutter/foundation.dart';

import 'app_state.dart';

/// A person who does maintenance work.
class StaffMember {
  final int id;
  String name, role, phone;
  StaffMember(this.id, this.name, this.role, this.phone);
}

/// A piece of equipment of the building.
class Equipment {
  final int id;
  String name, category, location, status; // status: Working, Needs repair, Under maintenance
  DateTime? lastService;
  Equipment(this.id, this.name, this.category, this.location, this.status, this.lastService);
}

/// A routine job that repeats, such as 'Generator test run' every 2 weeks.
class MTask {
  final int id;
  String title, every;
  int days;
  int? equipId;
  String equipLabel; // shown when the task has no equipment record (for example the water tank)
  DateTime due;
  int? staffId;
  DateTime? lastDone;
  MTask(this.id, this.title, this.every, this.days, this.due,
      {this.equipId, this.equipLabel = '', this.staffId, this.lastDone});
}

/// Who repairs a grievance, by when, and what for.
class Assignment {
  int? staffId;
  DateTime? target;
  int? equipId;
  String notes;
  Assignment({this.staffId, this.target, this.equipId, this.notes = ''});
}

const List<(String, int)> maintFrequencies = [
  ('Weekly', 7),
  ('Every 2 weeks', 14),
  ('Monthly', 30),
  ('Every 3 months', 90),
  ('Every 6 months', 180),
  ('Yearly', 365),
];
const List<String> equipmentStatuses = ['Working', 'Needs repair', 'Under maintenance'];
const List<String> equipmentCategories = [
  'Elevator', 'Plumbing', 'Electrical', 'Fire safety', 'Pool', 'Gym', 'Air conditioning', 'Security', 'Other'
];

DateTime _today() {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day, 12);
}

/// Whole days from today to [d] (negative when [d] is in the past).
int daysFromToday(DateTime d) =>
    DateTime(d.year, d.month, d.day, 12).difference(_today()).inDays;

DateTime inDays(int n) => DateTime(_today().year, _today().month, _today().day + n, 12);

String _plural(int n, String w) => '$n $w${n == 1 ? '' : 's'}';

/// The words for the due date of a task, and how serious it is: 0 fine, 1 soon, 2 overdue.
(String, int) taskState(MTask t) {
  final n = daysFromToday(t.due);
  if (n < 0) return ('Overdue by ${_plural(-n, 'day')}', 2);
  if (n == 0) return ('Due today', 1);
  if (n <= 7) return ('Due in ${_plural(n, 'day')}', 1);
  return ('Scheduled', 0);
}

/// Holds the maintenance data of the demo. Use the single [maint] object.
class MaintenanceState extends ChangeNotifier {
  final List<StaffMember> staff = [];
  final List<Equipment> equipment = [];
  final List<MTask> tasks = [];
  final Map<int, Assignment> repairs = {}; // grievance id -> assignment
  int _seq = 1000;
  int _next() => ++_seq;

  void clear() {
    staff.clear();
    equipment.clear();
    tasks.clear();
    repairs.clear();
    notifyListeners();
  }

  void changed() => notifyListeners();

  // ---- lookups
  StaffMember? staffById(int? id) {
    for (final s in staff) {
      if (s.id == id) return s;
    }
    return null;
  }

  Equipment? equipById(int? id) {
    for (final e in equipment) {
      if (e.id == id) return e;
    }
    return null;
  }

  StaffMember? staffByName(String name) {
    for (final s in staff) {
      if (s.name == name) return s;
    }
    return null;
  }

  Equipment? equipByName(String name) {
    for (final e in equipment) {
      if (e.name == name) return e;
    }
    return null;
  }

  /// The name of the staff member on a task.
  String assigneeOf(MTask t) => staffById(t.staffId)?.name ?? '';

  /// The equipment name shown for a task.
  String equipOf(MTask t) => equipById(t.equipId)?.name ?? t.equipLabel;

  /// Tasks, soonest first.
  List<MTask> get sortedTasks => [...tasks]..sort((a, b) => a.due.compareTo(b.due));

  int get overdueCount => tasks.where((t) => daysFromToday(t.due) < 0).length;
  int get dueThisWeekCount => tasks.where((t) {
        final n = daysFromToday(t.due);
        return n >= 0 && n <= 7;
      }).length;
  int get equipmentToFix => equipment.where((e) => e.status != 'Working').length;

  /// Open (not resolved) grievances that point to a piece of equipment.
  int openRepairsFor(AppState app, int equipId) => app.grievances
      .where((g) => g.stage < 2 && repairs[g.id]?.equipId == equipId)
      .length;

  // ---- tasks
  void markDone(MTask t, AppState app) {
    final now = _today();
    t.lastDone = now;
    t.due = DateTime(now.year, now.month, now.day + t.days, 12);
    final e = equipById(t.equipId);
    if (e != null) e.lastService = now;
    app.logActivity('Maintenance done: ${t.title}', 'Maintenance');
    notifyListeners();
  }

  void saveTask(AppState app,
      {MTask? existing, required String title, required String every, required DateTime? due, required Equipment? equip, required StaffMember? who}) {
    final days = maintFrequencies.firstWhere((f) => f.$1 == every, orElse: () => maintFrequencies[2]).$2;
    if (existing == null) {
      tasks.add(MTask(_next(), title, every, days, due ?? _today(), equipId: equip?.id, staffId: who?.id));
      app.logActivity('Maintenance task added: $title', 'Maintenance');
    } else {
      existing
        ..title = title
        ..every = every
        ..days = days
        ..equipId = equip?.id
        ..staffId = who?.id;
      if (equip != null) existing.equipLabel = '';
      if (due != null) existing.due = due;
      app.logActivity('Maintenance task updated: $title', 'Maintenance');
    }
    notifyListeners();
  }

  void deleteTask(MTask t, AppState app) {
    tasks.remove(t);
    app.logActivity('Deleted task: ${t.title}', 'Maintenance');
    notifyListeners();
  }

  // ---- equipment
  void saveEquipment(AppState app,
      {Equipment? existing, required String name, required String category, required String location, required String status}) {
    if (existing == null) {
      equipment.add(Equipment(_next(), name, category, location, status, null));
      app.logActivity('Equipment added: $name', 'Maintenance');
    } else {
      existing
        ..name = name
        ..category = category
        ..location = location
        ..status = status;
      app.logActivity('Equipment updated: $name', 'Maintenance');
    }
    notifyListeners();
  }

  /// Returns a message if the equipment cannot be deleted yet, otherwise deletes it and returns null.
  String? deleteEquipment(Equipment e, AppState app) {
    final linked = tasks.where((t) => t.equipId == e.id).length + openRepairsFor(app, e.id);
    if (linked > 0) return '${e.name} is still used by ${_plural(linked, 'linked item')}. Remove or finish those first.';
    equipment.remove(e);
    app.logActivity('Deleted equipment: ${e.name}', 'Maintenance');
    notifyListeners();
    return null;
  }

  // ---- staff
  void saveStaff(AppState app, {StaffMember? existing, required String name, required String role, required String phone}) {
    if (existing == null) {
      staff.add(StaffMember(_next(), name, role.isEmpty ? 'Maintenance' : role, phone));
      app.logActivity('Staff added: $name', 'Maintenance');
    } else {
      existing
        ..name = name
        ..role = role.isEmpty ? 'Maintenance' : role
        ..phone = phone;
      app.logActivity('Staff updated: $name', 'Maintenance');
    }
    notifyListeners();
  }

  int openWorkOf(StaffMember s, AppState app) =>
      app.grievances.where((g) => g.stage < 2 && repairs[g.id]?.staffId == s.id).length +
      tasks.where((t) => t.staffId == s.id).length;

  String? deleteStaff(StaffMember s, AppState app) {
    final n = openWorkOf(s, app);
    if (n > 0) return '${s.name} still has ${_plural(n, 'assignment')}. Reassign them first.';
    staff.remove(s);
    app.logActivity('Deleted staff: ${s.name}', 'Maintenance');
    notifyListeners();
    return null;
  }

  // ---- repair assignment on grievances
  void assign(AppState app, Grievance g,
      {required StaffMember? who, required DateTime? target, required Equipment? equip, required String notes}) {
    final a = repairs[g.id] ?? Assignment();
    if (who != null) {
      a.staffId = who.id;
      if (target != null) a.target = target;
      a.target ??= inDays(3);
      if (g.stage < 1) g.stage = 1;
    } else {
      a.staffId = null;
      a.target = null;
    }
    a.equipId = equip?.id;
    a.notes = notes;
    repairs[g.id] = a;
    if (who != null && equip != null && equip.status == 'Working') equip.status = 'Under maintenance';
    app.logActivity(
        who != null ? 'Repair assigned to ${who.name}: ${g.title}' : 'Repair unassigned: ${g.title}', 'Requests');
    notifyListeners();
  }

  /// Call after a grievance was moved to its next stage. A resolved repair puts its equipment back to Working.
  void afterAdvance(Grievance g) {
    if (g.stage < 2) return;
    final e = equipById(repairs[g.id]?.equipId);
    if (e != null) {
      e.status = 'Working';
      e.lastService = _today();
    }
    notifyListeners();
  }

  /// Fills the demo with sample staff, equipment, tasks and repair assignments.
  /// Residents only see the schedule and the assignments on their own grievances (the screens enforce that).
  void seedDemo(AppState app) {
    clear();
    final s = <StaffMember>[
      StaffMember(1, 'Mang Ben Ocampo', 'Plumber', '0917 555 0141'),
      StaffMember(2, 'Kuya Rey Santos', 'Electrician', '0917 555 0142'),
      StaffMember(3, 'Aling Nena Cruz', 'Housekeeping supervisor', '0917 555 0143'),
      StaffMember(4, 'Dante Villanueva', 'Building engineer', '0917 555 0144'),
      StaffMember(5, 'Joel Mercado', 'Pool and gym attendant', '0917 555 0145'),
      StaffMember(6, 'Ramon Dela Cruz', 'Head of security', '0917 555 0146'),
    ];
    final e = <Equipment>[
      Equipment(1, 'Elevator A', 'Elevator', 'Tower lobby', 'Needs repair', inDays(-75)),
      Equipment(2, 'Elevator B', 'Elevator', 'Tower lobby', 'Working', inDays(-26)),
      Equipment(3, 'Water pump set', 'Plumbing', 'Basement pump room', 'Working', inDays(-48)),
      Equipment(4, 'Standby generator', 'Electrical', 'Basement', 'Working', inDays(-16)),
      Equipment(5, 'Fire alarm panel', 'Fire safety', 'Ground floor lobby', 'Working', inDays(-21)),
      Equipment(6, 'Fire extinguishers', 'Fire safety', 'Every floor', 'Working', inDays(-69)),
      Equipment(7, 'Pool filtration pump', 'Pool', 'Pool deck', 'Working', inDays(-5)),
      Equipment(8, 'Treadmill 2', 'Gym', 'Gym', 'Needs repair', inDays(-40)),
      Equipment(9, 'Lobby aircon', 'Air conditioning', 'Lobby', 'Working', inDays(-29)),
      Equipment(10, 'Parking gate sensor', 'Security', 'Motor parking gate', 'Under maintenance', inDays(-12)),
      Equipment(11, 'Gym shower water heater', 'Plumbing', 'Gym', 'Needs repair', inDays(-90)),
      Equipment(12, 'CCTV system', 'Security', 'Security office', 'Working', inDays(-3)),
    ];
    // title, equipment id, every, days, due in days, staff id, last done days ago
    final t = <(String, int, String, int, int, int, int)>[
      ('Elevator inspection and lubrication', 1, 'Monthly', 30, 5, 4, 26),
      ('Fire extinguisher pressure check', 6, 'Every 3 months', 90, 21, 6, 69),
      ('Generator test run', 4, 'Every 2 weeks', 14, -2, 2, 16),
      ('Water pump servicing', 3, 'Every 3 months', 90, 12, 1, 78),
      ('Pool filter cleaning', 7, 'Weekly', 7, 2, 5, 5),
      ('Fire alarm panel test', 5, 'Monthly', 30, 9, 2, 21),
      ('Lobby aircon filter cleaning', 9, 'Monthly', 30, 0, 4, 30),
      ('Water tank cleaning', 0, 'Every 6 months', 180, 40, 1, 140),
      ('CCTV camera check', 12, 'Weekly', 7, 4, 6, 3),
      ('Gym equipment inspection', 8, 'Every 2 weeks', 14, 6, 5, 8),
    ];
    staff.addAll(s);
    equipment.addAll(e);
    var n = 0;
    for (final x in t) {
      tasks.add(MTask(100 + (++n), x.$1, x.$3, x.$4, inDays(x.$5),
          equipId: x.$2 == 0 ? null : x.$2,
          equipLabel: x.$2 == 0 ? 'Rooftop water tank' : '',
          staffId: x.$6,
          lastDone: inDays(-x.$7)));
    }
    // Repair assignments, matched by the grievance title.
    // title, stage, staff id, target in days, equipment id (0 = none), note
    final r = <(String, int, int, int, int, String)>[
      ('Leaking pipe in the hallway', 1, 1, 2, 0, 'Checking the pipe above the ceiling near Elevator A.'),
      ('Broken hallway light', 2, 2, -3, 0, 'Replaced the lamp and the starter.'),
      ('Parking gate sensor not working', 1, 2, 3, 10, 'Waiting for a replacement sensor from the supplier.'),
      ('Treadmill in the gym is broken', 1, 5, 5, 8, 'Motor belt ordered. Treadmill 2 is closed until it is fixed.'),
      ('Elevator A makes a grinding sound', 1, 4, 1, 1, 'Elevator technician is scheduled to visit.'),
      ('No hot water in the gym shower', 1, 1, 4, 11, 'Heating element must be replaced.'),
    ];
    for (final x in r) {
      final matches = app.grievances.where((g) => g.title == x.$1);
      if (matches.isEmpty) continue;
      final g = matches.first;
      g.stage = x.$2;
      repairs[g.id] = Assignment(staffId: x.$3, target: inDays(x.$4), equipId: x.$5 == 0 ? null : x.$5, notes: x.$6);
    }
    notifyListeners();
  }
}

/// The single maintenance store used by the demo screens.
final MaintenanceState maint = MaintenanceState();
