import 'app_state.dart' show peso;
import 'doc_model.dart';

/// A way residents can pay their dues (shown under Dues & payment).
/// The details are sample text - the administrator edits them in Finance.
class PayMethod {
  final String name;
  String details;
  bool enabled;
  PayMethod(this.name, this.details, {this.enabled = true});
}

/// A payment the administrator has recorded. This is the proof of payment
/// (receipt) that can be opened and downloaded as Word or Excel.
class PaymentRecord {
  final int id;
  final String receiptNo, unit, payer, forText, method, reference, date;
  final num amount;
  const PaymentRecord(this.id, this.receiptNo, this.unit, this.payer,
      this.forText, this.method, this.reference, this.date, this.amount);

  /// The date paid, read back from [date] (e.g. "Aug 12, 2026").
  DateTime get when {
    final m = RegExp(r'^([A-Za-z]{3}) (\d{1,2}), (\d{4})$').firstMatch(date);
    if (m == null) return DateTime.fromMillisecondsSinceEpoch(0);
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return DateTime(int.parse(m[3]!), names.indexOf(m[1]!) + 1, int.parse(m[2]!));
  }
}

/// A resident's "I have paid" message with the reference number, waiting for
/// the administrator to check it.
class PaymentProof {
  final int id;
  final String unit, payer, method, reference, date;
  final num amount;
  String status; // Pending | Confirmed | Rejected
  PaymentProof(this.id, this.unit, this.payer, this.method, this.reference,
      this.date, this.amount,
      {this.status = 'Pending'});
}

/// One receipt as document blocks (shown in the viewer, exported to Word/Excel).
List<DocBlock> receiptBlocks(PaymentRecord p) => [
      const DocBlock.h1('Payment receipt'),
      const DocBlock.p('City Residences Condominium Corporation'),
      DocBlock.table([
        const ['Detail', 'Information'],
        ['Receipt no.', p.receiptNo],
        ['Date paid', p.date],
        ['Unit', p.unit],
        ['Received from', p.payer],
        ['Payment for', p.forText],
        ['Amount', peso(p.amount)],
        ['Payment method', p.method],
        ['Reference no.', p.reference],
        const ['Status', 'Paid'],
      ]),
      const DocBlock.p(
          'This receipt is your proof of payment. Keep a copy for your records.'),
    ];

/// A list of payments as document blocks (payment history export).
List<DocBlock> paymentHistoryBlocks(String title, List<PaymentRecord> list) {
  final total = list.fold<num>(0, (s, p) => s + p.amount);
  return [
    DocBlock.h1(title),
    const DocBlock.p('City Residences Condominium Corporation'),
    DocBlock.table([
      const [
        'Receipt no.', 'Date', 'Unit', 'Paid by', 'Payment for', 'Method', 'Reference no.', 'Amount'
      ],
      for (final p in list)
        [p.receiptNo, p.date, p.unit, p.payer, p.forText, p.method, p.reference, peso(p.amount)],
    ]),
    DocBlock.p('${list.length} payment${list.length == 1 ? '' : 's'} - total ${peso(total)}'),
  ];
}
