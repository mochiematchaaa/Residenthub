import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangePayload, RealtimeSubscribeStatus, Supabase, SupabaseClient;

import '../core/core.dart';
import 'supabase_config.dart';

/// Keeps payments and motor parking the same in the app and on the website.
///
/// Both sides read and write one table (shared_records) in Supabase and listen for changes,
/// so a payment sent from the website shows up for the administrator in the app within about a
/// second, and a slot assigned in the app shows as taken on the website.
/// Until supabase_config.dart is filled in, this does nothing and the app works on its own.

enum CloudState { off, connecting, live, problem }

class _Row {
  final String kind, id;
  final Map<String, dynamic> value;
  const _Row(this.kind, this.id, this.value);
  String get key => '$kind|$id';
}

class CloudSync extends ChangeNotifier {
  static const _table = 'shared_records';
  static const _kinds = ['proof', 'slot', 'request', 'setting'];

  // Fields each kind of record carries. Anything else a newer website adds is ignored here.
  static const _fields = <String, Set<String>>{
    'proof': {
      'id', 'unit', 'payer', 'forText', 'method', 'reference', 'amount', 'date',
      'status', 'receiptNo', 'confirmedOn', 'direct'
    },
    'slot': {'unit'},
    'request': {'unit', 'who', 'when', 'at'},
    'setting': {'rate'},
  };

  CloudState state = CloudState.off;
  String detail = '';

  SupabaseClient? _client;
  final Map<String, _Row> _known = {}; // what the database holds, as far as we know
  bool _ready = false, _pushing = false, _pushAgain = false, _applyAfterPush = false;
  Timer? _pushTimer, _retryTimer;

  void _set(CloudState s, String text) {
    state = s;
    detail = text;
    notifyListeners();
  }

  Future<void> start() async {
    if (!cloudConfigured || _client != null) return;
    _set(CloudState.connecting, 'Connecting…');
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      _client = Supabase.instance.client;
    } catch (e) {
      _set(CloudState.problem, 'Could not start live updates. Check the URL and key.');
      debugPrint('ResidentHub sync: $e');
      return;
    }
    app.addListener(_schedulePush);
    _client!
        .channel('residenthub-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: _onChange,
        )
        .subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _pull();
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        _set(CloudState.problem, 'Live updates paused. Reconnecting…');
      }
    });
  }

  // ------------------------------------------------------------ reading

  Future<void> _pull() async {
    try {
      final data = await _client!.from(_table).select('kind,id,value').inFilter('kind', _kinds);
      _known.clear();
      var hasSlots = false;
      for (final r in data) {
        final row = _fromDb(r);
        if (row == null) continue;
        _known[row.key] = row;
        if (row.kind == 'slot') hasSlots = true;
      }
      // A new, empty project: the first device in saves the starting layout.
      if (hasSlots) {
        _apply();
      } else {
        _mergeProofsOnly();
      }
      _ready = true;
      await _pushDiff(force: true);
      if (state != CloudState.problem) _set(CloudState.live, 'Live · connected');
    } catch (e) {
      debugPrint('ResidentHub sync: $e');
      _set(CloudState.problem, 'Could not read the shared records. Run the SQL setup first.');
    }
  }

  _Row? _fromDb(Map<String, dynamic> r) {
    final kind = r['kind']?.toString();
    final id = r['id']?.toString();
    if (kind == null || id == null || !_kinds.contains(kind)) return null;
    final v = r['value'];
    return _Row(kind, id, v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{});
  }

  void _onChange(PostgresChangePayload p) {
    final isDelete = p.eventType == PostgresChangeEvent.delete;
    final row = _fromDb(isDelete ? p.oldRecord : p.newRecord);
    if (row == null) return;
    if (isDelete) {
      _known.remove(row.key);
    } else {
      _known[row.key] = row;
    }
    if (!_ready) return; // the first pull reads everything anyway
    if (_pushTimer?.isActive == true || _pushing) {
      // We have a change of our own on its way: send it first, then apply, so it is not lost.
      _applyAfterPush = true;
      return;
    }
    _apply();
  }

  void _mergeProofsOnly() {
    final list = <PaymentProof>[];
    for (final r in _known.values.where((r) => r.kind == 'proof')) {
      final p = PaymentProof.fromJson(r.value);
      if (p != null) list.add(p);
    }
    app.applyCloudProofs(list);
  }

  /// Update the app so it matches what the database holds.
  void _apply() {
    _mergeProofsOnly();
    final slotUnits = <String, String>{};
    final requests = <ParkingReq>[];
    num? rate;
    for (final r in _known.values) {
      if (r.kind == 'slot') {
        slotUnits[r.id] = (r.value['unit'] ?? '').toString();
      } else if (r.kind == 'request') {
        final at = r.value['at'];
        requests.add(ParkingReq(
          (r.value['unit'] ?? r.id).toString(),
          (r.value['who'] ?? '').toString(),
          when: (r.value['when'] ?? 'Just now').toString(),
          at: at is num ? at.toInt() : 0,
        ));
      } else if (r.kind == 'setting' && r.id == 'motor_rate') {
        final v = r.value['rate'];
        if (v is num) rate = v;
      }
    }
    if (slotUnits.isNotEmpty) app.applyCloudParking(slotUnits, requests, rate);
  }

  // ------------------------------------------------------------ writing

  List<_Row> _localRows() => [
        for (final p in app.proofs) _Row('proof', '${p.id}', p.toJson()),
        for (final s in app.slots) _Row('slot', s.id, {'unit': s.unit}),
        // A request that has been given a slot is no longer waiting, so it leaves the shared list.
        for (final r in app.parking.where((r) => !r.confirmed))
          _Row('request', r.unit, {'unit': r.unit, 'who': r.name, 'when': r.when, 'at': r.at}),
        _Row('setting', 'motor_rate', {'rate': app.motorRate}),
      ];

  void _schedulePush() {
    if (!_ready) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(milliseconds: 150), () => _pushDiff());
  }

  /// A comparable form of a record: only the fields we know, with empty values left out.
  String _canon(String kind, Map<String, dynamic> v) {
    final keep = _fields[kind] ?? const <String>{};
    final m = <String, dynamic>{};
    for (final k in keep) {
      final x = v[k];
      if (x == null || x == '' || x == false) continue;
      m[k] = x;
    }
    return _stable(m);
  }

  String _stable(dynamic v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return '{${keys.map((k) => '${jsonEncode(k)}:${_stable(v[k])}').join(',')}}';
    }
    if (v is List) return '[${v.map(_stable).join(',')}]';
    if (v is num) return (v.isFinite && v == v.truncate()) ? v.truncate().toString() : v.toString();
    return jsonEncode(v);
  }

  Future<void> _pushDiff({bool force = false}) async {
    if (_client == null || (!_ready && !force)) return;
    if (_pushing) {
      _pushAgain = true;
      return;
    }
    _pushing = true;
    var failed = false;
    try {
      final want = {for (final r in _localRows()) r.key: r};
      final upserts = <_Row>[];
      for (final e in want.entries) {
        final k = _known[e.key];
        if (k == null || _canon(k.kind, k.value) != _canon(e.value.kind, e.value.value)) {
          upserts.add(e.value);
        }
      }
      // Only waiting parking requests are ever removed from the shared list by the app.
      final deletes = _known.values.where((r) => r.kind == 'request' && !want.containsKey(r.key)).toList();
      if (upserts.isNotEmpty) {
        await _client!.from(_table).upsert([
          for (final r in upserts) {'kind': r.kind, 'id': r.id, 'value': r.value}
        ], onConflict: 'kind,id');
        for (final r in upserts) {
          _known[r.key] = r;
        }
      }
      for (final r in deletes) {
        await _client!.from(_table).delete().eq('kind', r.kind).eq('id', r.id);
        _known.remove(r.key);
      }
      if (state != CloudState.live) _set(CloudState.live, 'Live · connected');
    } catch (e) {
      failed = true;
      debugPrint('ResidentHub sync: $e');
      _set(CloudState.problem, 'Sync problem · retrying');
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 4), () => _pushDiff());
    } finally {
      _pushing = false;
      if (_pushAgain) {
        _pushAgain = false;
        unawaited(_pushDiff());
      } else if (_applyAfterPush && !failed && _pushTimer?.isActive != true) {
        _applyAfterPush = false;
        _apply();
      }
    }
  }
}

final CloudSync cloud = CloudSync();

/// A small line that says whether live updates with the website are working.
/// Shows nothing when the app runs on its own.
class CloudStatusLine extends StatelessWidget {
  const CloudStatusLine({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cloud,
      builder: (context, _) {
        if (cloud.state == CloudState.off) return const SizedBox.shrink();
        final good = cloud.state == CloudState.live;
        final bad = cloud.state == CloudState.problem;
        final color = good
            ? const Color(0xFF2E7D32)
            : bad
                ? const Color(0xFFC62828)
                : const Color(0xFF8A6D00);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(bad ? Icons.sync_problem_rounded : Icons.sync_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text('Website sync: ${cloud.detail}',
                    style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }
}
