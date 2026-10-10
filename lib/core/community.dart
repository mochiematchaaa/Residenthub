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

List<Poll> seedPolls() => [
      Poll(1, 'Repaint the ground-floor lobby this year?', true, 'Oct 20, 2026', [
        PollOption('Yes, repaint now', 31),
        PollOption('Wait until next year', 9),
        PollOption('No repaint needed', 4),
      ]),
      Poll(2, 'Which weekday should the pool be closed for cleaning?', true, 'Oct 25, 2026', [
        PollOption('Monday', 18),
        PollOption('Wednesday', 7),
        PollOption('Thursday', 12),
      ]),
      Poll(3, 'Add a second coffee-lounge hour in the afternoon?', false, 'Sep 15, 2026', [
        PollOption('Yes', 38),
        PollOption('No', 6),
      ]),
    ];

/// One motor parking slot. [unit] is empty when the slot is free.
class ParkingSlot {
  final String id;
  String unit;
  ParkingSlot(this.id, [this.unit = '']);
  bool get used => unit.isNotEmpty;
}

List<ParkingSlot> seedSlots() {
  const units = [
    'Unit 12A', 'Unit 7C', 'Unit 3B', 'Unit 15D', 'Unit 9A', 'Unit 21B', 'Unit 18C',
    'Unit 6B', 'Unit 2A', 'Unit 8C', 'Unit 10D', 'Unit 14A', 'Unit 17B',
  ];
  return [
    for (var i = 0; i < 24; i++) ParkingSlot('M-${(i + 1).toString().padLeft(2, '0')}', i < units.length ? units[i] : ''),
  ];
}

// ---------------------------------------------------------------- directory

class ContactInfo {
  final String name, note, tel;
  const ContactInfo(this.name, this.note, this.tel);
}

const directoryContacts = [
  ContactInfo('Security desk', 'Open 24 hours · Gate and lobby', 'Local 101'),
  ContactInfo('Administration office', 'Mon–Sat, 8 AM – 5 PM · Dues, bookings, documents', 'Local 102'),
  ContactInfo('Maintenance', 'Repairs in common areas · Report through Grievances', 'Local 103'),
  ContactInfo('Emergency hotline', 'Fire, police or medical emergencies', '911'),
];

const houseRules = [
  ['Swimming pool', 'Open 6:00 AM – 8:00 PM. Shower before entering and keep glass out of the pool area.'],
  ['Function Hall', 'Open 8:00 AM – 10:00 PM. Book ahead, and leave the hall clean for the next group.'],
  ['Quiet hours', 'Please keep noise low from 10:00 PM to 6:00 AM, including music and renovation work.'],
  ['Common areas', 'No smoking inside the building. Keep hallways, stairs and the lobby clear.'],
  ['Pets', 'Pets stay on a leash in common areas, and owners clean up after them.'],
  ['Garbage', 'Bag and tie your waste, and use the designated disposal area only.'],
];

const directoryFaq = [
  [
    'How do I book the pool or the Function Hall?',
    'Open Book, pick the place, tap an open time slot and send your request. The office approves it and you will see the result under My reservations.'
  ],
  ['When are monthly dues due?', 'Dues are due on the 15th of every month. Your balance and history are under Dues.'],
  [
    'I rent out my unit. What do I need to do?',
    'Open Unit status and tell us how your unit is used. Long-term leases are saved right away. Short-term rentals and home businesses need the administrator\'s approval.'
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
