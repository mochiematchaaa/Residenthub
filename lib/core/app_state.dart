import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'community.dart';
import 'doc_model.dart';
import 'doc_seed.dart';
import 'expenses.dart';
import 'payments.dart';

enum Role { resident, admin }

String peso(num n) {
  final s = n.toStringAsFixed(2);
  final parts = s.split('.');
  final whole = parts[0]
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '₱$whole.${parts[1]}';
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December'
];
String longDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
String shortDate(DateTime d) =>
    '${_months[d.month - 1].substring(0, 3)} ${d.day}, ${d.year}';

String usageLabel(String u) =>
    const {
      'owner': 'Owner-occupied',
      'tenant': 'Rented out (long-term)',
      'shortterm': 'Short-term rental',
      'business': 'Home business',
      'vacant': 'Vacant',
      'away': 'Owner away',
      'renovation': 'Under renovation',
    }[u] ??
    '—';

// ---------------------------------------------------------------- models

class Unit {
  String unit, name, type, status, contact;
  int overdue;
  String usage; // current unit state: owner | tenant | shortterm | business | vacant | away | renovation
  String statusNote, statusDate;

  /// For short-term rentals and home businesses: '' | pending | approved | rejected.
  String usageStatus;

  /// The administrator's note shown to the resident when a declaration is rejected.
  String usageRemark;
  Unit(this.unit, this.name, this.type, this.status, this.contact, this.overdue,
      this.usage,
      {this.statusNote = '', this.statusDate = '', this.usageStatus = '', this.usageRemark = ''});

  /// Short-term rentals and home businesses need the administrator's approval.
  bool get needsApproval => usage == 'shortterm' || usage == 'business';
}

/// One entry in a unit's status history (also drives the admin's update feed).
class StatusUpdate {
  final String unit, key, note, date, by; // by: 'Resident' | 'Admin'
  const StatusUpdate(this.unit, this.key, this.note, this.date, this.by);
}

/// One line in the administrator's "Recent activity" list.
class ActivityEntry {
  final String title, area;
  final DateTime at;
  const ActivityEntry(this.title, this.area, this.at);
}

class Booking {
  final int id;
  final String who, unit, place, when;
  String status; // Pending | Approved | Denied | Completed
  Booking(this.id, this.who, this.unit, this.place, this.when, this.status);
}

class Due {
  final int id;
  final String unit, name;
  final int months;
  bool paid = false;

  /// One-off charge (e.g. a damage fee): [months] is 0 and [note] says what it is for.
  final int? customAmount;
  final String note;
  Due(this.id, this.unit, this.name, this.months, {this.customAmount, this.note = ''});
  bool get isCharge => customAmount != null;
  int get amt => customAmount ?? months * 450;
  String get label => isCharge ? note : '$months month${months == 1 ? '' : 's'} overdue';
}

class MonthDue {
  final String month, due, status;
  final int amt;
  MonthDue(this.month, this.amt, this.due, this.status);
}

class Grievance {
  final int id;
  final String title, body, by; // by = unit label
  int stage; // 0 open, 1 in progress, 2 resolved
  Grievance(this.id, this.title, this.body, this.by, this.stage);
  String get statusLabel => const ['Open', 'In progress', 'Resolved'][stage];
}

class Announcement {
  final int id;
  String title, body, date, status, type;
  bool sms;
  Announcement(this.id, this.title, this.body, this.date, this.status,
      this.type, this.sms);
}

class EventItem {
  final int id;
  final String title, date, place, about;
  final int going; // residents already going, before the signed-in resident's own RSVP
  EventItem(this.id, this.title, this.date, this.place, {this.about = '', this.going = 0});
}

class Account {
  String name, email, phone, unit, role, added;
  bool suspended;
  Account(this.name, this.email, this.phone, this.unit, this.role, this.added,
      {this.suspended = false});
}

class ResidentUser {
  String name, unit, email, phone, password;
  Uint8List? photo;
  ResidentUser(this.name, this.unit, this.email, this.phone, this.password);
  String get unitLabel => unit.split(' · ').first;
}

class SessionInfo {
  final int id;
  final String device, location, when;
  final bool current;
  SessionInfo(this.id, this.device, this.location, this.when, this.current);
}

class ParkingReq {
  final String unit, name;
  bool confirmed;
  ParkingReq(this.unit, this.name, {this.confirmed = false});
}

// ---------------------------------------------------------------- state

final AppState app = AppState();

class AppState extends ChangeNotifier {
  Role? role;
  bool dark = false;
  ResidentUser? me;
  int resTab = 0;
  int adminTab = 0;
  int _id = 1000;
  int nextId() => _id++;
  void _n() => notifyListeners();

  void toggleDark() {
    dark = !dark;
    _n();
  }

  void setResTab(int i) {
    resTab = i;
    _n();
  }

  void setAdminTab(int i) {
    adminTab = i;
    _n();
  }

  // ---- seed data (copied from the web demo) ----
  final List<ResidentUser> residents = [
    ResidentUser('Maria Santos', 'Unit 12A · Owner',
        'maria.santos@cityresidences.ph', '0917 555 0112', 'resident123'),
    ResidentUser('Jessele Fugaban', 'Unit 6B · Owner',
        'jessele.fugaban@cityresidences.ph', '0917 555 0145', 'resident123'),
  ];

  final List<Account> trusted = [
    Account('Maria Santos', 'maria.santos@cityresidences.ph', '0917 555 0112',
        'Unit 12A', 'Resident', 'Aug 1, 2026'),
    Account('Jessele Fugaban', 'jessele.fugaban@cityresidences.ph', '0917 555 0145',
        'Unit 6B', 'Resident', 'Aug 1, 2026'),
  ];
  static const _baseAdminLogins = [
    'joseph', 'joseph capili', 'joseph.capili', 'owner', 'admin',
    'owner@cityresidences.ph'
  ];

  /// Names that sign in as the administrator (includes the e-mail set in the profile).
  List<String> get adminLogins => [..._baseAdminLogins, adminEmail.trim().toLowerCase()];

  // ---- administrator profile (editable in More > Settings) ----
  String adminName = 'Joseph Capili';
  String adminEmail = 'owner@cityresidences.ph';
  String adminPhone = '';
  Uint8List? adminPhoto;
  String get adminFirstName {
    final parts = adminName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? 'Admin' : parts.first;
  }

  String? saveAdminProfile(String name, String email, String phone) {
    if (name.trim().isEmpty) return 'Enter your name.';
    final e = email.trim();
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(e)) return 'Enter a valid email address.';
    final lower = e.toLowerCase();
    if (residents.any((r) => r.email.toLowerCase() == lower) || trusted.any((t) => t.email.toLowerCase() == lower)) {
      return 'That email belongs to a resident account.';
    }
    final ph = phone.trim();
    if (ph.isNotEmpty && !validMobile(normalizePhone(ph))) return 'Enter a valid mobile number, e.g. 0917 555 0112.';
    adminName = name.trim();
    adminEmail = e;
    adminPhone = ph;
    _n();
    return null;
  }

  String? changeAdminPassword(String cur, String nw, String conf) {
    if (cur != adminPassword) return "Current password doesn't match.";
    if (nw.length < 6) return 'New password must be at least 6 characters.';
    if (nw != conf) return "New password and confirmation don't match.";
    adminPassword = nw;
    _n();
    return null;
  }

  void setAdminPhoto(Uint8List? bytes) {
    adminPhoto = bytes;
    _n();
  }

  void setMyPhoto(Uint8List? bytes) {
    final u = me;
    if (u == null) return;
    u.photo = bytes;
    _n();
  }

  final List<Unit> units = [
    Unit('Unit 12A', 'Reyes Household', 'Owner', 'Occupied', '0917 555 0112', 1, 'owner'),
    Unit('Unit 7C', 'Garcia Household', 'Tenant', 'Occupied', '0917 555 0234', 1, 'tenant'),
    Unit('Unit 3B', 'Villanueva Household', 'Owner', 'Occupied', '0917 555 0311', 2, 'shortterm',
        statusNote: 'Listed on Airbnb.', statusDate: 'Mar 12, 2026', usageStatus: 'approved'),
    Unit('Unit 15D', 'Mendoza Household', 'Tenant', 'Occupied', '0917 555 0455', 1, 'tenant'),
    Unit('Unit 9A', 'Cruz Household', 'Owner', 'Occupied', '0917 555 0567', 3, 'owner'),
    Unit('Unit 21B', 'Santos Household', 'Owner', 'Occupied', '0917 555 0678', 1, 'business',
        statusNote: 'Online reselling of home goods.', statusDate: 'Sep 28, 2026', usageStatus: 'pending'),
    Unit('Unit 5A', '—', '—', 'Vacant', '—', 2, 'vacant', statusNote: 'No tenant yet.', statusDate: 'Sep 1, 2026'),
    Unit('Unit 18C', 'Aquino Household', 'Tenant', 'Occupied', '0917 555 0891', 1, 'tenant'),
    Unit('Unit 4D', 'Reyes-Torres Household', 'Owner', 'Occupied', '0917 555 0932', 0, 'owner'),
    Unit('Unit 11B', 'Fernandez Household', 'Owner', 'Occupied', '0917 555 1007', 0, 'owner'),
    Unit('Unit 6B', 'Fugaban Household', 'Owner', 'Occupied', '0917 555 0145', 0, 'owner'),
  ];

  /// Newest first. Residents and the admin both post here.
  final List<StatusUpdate> statusUpdates = [
    const StatusUpdate('Unit 21B', 'business', 'Online reselling of home goods.', 'Sep 28, 2026', 'Resident'),
    const StatusUpdate('Unit 5A', 'vacant', 'No tenant yet.', 'Sep 1, 2026', 'Admin'),
    const StatusUpdate('Unit 12A', 'owner', 'Back home after a month away.', 'Aug 20, 2026', 'Resident'),
    const StatusUpdate('Unit 12A', 'away', 'Out of the country until August 20.', 'Jul 18, 2026', 'Resident'),
    const StatusUpdate('Unit 3B', 'shortterm', 'Listed on Airbnb.', 'Mar 12, 2026', 'Resident'),
  ];
  int newStatusUpdates = 1; // resident updates the admin has not opened yet

  static const facilities = [
    ['Swimming Pool', '6:00 AM – 8:00 PM'],
    ['Function Hall', '8:00 AM – 10:00 PM'],
  ];
  static const slotTimes = [
    '8–10 AM', '10–12 NN', '12–2 PM', '2–4 PM', '4–6 PM', '6–8 PM', '8–10 PM'
  ];
  static const baseBooked = [
    [4, 6],
    [0, 2]
  ];
  final Map<String, bool> blocked = {}; // admin toggles "f-i"
  final Set<String> mySlots = {}; // resident submitted "f-i"

  bool slotBooked(int f, int i) {
    final base = baseBooked[f].contains(i);
    final b = blocked['$f-$i'] ?? false;
    return (base != b) || mySlots.contains('$f-$i');
  }

  final List<Booking> bookings = [
    Booking(1, 'Reyes Household', 'Unit 12A', 'Function Hall', 'Oct 3, 6:00 PM – 10:00 PM', 'Pending'),
    Booking(2, 'Cruz Household', 'Unit 9A', 'Swimming Pool', 'Tomorrow, 3:00 PM – 5:00 PM', 'Pending'),
    Booking(3, 'Garcia Household', 'Unit 7C', 'Function Hall', 'Sat, 2:00 PM – 6:00 PM', 'Pending'),
    Booking(4, 'Villanueva Household', 'Unit 3B', 'Swimming Pool', 'Oct 5, 1:00 PM – 4:00 PM', 'Pending'),
    Booking(5, 'Reyes Household', 'Unit 12A', 'Function Hall', 'Saturday, 2:00 PM – 6:00 PM', 'Approved'),
    Booking(6, 'Reyes Household', 'Unit 12A', 'Function Hall', 'Sep 10, 6:00 PM – 9:00 PM', 'Completed'),
    Booking(7, 'Reyes Household', 'Unit 12A', 'Swimming Pool', 'Sep 2, 3:00 PM – 5:00 PM', 'Completed'),
  ];

  final List<Due> dues = [
    Due(1, 'Unit 12A', 'Reyes Household', 1),
    Due(2, 'Unit 7C', 'Garcia Household', 1),
    Due(3, 'Unit 3B', 'Villanueva Household', 2),
    Due(4, 'Unit 15D', 'Mendoza Household', 1),
    Due(5, 'Unit 9A', 'Cruz Household', 3),
    Due(6, 'Unit 21B', 'Santos Household', 1),
    Due(7, 'Unit 5A', 'Vacant unit', 2),
    Due(8, 'Unit 18C', 'Aquino Household', 1),
  ];
  num motorRate = 500;
  final List<ParkingReq> parking = [
    ParkingReq('Unit 4D', 'Reyes-Torres Household'),
    ParkingReq('Unit 11B', 'Fernandez Household'),
  ];
  final List<ParkingSlot> slots = seedSlots();

  // ---- payment options, proofs and receipts ----
  // The account details below are SAMPLE text. The administrator edits them in
  // Finance > Payment options before the app is handed over.
  static const officePay = 'Cash or check at the office';
  final List<PayMethod> payMethods = [
    PayMethod(officePay,
        'Administration office, ground floor. Monday to Saturday, 8:00 AM - 5:00 PM.'),
    PayMethod('Bank transfer',
        'Account name: City Residences Condominium Corp.\nBank: (add bank name)\nAccount no.: (add account number)'),
    PayMethod('GCash', 'Account name: (add name)\nNumber: (add GCash number)'),
    PayMethod('Maya', 'Account name: (add name)\nNumber: (add Maya number)'),
  ];

  int _receiptSeq = 7;
  final List<PaymentRecord> payments = [
    const PaymentRecord(6, 'OR-2026-0006', 'Unit 6B', 'Jessele Fugaban', '1 month association dues',
        'Cash or check at the office', '—', 'Aug 12, 2026', 450),
    const PaymentRecord(5, 'OR-2026-0005', 'Unit 12A', 'Maria Santos', '1 month association dues',
        'Cash or check at the office', '—', 'Aug 11, 2026', 450),
    const PaymentRecord(4, 'OR-2026-0004', 'Unit 6B', 'Jessele Fugaban', '1 month association dues',
        'GCash', 'GC-2026-07-0145', 'Jul 13, 2026', 450),
    const PaymentRecord(3, 'OR-2026-0003', 'Unit 12A', 'Maria Santos', '1 month association dues',
        'Bank transfer', 'BT-2026-07-0112', 'Jul 12, 2026', 450),
    const PaymentRecord(2, 'OR-2026-0002', 'Unit 6B', 'Jessele Fugaban', '1 month association dues',
        'Maya', 'MY-2026-06-0145', 'Jun 14, 2026', 450),
    const PaymentRecord(1, 'OR-2026-0001', 'Unit 12A', 'Maria Santos', '1 month association dues',
        'GCash', 'GC-2026-06-0112', 'Jun 13, 2026', 450),
  ];
  final List<PaymentProof> proofs = [];

  List<PaymentRecord> get myPayments =>
      payments.where((p) => p.unit == myUnit).toList();
  List<PaymentProof> get myProofs =>
      proofs.where((p) => p.unit == myUnit).toList();
  int get pendingProofs => proofs.where((p) => p.status == 'Pending').length;
  List<PayMethod> get enabledPayMethods =>
      payMethods.where((m) => m.enabled).toList();

  /// Total of the payments recorded in the given month.
  num collectedIn(int year, int month) => payments
      .where((p) => p.when.year == year && p.when.month == month)
      .fold<num>(0, (s, p) => s + p.amount);

  num get collectedThisMonth {
    final n = DateTime.now();
    return collectedIn(n.year, n.month);
  }

  num get totalCollected => payments.fold<num>(0, (s, p) => s + p.amount);

  /// The last [n] months (oldest first) ending with the current month.
  List<DateTime> trendMonths([int n = 6]) {
    final now = DateTime.now();
    return [for (var i = n - 1; i >= 0; i--) DateTime(now.year, now.month - i, 1)];
  }

  List<double> collectionTrend([int n = 6]) =>
      [for (final m in trendMonths(n)) collectedIn(m.year, m.month).toDouble()];

  List<String> collectionTrendLabels([int n = 6]) =>
      [for (final m in trendMonths(n)) _months[m.month - 1].substring(0, 3)];

  PaymentRecord _addPayment(String unit, String payer, String forText,
      String method, String reference, num amount) {
    final rec = PaymentRecord(
      nextId(),
      'OR-2026-${(_receiptSeq++).toString().padLeft(4, '0')}',
      unit,
      payer,
      forText,
      method,
      reference.trim().isEmpty ? '—' : reference.trim(),
      shortDate(DateTime.now()),
      amount,
    );
    payments.insert(0, rec);
    return rec;
  }

  static String _duesText(int months) =>
      '$months month${months == 1 ? '' : 's'} association dues';

  /// Resident: "I have paid" with the reference number. Returns an error or null.
  String? submitProof(String method, String reference, String amountRaw) {
    final a = double.tryParse(amountRaw.trim().replaceAll(',', ''));
    if (a == null || a <= 0) return 'Enter the amount you paid.';
    if (reference.trim().isEmpty) {
      return 'Enter the reference number from your payment receipt.';
    }
    proofs.insert(0,
        PaymentProof(nextId(), myUnit, myHousehold, method, reference.trim(), shortDate(DateTime.now()), a));
    logActivity('Payment reference sent, $myUnit', 'Finance');
    _n();
    return null;
  }

  // ---- expenses (administrator) ----
  final List<Expense> expenses = [];

  /// Records one purchase of the corporation. Returns an error message or null.
  String? addExpense({
    required String category,
    required String area,
    required String item,
    required String payee,
    required String qtyRaw,
    required String unitPriceRaw,
    required String receiptNo,
    required String note,
    required String dateRaw,
  }) {
    if (item.trim().isEmpty) return 'Enter what was bought.';
    final qty = qtyRaw.trim().isEmpty ? 1.0 : double.tryParse(qtyRaw.trim().replaceAll(',', ''));
    if (qty == null || qty <= 0) return 'Enter a valid quantity.';
    final price = double.tryParse(unitPriceRaw.trim().replaceAll(',', ''));
    if (price == null || price <= 0) return 'Enter the price of one piece or one unit.';
    if (payee.trim().isEmpty) return 'Enter the store or supplier.';
    final d = dateRaw.trim().isEmpty ? DateTime.now() : parseShortDate(dateRaw);
    if (d == null) return 'Enter the date like "Oct 10, 2026".';
    final e = Expense(
      id: nextId(),
      item: item.trim(),
      category: category,
      area: area,
      payee: payee.trim(),
      receiptNo: receiptNo.trim(),
      note: note.trim(),
      qty: qty,
      unitPrice: price,
      date: d,
    );
    expenses.add(e);
    expenses.sort((x, y) => y.date.compareTo(x.date));
    logActivity('Purchase recorded: ${e.item}, ${peso(e.amount)}', 'Finance');
    _n();
    return null;
  }

  void removeExpense(Expense e) {
    expenses.remove(e);
    _n();
  }

  num spentIn(int year, int month) => expenses
      .where((e) => e.date.year == year && e.date.month == month)
      .fold<num>(0, (s, e) => s + e.amount);

  /// Expenses of the current month.
  num get spentThisMonth {
    final n = DateTime.now();
    return spentIn(n.year, n.month);
  }

  String monthLabel(DateTime d) => '${_months[d.month - 1]} ${d.year}';

  /// Resident: SIMULATED online checkout (stands in for a payment gateway).
  /// No real money moves: it settles the resident's open dues, issues a receipt
  /// and marks the method as "(simulated)". Returns null when nothing is owed.
  PaymentRecord? payOnlineSimulated(String method) {
    final total = myBalance;
    if (total <= 0) return null;
    final open = dues.where((d) => d.unit == myUnit && !d.paid).toList();
    for (final d in open) {
      d.paid = true;
    }
    final code = method.toLowerCase().contains('gcash')
        ? 'GC'
        : method.toLowerCase().contains('maya')
            ? 'MY'
            : method.toLowerCase().contains('bank')
                ? 'BK'
                : 'CD';
    final ref = 'SIM-$code-${(DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0')}';
    final forText = open.isEmpty
        ? 'Association dues'
        : open.map((d) => d.isCharge ? d.note : _duesText(d.months)).join(', ');
    final rec = _addPayment(myUnit, myHousehold, forText, '$method (simulated)', ref, total);
    logActivity('Online payment received (simulated), $myUnit', 'Finance');
    _n();
    return rec;
  }

  /// Admin: the proof checks out - record the payment and issue a receipt.
  PaymentRecord confirmProof(PaymentProof p) {
    p.status = 'Confirmed';
    final open = dues.where((d) => d.unit == p.unit && !d.paid).toList()
      ..sort((a, b) => a.isCharge == b.isCharge ? 0 : (a.isCharge ? 1 : -1));
    final String forText;
    if (open.isNotEmpty) {
      open.first.paid = true;
      forText = open.first.isCharge ? open.first.note : _duesText(open.first.months);
    } else {
      forText = 'Association dues';
    }
    final rec = _addPayment(p.unit, p.payer, forText, p.method, p.reference, p.amount);
    logActivity('Payment recorded, ${p.unit}', 'Finance');
    _n();
    return rec;
  }

  void rejectProof(PaymentProof p) {
    p.status = 'Rejected';
    logActivity('Payment reference not confirmed, ${p.unit}', 'Finance');
    _n();
  }

  void updatePayMethod(PayMethod m, String details, bool enabled) {
    if (details.trim().isNotEmpty) m.details = details.trim();
    m.enabled = enabled;
    _n();
  }

  final List<Grievance> grievances = [
    Grievance(1, 'Street light out on the Phase 2 road', '', 'Unit 8A', 0),
    Grievance(2, 'Construction noise after 8 PM', '', 'Unit 14B', 1),
    Grievance(3, 'Clogged drainage near the parking area', '', 'Unit 3D', 2),
    Grievance(4, 'Slow drainage in the hallway sink',
        'Reported last week, plumber scheduled.', 'Unit 12A', 1),
  ];

  final List<DocItem> docs = seedDocs();

  /// Documents the signed-in role is allowed to see.
  List<DocItem> get visibleDocs {
    final mine = role == Role.admin ? 'admin' : 'resident';
    return docs.where((d) => d.audience == 'all' || d.audience == mine).toList();
  }

  /// General documents (everything except finance).
  List<DocItem> get communityDocs =>
      visibleDocs.where((d) => d.cat != 'Finance').toList();

  /// Finance documents are kept separate from the general documents.
  List<DocItem> get financeDocs =>
      visibleDocs.where((d) => d.cat == 'Finance').toList();

  final List<Announcement> announcements = [
    Announcement(1, 'Water interruption this Saturday',
        'Main water supply will be shut off from 9 AM to 3 PM for pipe maintenance.',
        'Yesterday', 'Published', 'Maintenance', true),
    Announcement(2, 'Annual General Assembly',
        "This year's assembly is set for October 18, 6:00 PM at the Function Hall.",
        '3 days ago', 'Published', 'General', false),
    Announcement(3, 'Reminder: October dues due on the 5th',
        'Please settle dues on or before due date to avoid penalties.',
        'Sep 20, 2026', 'Published', 'General', false),
    Announcement(4, 'Water interruption on Sept 30',
        'Scheduled maintenance, 10 PM–4 AM.', 'Sep 24, 2026', 'Published',
        'Maintenance', true),
    Announcement(5, 'Elevator B undergoing inspection',
        'Elevator B out of service Oct 1, 8 AM–12 PM.', 'Sep 18, 2026',
        'Draft', 'Maintenance', false),
  ];

  /// Mobile numbers of the resident accounts (used to text announcements).
  List<String> get residentPhones => [
        for (final a in trusted)
          if (a.role == 'Resident' && validMobile(normalizePhone(a.phone))) normalizePhone(a.phone),
      ];

  final List<EventItem> events = [
    EventItem(1, 'Community Clean-Up Drive', 'Oct 4, 2026 · 7:00 AM', 'Ground floor lobby',
        about: 'Gloves and bags are provided. Breakfast is on the association.', going: 19),
    EventItem(2, 'Zumba at the Function Hall', 'Every Sat · 6:00 AM', 'Function Hall',
        about: 'A free weekly workout for residents of all ages. Bring a towel and water.', going: 14),
    EventItem(3, 'Annual General Assembly', 'Oct 18, 2026 · 6:00 PM', 'Function Hall',
        about: 'Yearly report, budget and board updates. Every unit is encouraged to send a representative.', going: 41),
    EventItem(4, "Halloween Kids' Party", 'Oct 31, 2026 · 4:00 PM', 'Function Hall',
        about: 'Kids in costume walk the building with a parent. Volunteers are welcome to hand out treats.', going: 27),
    EventItem(5, 'HOA General Assembly', 'Nov 8, 2026 · 6:00 PM', 'Function Hall',
        about: 'Board election and the budget for next year.', going: 33),
  ];

  /// What happened in the app, newest first (shown as "Recent activity").
  final List<ActivityEntry> activityLog = [];

  void logActivity(String title, String area) {
    activityLog.insert(0, ActivityEntry(title, area, DateTime.now()));
    if (activityLog.length > 200) activityLog.removeRange(200, activityLog.length);
  }

  /// "just now", "5 minutes ago", "Yesterday", "Oct 8, 2026".
  static String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} minute${d.inMinutes == 1 ? '' : 's'} ago';
    if (d.inHours < 24) return '${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
    if (d.inDays == 1) return 'Yesterday';
    return shortDate(t);
  }

  /// Bookings to show as "upcoming": approved first, then waiting for approval.
  List<Booking> get upcomingBookings {
    final l = [
      ...bookings.where((b) => b.status == 'Approved'),
      ...bookings.where((b) => b.status == 'Pending'),
    ];
    return l.take(3).toList();
  }

  /// The signed-in resident's notifications, built from what is really on record.
  /// Each entry is [text, tone] with tone good | bad | info.
  List<List<String>> get myNotifs {
    final out = <List<String>>[];
    for (final b in myBookings) {
      if (b.status == 'Approved') {
        out.add(['Your ${b.place} booking (${b.when}) was approved.', 'good']);
      } else if (b.status == 'Denied') {
        out.add(['Your ${b.place} booking (${b.when}) was not approved.', 'bad']);
      } else if (b.status == 'Pending') {
        out.add(['Your ${b.place} request (${b.when}) is waiting for approval.', 'info']);
      }
    }
    for (final r in myDueRows) {
      if (r.status == 'Overdue') {
        out.add(['Dues for ${r.month} are overdue.', 'bad']);
      } else if (r.status == 'Open') {
        out.add(['Open charge: ${r.month}.', 'info']);
      }
    }
    for (final p in myProofs) {
      if (p.status == 'Confirmed') {
        out.add(['Your payment (ref. ${p.reference}) was confirmed. The receipt is under Dues & payment.', 'good']);
      } else if (p.status == 'Rejected') {
        out.add(['Your payment (ref. ${p.reference}) could not be confirmed. Please check the reference number.', 'bad']);
      }
    }
    final rec = myUnitRec;
    if (rec != null && rec.needsApproval) {
      if (rec.usageStatus == 'approved') {
        out.add(['Your ${usageLabel(rec.usage).toLowerCase()} was approved.', 'good']);
      } else if (rec.usageStatus == 'rejected') {
        out.add(['Your ${usageLabel(rec.usage).toLowerCase()} was not approved. ${rec.usageRemark}', 'bad']);
      } else if (rec.usageStatus == 'pending') {
        out.add(['Your ${usageLabel(rec.usage).toLowerCase()} is waiting for the administrator.', 'info']);
      }
    }
    if (pollsToVote > 0) {
      out.add(['$pollsToVote poll${pollsToVote > 1 ? 's' : ''} waiting for your vote.', 'info']);
    }
    final mySlot = slotOf(myUnit);
    if (mySlot != null) out.add(['Motor parking slot ${mySlot.id} is assigned to your unit.', 'good']);
    for (final a in announcements.where((a) => a.status == 'Published').take(2)) {
      out.add(['New announcement: ${a.title}.', 'info']);
    }
    return out;
  }

  /// Accounts live on this device only, so the only session is the current one.
  List<SessionInfo> sessions = [];

  static String _deviceLabel() {
    if (kIsWeb) return 'Web browser · ResidentHub';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android phone · ResidentHub app',
      TargetPlatform.iOS => 'iPhone · ResidentHub app',
      _ => 'Computer · ResidentHub',
    };
  }

  static String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  // ---------------------------------------------------------------- auth

  /// Returns an error message, or null when sign-in succeeded.
  /// Administrator (owner) password. Change it here before handing the app over.
  String adminPassword = 'admin123';

  int _failedLogins = 0;
  DateTime? _lockedUntil;

  String _loginFailed() {
    _failedLogins++;
    if (_failedLogins >= 5) {
      _failedLogins = 0;
      _lockedUntil = DateTime.now().add(const Duration(minutes: 1));
      return 'Too many failed attempts. Please wait a minute and try again.';
    }
    return "Incorrect email/username or password. If you don't have an account yet, ask the administrator to set one up.";
  }

  String? login(String emailRaw, String pass) {
    final e = emailRaw.trim().toLowerCase();
    if (e.isEmpty) return 'Enter your email or username.';
    if (pass.isEmpty) return 'Enter your password.';
    final lock = _lockedUntil;
    if (lock != null && DateTime.now().isBefore(lock)) {
      return 'Too many failed attempts. Please wait a minute and try again.';
    }
    final acct = trusted.where((t) => t.email.toLowerCase() == e).toList();
    if (acct.isNotEmpty && acct.first.suspended) {
      return 'This account has been suspended. Contact the owner.';
    }
    // Owner / administrator
    if (adminLogins.contains(e)) {
      if (pass != adminPassword) return _loginFailed();
      return _enter(Role.admin, null);
    }
    // Residents
    final u = residents.where((r) => r.email.toLowerCase() == e).toList();
    if (u.isNotEmpty && pass == u.first.password) return _enter(Role.resident, u.first);
    return _loginFailed();
  }

  // ---------------------------------------------------------- forgot password
  // Residents reset their password with a 6-digit code sent to the mobile number
  // on file. No SMS gateway is connected in this build, so with [showTestCode] on,
  // the code is shown on screen instead. Turn it off and plug a gateway into
  // [startPasswordReset] when you go live.
  static const bool showTestCode = true;

  String? _otpPhone, _otpCode;
  DateTime? _otpExpires;
  int _otpTries = 0;

  static String normalizePhone(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('63') && d.length == 12) d = '0${d.substring(2)}';
    return d;
  }

  static bool validMobile(String normalized) => RegExp(r'^09\d{9}$').hasMatch(normalized);

  /// Step 1: the resident enters their phone number. Always looks the same from
  /// the outside, whether or not the number belongs to an account.
  String? startPasswordReset(String phoneRaw) {
    final n = normalizePhone(phoneRaw);
    if (!validMobile(n)) return 'Enter a valid mobile number, e.g. 0917 555 0112.';
    _otpPhone = n;
    _otpTries = 0;
    if (residents.any((r) => normalizePhone(r.phone) == n)) {
      _otpCode = (100000 + math.Random().nextInt(900000)).toString();
      _otpExpires = DateTime.now().add(const Duration(minutes: 5));
    } else {
      _otpCode = null;
      _otpExpires = null;
    }
    return null;
  }

  /// The code that would be texted (null when the number has no account).
  String? get pendingTestCode => _otpCode;

  /// Step 2: code + new password.
  String? finishPasswordReset(String code, String nw, String conf) {
    final c = _otpCode, p = _otpPhone, exp = _otpExpires;
    if (c == null || p == null || exp == null) return 'That code is not valid. Request a new one.';
    if (DateTime.now().isAfter(exp)) {
      _clearOtp();
      return 'That code has expired. Request a new one.';
    }
    if (++_otpTries > 5) {
      _clearOtp();
      return 'Too many wrong codes. Request a new one.';
    }
    if (code.trim() != c) return 'That code is not correct.';
    if (nw.length < 6) return 'New password must be at least 6 characters.';
    if (nw != conf) return "New password and confirmation don't match.";
    for (final r in residents.where((r) => normalizePhone(r.phone) == p)) {
      r.password = nw;
    }
    _clearOtp();
    _failedLogins = 0;
    _lockedUntil = null;
    return null;
  }

  void _clearOtp() {
    _otpPhone = null;
    _otpCode = null;
    _otpExpires = null;
    _otpTries = 0;
  }

  String? _enter(Role r, ResidentUser? user) {
    _failedLogins = 0;
    _lockedUntil = null;
    role = r;
    me = user;
    sessions = [SessionInfo(1, _deviceLabel(), 'Signed in at ${_clock(DateTime.now())}', 'Active now', true)];
    resTab = 0;
    adminTab = 0;
    _n();
    return null;
  }

  void logout() {
    role = null;
    me = null;
    resTab = 0;
    adminTab = 0;
    _n();
  }

  // ---------------------------------------------------------------- resident

  String get myUnit => me?.unitLabel ?? 'Unit 12A';
  Unit? get myUnitRec {
    final l = units.where((u) => u.unit == myUnit).toList();
    return l.isEmpty ? null : l.first;
  }

  String get myHousehold => myUnitRec?.name ?? me?.name ?? '';
  List<Booking> get myBookings =>
      bookings.where((b) => b.unit == myUnit).toList();
  List<Grievance> get myGrievances =>
      grievances.where((g) => g.by == myUnit).toList();
  bool get parkingRequested => parking.any((p) => p.unit == myUnit);

  List<MonthDue> get myDueRows {
    final overdue = dues.any((d) => d.unit == myUnit && !d.paid && !d.isCharge);
    return [
      for (final d in dues)
        if (d.unit == myUnit && d.isCharge)
          MonthDue(d.note, d.amt, 'upon receipt', d.paid ? 'Paid' : 'Open'),
      MonthDue('September 2026', 450, 'Sep 15', overdue ? 'Overdue' : 'Paid'),
      MonthDue('August 2026', 450, 'Aug 15', 'Paid'),
      MonthDue('July 2026', 450, 'Jul 15', 'Paid'),
      MonthDue('June 2026', 450, 'Jun 15', 'Paid'),
    ];
  }

  int get myBalance =>
      myDueRows.where((d) => d.status != 'Paid').fold(0, (s, d) => s + d.amt);

  Booking? get upcomingBooking {
    final l = myBookings
        .where((b) => b.status == 'Approved' || b.status == 'Pending')
        .toList();
    return l.isEmpty ? null : l.first;
  }

  void submitBooking(int f, int slot) {
    mySlots.add('$f-$slot');
    bookings.insert(
        0,
        Booking(nextId(), myHousehold, myUnit, facilities[f][0],
            '${slotTimes[slot]} today', 'Pending'));
    logActivity('Booking request for the ${facilities[f][0]}, $myUnit', 'Facilities');
    _n();
  }

  void addGrievance(String title, String body) {
    grievances.insert(0,
        Grievance(nextId(), title, body.isEmpty ? 'No further details.' : body, myUnit, 0));
    logActivity('Grievance opened: $title', 'Requests');
    _n();
  }

  void requestParking() {
    if (!parkingRequested) parking.add(ParkingReq(myUnit, myHousehold));
    _n();
  }

  List<StatusUpdate> get myStatusUpdates =>
      statusUpdates.where((u) => u.unit == myUnit).toList();

  /// Resident posts the new state of their unit. Takes effect immediately.
  String? postMyStatus(String key, String note) {
    final u = myUnitRec;
    if (u == null) return 'Unit record not found.';
    if (const ['tenant', 'shortterm', 'business', 'renovation'].contains(key) &&
        note.trim().isEmpty) {
      return 'Add a short note first, e.g. tenant name, platform, business type or expected end date.';
    }
    _applyStatus(u, key, note.trim(), 'Resident');
    newStatusUpdates++;
    _n();
    return null;
  }

  /// Admin sets the state of any unit.
  void adminSetStatus(Unit u, String key, String note) {
    _applyStatus(u, key, note.trim(), 'Admin');
    _n();
  }

  void markStatusSeen() {
    if (newStatusUpdates == 0) return;
    newStatusUpdates = 0;
    _n();
  }

  void _applyStatus(Unit u, String key, String note, String by) {
    final date = shortDate(DateTime.now());
    u.usage = key;
    final needs = key == 'shortterm' || key == 'business';
    // A resident's declaration waits for the administrator; the administrator's own change is approved.
    u.usageStatus = !needs ? '' : (by == 'Admin' ? 'approved' : 'pending');
    u.usageRemark = '';
    u.statusNote = note;
    u.statusDate = date;
    u.status = key == 'vacant' ? 'Vacant' : 'Occupied';
    statusUpdates.insert(0, StatusUpdate(u.unit, key, note, date, by));
    logActivity('${u.unit} status set to ${usageLabel(key).toLowerCase()}', 'Units');
  }

  void saveProfile(String name, String email, String phone) {
    final u = me;
    if (u == null) return;
    u.name = name.trim();
    u.email = email.trim();
    u.phone = phone.trim();
    _n();
  }

  String? changePassword(String cur, String nw, String conf) {
    final u = me;
    if (u == null) return 'No signed-in account to update.';
    if (cur != u.password) return "Current password doesn't match.";
    if (nw.length < 6) return 'New password must be at least 6 characters.';
    if (nw != conf) return "New password and confirmation don't match.";
    u.password = nw;
    _n();
    return null;
  }

  void logoutSession(int id) {
    sessions = sessions.where((s) => s.id != id).toList();
    _n();
  }

  void logoutOthers() {
    sessions = sessions.where((s) => s.current).toList();
    _n();
  }

  // ---------------------------------------------------------------- admin

  int get unpaidCount => dues.where((d) => !d.paid).length;
  int get openGrievances => grievances.where((g) => g.stage < 2).length;
  int get pendingBookings => bookings.where((b) => b.status == 'Pending').length;
  int get pendingParking => parking.where((p) => !p.confirmed).length;

  void toggleSlot(int f, int i) {
    final k = '$f-$i';
    blocked[k] = !(blocked[k] ?? false);
    _n();
  }

  void bookAct(int id, String status) {
    final b = bookings.firstWhere((b) => b.id == id);
    b.status = status;
    logActivity('${b.place} booking ${status.toLowerCase()}, ${b.unit}', 'Facilities');
    _n();
  }

  /// Admin: adds a one-off charge (e.g. a facility damage fee) to a unit.
  String? addCharge(String unitRaw, String amountRaw, String note) {
    String norm(String t) => t.toLowerCase().replaceAll('unit', '').replaceAll(RegExp(r'[^a-z0-9]'), '');
    final key = norm(unitRaw);
    final match = key.isEmpty ? <Unit>[] : units.where((u) => norm(u.unit) == key).toList();
    if (match.isEmpty) return 'No unit with that name. Use a unit such as "Unit 12A".';
    final a = double.tryParse(amountRaw.trim().replaceAll(',', ''));
    if (a == null || a <= 0) return 'Enter a valid amount.';
    if (note.trim().isEmpty) return 'Add a short description, e.g. Facility damage fee.';
    dues.add(Due(nextId(), match.first.unit, match.first.name, 0, customAmount: a.round(), note: note.trim()));
    logActivity('Charge added, ${match.first.unit}: ${note.trim()}', 'Finance');
    _n();
    return null;
  }

  /// Records a payment for a unit's dues and issues a receipt.
  PaymentRecord? payDue(int id, {String method = officePay, String reference = ''}) {
    final d = dues.firstWhere((d) => d.id == id);
    if (d.paid) return null;
    d.paid = true;
    final rec = _addPayment(d.unit, d.name, d.isCharge ? d.note : _duesText(d.months), method, reference, d.amt);
    logActivity('Payment recorded, ${d.unit}', 'Finance');
    _n();
    return rec;
  }

  String? setRate(String raw) {
    final n = double.tryParse(raw.trim());
    if (n == null || n < 0) return 'Enter a valid amount before updating the rate.';
    motorRate = n;
    _n();
    return null;
  }

  /// Gives the first free slot to a parking request. Returns an error message or null.
  String? assignRequest(ParkingReq p) {
    final free = freeSlot;
    if (free == null) return 'There are no free slots right now.';
    free.unit = p.unit;
    p.confirmed = true;
    logActivity('Parking slot ${free.id} assigned to ${p.unit}', 'Parking');
    _n();
    return null;
  }

  void confirmParking(ParkingReq p) => assignRequest(p);

  void declineParking(ParkingReq p) {
    parking.remove(p);
    logActivity('Parking request declined, ${p.unit}', 'Parking');
    _n();
  }

  ParkingSlot? get freeSlot {
    for (final s in slots) {
      if (!s.used) return s;
    }
    return null;
  }

  int get slotsUsed => slots.where((s) => s.used).length;

  /// The slot a unit has been given, or null.
  ParkingSlot? slotOf(String unit) {
    for (final s in slots) {
      if (s.unit == unit) return s;
    }
    return null;
  }

  void assignSlot(ParkingSlot s, String unit) {
    s.unit = unit;
    for (final r in parking.where((r) => r.unit == unit)) {
      r.confirmed = true;
    }
    logActivity('Parking slot ${s.id} assigned to $unit', 'Parking');
    _n();
  }

  void releaseSlot(ParkingSlot s) {
    logActivity('Parking slot ${s.id} released from ${s.unit}', 'Parking');
    s.unit = '';
    _n();
  }

  // ---- polls (admin publishes, residents vote once per unit) ----
  final List<Poll> polls = seedPolls();
  final Map<String, int> _votes = {}; // '<unit>|<pollId>' -> option index

  int? myVote(int pollId) => _votes['$myUnit|$pollId'];
  int get pollsToVote => polls.where((p) => p.open && myVote(p.id) == null).length;
  int get openPolls => polls.where((p) => p.open).length;

  String? castVote(Poll p, int option) {
    if (!p.open) return 'This poll is closed.';
    if (myVote(p.id) != null) return 'Your unit has already voted in this poll.';
    if (option < 0 || option >= p.options.length) return 'Pick an option first.';
    p.options[option].votes++;
    _votes['$myUnit|${p.id}'] = option;
    logActivity('Poll vote from $myUnit: ${p.question}', 'Polls');
    _n();
    return null;
  }

  String? addPoll(String question, String optionsRaw) {
    final opts = optionsRaw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (question.trim().isEmpty || opts.length < 2) return 'Add a question and at least two options (one per line).';
    final closes = shortDate(DateTime.now().add(const Duration(days: 7)));
    polls.insert(0, Poll(nextId(), question.trim(), true, closes, [for (final o in opts) PollOption(o, 0)]));
    logActivity('Poll published: ${question.trim()}', 'Polls');
    _n();
    return null;
  }

  void togglePoll(Poll p) {
    p.open = !p.open;
    logActivity('Poll ${p.open ? 'reopened' : 'closed'}: ${p.question}', 'Polls');
    _n();
  }

  void deletePoll(Poll p) {
    polls.remove(p);
    logActivity('Poll deleted: ${p.question}', 'Polls');
    _n();
  }

  // ---- events (residents say they are going) ----
  final Set<int> rsvp = {};
  int goingCount(EventItem e) => e.going + (rsvp.contains(e.id) ? 1 : 0);

  void toggleRsvp(EventItem e) {
    if (!rsvp.remove(e.id)) rsvp.add(e.id);
    logActivity('${rsvp.contains(e.id) ? 'Going to' : 'No longer going to'}: ${e.title}', 'Events');
    _n();
  }

  // ---- unit rentals (the administrator reviews short-term rentals and home businesses) ----
  int get rentalsToReview => units.where((u) => u.needsApproval && u.usageStatus == 'pending').length;

  void reviewUsage(Unit u, bool approve, String note) {
    u.usageStatus = approve ? 'approved' : 'rejected';
    u.usageRemark = approve ? '' : (note.trim().isEmpty ? 'Not approved at this time. Please contact the office.' : note.trim());
    logActivity('${approve ? 'Approved' : 'Rejected'} ${usageLabel(u.usage).toLowerCase()} for ${u.unit}', 'Units');
    _n();
  }

  void advanceGrievance(int id) {
    final g = grievances.firstWhere((g) => g.id == id);
    if (g.stage < 2) g.stage++;
    logActivity('Grievance ${g.stage == 2 ? 'resolved' : 'in progress'}: ${g.title}', 'Requests');
    _n();
  }

  void publishAnn(int id) {
    final a = announcements.firstWhere((a) => a.id == id);
    a.status = 'Published';
    logActivity('Announcement published: ${a.title}', 'Announcements');
    _n();
  }

  void addAnnouncement(String title, String body, String type, bool sms) {
    announcements.insert(
        0,
        Announcement(nextId(), title, body.isEmpty ? '—' : body, 'Just now',
            'Published', type, sms));
    logActivity('Announcement published: $title', 'Announcements');
    _n();
  }

  void editAnnouncement(int id, String title, String body) {
    final a = announcements.firstWhere((a) => a.id == id);
    if (title.trim().isNotEmpty) a.title = title.trim();
    if (body.trim().isNotEmpty) a.body = body.trim();
    _n();
  }

  void deleteAnnouncement(int id) {
    announcements.removeWhere((a) => a.id == id);
    _n();
  }

  void addEvent(String title, String date, String place) {
    events.insert(
        0,
        EventItem(nextId(), title, date.isEmpty ? 'Date TBD' : date,
            place.isEmpty ? 'Venue TBD' : place));
    _n();
  }

  void deleteEvent(int id) {
    events.removeWhere((e) => e.id == id);
    _n();
  }

  void addDoc(DocItem d) {
    docs.insert(0, d);
    _n();
  }

  void removeDoc(DocItem d) {
    docs.remove(d);
    _n();
  }

  String? addAccount(String name, String email, String phone, String role, String unit) {
    name = name.trim();
    email = email.trim();
    if (name.isEmpty || email.isEmpty) return 'Full name and email are required.';
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) return 'Enter a valid email address.';
    final clash = email.toLowerCase() == 'owner@cityresidences.ph' ||
        trusted.any((t) => t.email.toLowerCase() == email.toLowerCase()) ||
        residents.any((r) => r.email.toLowerCase() == email.toLowerCase());
    if (clash) return 'An account with that email already exists.';
    if (role == 'Resident' && unit.trim().isEmpty) {
      return "Assign a unit to confirm this resident's account.";
    }
    final u = role == 'Resident' ? unit.trim() : '—';
    trusted.add(Account(name, email, phone.trim().isEmpty ? '—' : phone.trim(), u, role, 'Just now'));
    if (role == 'Resident') {
      residents.add(ResidentUser(name, '$u · Owner', email,
          phone.trim().isEmpty ? '—' : phone.trim(), 'resident123'));
    }
    _n();
    return null;
  }

  /// Admin issues a temporary password; returns it so it can be handed over.
  String resetPassword(Account a) {
    const tmp = 'resident123';
    for (final r in residents.where((r) => r.email.toLowerCase() == a.email.toLowerCase())) {
      r.password = tmp;
    }
    _n();
    return tmp;
  }

  void toggleSuspend(Account a) {
    a.suspended = !a.suspended;
    _n();
  }

  void revoke(Account a) {
    trusted.remove(a);
    residents.removeWhere((r) => r.email.toLowerCase() == a.email.toLowerCase());
    _n();
  }
}
