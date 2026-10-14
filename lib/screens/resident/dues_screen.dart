import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../shared/payment_widgets.dart';
import 'resident_screens.dart';

class ResDues extends StatelessWidget {
  const ResDues({super.key});

  void _sendProof(BuildContext context) {
    final online = [
      for (final m in app.enabledPayMethods)
        if (m.name != AppState.officePay) m.name,
    ];
    if (online.isEmpty) {
      msg(context, 'Online payment options are not set up yet. Please pay at the office.');
      return;
    }
    showFormSheet(
      context,
      title: 'Send payment proof',
      subtitle: 'Enter the reference number from your payment receipt. The administrator will check it and record your payment.',
      choices: [ChoiceSpec('method', 'Paid through', online, online.first)],
      fields: [
        const FieldSpec('ref', 'Reference no.', hint: 'From your GCash / Maya / bank receipt'),
        FieldSpec('amount', 'Amount paid (₱)', type: TextInputType.number, initial: app.myBalance > 0 ? app.myBalance.toStringAsFixed(2) : ''),
      ],
      submit: 'Send',
      onSubmit: (v) {
        final err = app.submitProof(v['method'] as String, v['ref'] as String, v['amount'] as String);
        if (err == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) msg(context, 'Sent. The administrator will confirm your payment.');
          });
        }
        return err;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = app.myDueRows;
    return TabPage(
      title: 'Dues & payment',
      subtitle: 'Your monthly charges and outstanding balance.',
      children: [
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Outstanding balance', style: TextStyle(color: muted(context), fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(peso(app.myBalance), style: hd(34, color: app.myBalance > 0 ? danger : const Color(0xFF2B5636))),
              const SizedBox(height: 8),
              Text(
                'Pay using one of the options below, then send your reference number. The administrator records it and your receipt appears here.',
                style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.45),
              ),
            ],
          ),
        ),
        if (rows.isEmpty) const EmptyBox('No charges have been billed to your unit yet.', icon: Icons.receipt_long_outlined),
        if (rows.isNotEmpty)
        RCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
                ListTile(
                  leading: IconBadge(rows[i].status == 'Paid' ? Icons.check_rounded : Icons.schedule_rounded, tone: toneForStatus(rows[i].status), size: 38),
                  title: Text(rows[i].month, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(rows[i].due == 'upon receipt' ? 'Due upon receipt' : 'Due ${rows[i].due}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(peso(rows[i].amt), style: hd(15)),
                      const SizedBox(height: 4),
                      Pill(rows[i].status),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const IconBadge(Icons.account_balance_wallet_outlined, accent: true),
                const SizedBox(width: 12),
                Expanded(child: Text('How to pay', style: hd(17))),
              ]),
              const SizedBox(height: 10),
              if (app.enabledPayMethods.isEmpty)
                Text('Payment options will be posted by the administrator.', style: TextStyle(color: muted(context), fontSize: 13)),
              for (final m in app.enabledPayMethods)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(payIcon(m.name), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(m.details, style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.45)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 2),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _sendProof(context),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('I have paid - send reference no.'),
                ),
              ),
            ],
          ),
        ),
        if (app.myProofs.isNotEmpty)
          RCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Align(alignment: Alignment.centerLeft, child: Text('Payment proofs sent', style: hd(17))),
                ),
                for (final p in app.myProofs)
                  ListTile(
                    title: Text('${p.method} · ${peso(p.amount)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('Ref. ${p.reference} · ${p.date}'),
                    trailing: Pill(p.status),
                  ),
              ],
            ),
          ),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const IconBadge(Icons.receipt_long_outlined, accent: true),
                const SizedBox(width: 12),
                Expanded(child: Text('Receipts', style: hd(17))),
              ]),
              const SizedBox(height: 6),
              Text('Your proof of payment. Open a receipt to download it as Word or Excel.',
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 12),
              ReceiptList(app.myPayments),
              OutlinedButton.icon(
                onPressed: () => go(context, const ResFinanceDocs()),
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('Open finance documents'),
              ),
              if (app.myPayments.isNotEmpty) ...[
                const SizedBox(height: 4),
                HistoryExportButtons(
                  title: 'Payment history ${app.myUnit}',
                  list: () => app.myPayments,
                ),
              ],
            ],
          ),
        ),
        RCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const IconBadge(Icons.two_wheeler_rounded, accent: true),
                const SizedBox(width: 12),
                Expanded(child: Text('Motor parking rental', style: hd(17))),
              ]),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Rent a motor/motorcycle parking slot for '),
                  TextSpan(text: app.motorRate > 0 ? '${peso(app.motorRate)}/month' : 'the monthly rate', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const TextSpan(text: ". This rate isn't fixed and may change — check with the office for the latest amount."),
                ]),
                style: TextStyle(color: muted(context), fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('${app.slots.length - app.slotsUsed} of ${app.slots.length} slots free', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
                  Text('Green = free · Red = taken', style: TextStyle(color: muted(context), fontSize: 11.5)),
                ],
              ),
              const SizedBox(height: 8),
              if (app.slots.isEmpty)
                Text('The office has not set up motor parking slots yet.', style: TextStyle(color: muted(context), fontSize: 13)),
              if (app.slots.isNotEmpty)
              GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.7,
                children: [
                  for (final sl in app.slots)
                    Builder(builder: (context) {
                      final mine = sl.unit == app.myUnit;
                      final t = toneOf(context, sl.used ? Tone.bad : Tone.good);
                      return Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: mine ? lavDeep : t.bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(sl.id, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: mine ? Colors.white : t.fg)),
                      );
                    }),
                ],
              ),
              const SizedBox(height: 12),
              if (app.slotOf(app.myUnit) != null)
                Pill('Your slot: ${app.slotOf(app.myUnit)!.id}', tone: Tone.good)
              else if (app.parkingRequested)
                const Pill('Request sent — awaiting admin confirmation', tone: Tone.good)
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      app.requestParking();
                      msg(context, 'Parking slot request sent to the administrator.');
                    },
                    child: const Text('Request a parking slot'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
