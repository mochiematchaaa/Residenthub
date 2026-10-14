/// Community features that match the website dashboards:
/// polls, motor parking slots and the resident directory.
/// Pure data. It does not import the app state, so app_state.dart can use it.

class PollOption {
  final String text;
  int votes;
  PollOption(this.text, this.votes);
}

class Poll {
  final int id;
  String question;
  bool open;
  String closes;
  final List<PollOption> options;
  Poll(this.id, this.question, this.open, this.closes, this.options);

  int get total => options.fold<int>(0, (s, o) => s + o.votes);
}

/// One motor parking slot. [unit] is empty when the slot is free.
class ParkingSlot {
  final String id;
  String unit;
  ParkingSlot(this.id, [this.unit = '']);
  bool get used => unit.isNotEmpty;
}

/// Slot names for a motor parking area with [n] slots: M-01, M-02, ...
List<String> slotNames(int n) => [for (var i = 1; i <= n; i++) 'M-${i.toString().padLeft(2, '0')}'];

// ---------------------------------------------------------------- directory

class ContactInfo {
  final String name, note, tel;
  const ContactInfo(this.name, this.note, this.tel);
}

/// Filled in by the administrator (More > Directory and house rules) and shared with every resident.
final List<ContactInfo> directoryContacts = [];

/// Each rule is [title, text]. Filled in by the administrator.
final List<List<String>> houseRules = [];

const directoryFaq = [
  [
    'How do I book the pool or the Function Hall?',
    'Open Book, pick the place, tap an open time slot and send your request. The office approves it and you will see the result under My reservations.'
  ],
  ['When are monthly dues due?', 'Dues are due on the 15th of every month. Your balance and history are under Dues.'],
  [
    'I rent out my unit. What do I need to do?',
    'Open Unit Rental and tell us how your unit is used. Long-term leases are saved right away. Short-term rentals and home businesses need the administrator\'s approval.'
  ],
  [
    'How do I request motor parking?',
    'Open Dues and use the Motor parking rental box. The office will assign a slot when one is free.'
  ],
  [
    'How do I report a problem in the building?',
    'Use Grievances to describe the concern. You can follow its status from Open to In progress to Resolved.'
  ],
];
