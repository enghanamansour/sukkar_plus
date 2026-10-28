import '../models/followup.dart';

/// Builds the minimal, pseudonymous event sent to automation (Make.com) when a
/// follow-up request is submitted. It intentionally excludes names, IDs,
/// dates of birth, metric values, laboratory values and report contents.
/// The Edge Function builds the identical payload server-side (see
/// supabase/functions/_shared/payload.ts) and is the only component allowed
/// to call the real webhook.
Map<String, Object?> buildFollowUpEventPayload(FollowUpRequest r, {required bool demo, String eventType = 'followup.submitted'}) => {
      'schema_version': 1,
      'event_type': eventType,
      'request_ref': r.pseudoId,
      'status': r.status.wireName,
      'trigger_type': r.trigger.wireName,
      'rule_ids': [...r.ruleIds]..sort(),
      'rules_version': r.rulesVersion,
      'submitted_at': r.updatedAt.toUtc().toIso8601String(),
      'environment': demo ? 'demo' : 'live',
    };

/// Keys that must never appear in an automation payload. Checked by tests and
/// by the server-side builder.
const forbiddenPayloadKeys = {
  'name',
  'display_name',
  'national_id',
  'dob',
  'date_of_birth',
  'email',
  'phone',
  'user_id',
  'metrics',
  'snapshot',
  'labs',
  'pdf',
  'report',
};

class DispatchResult {
  const DispatchResult({required this.state, required this.adapterName, required this.isMock, this.errorAr, this.duplicate = false});
  final DispatchState state;
  final String adapterName;
  final bool isMock;
  final String? errorAr;

  /// True when the idempotency key had already been dispatched.
  final bool duplicate;
}

abstract class FollowUpNotifier {
  String get adapterName;
  bool get isMock;
  Future<DispatchResult> notify(Map<String, Object?> payload, {required String idempotencyKey});
}

class RecordedEvent {
  const RecordedEvent(this.idempotencyKey, this.payload, this.at);
  final String idempotencyKey;
  final Map<String, Object?> payload;
  final DateTime at;
}

/// Local mock: records events in memory and clearly identifies itself as a
/// mock. Idempotent on [idempotencyKey]. No network access.
class MockFollowUpNotifier implements FollowUpNotifier {
  MockFollowUpNotifier({DateTime Function()? clock, this.failNext = false}) : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  final List<RecordedEvent> events = [];
  final Map<String, DispatchResult> _byKey = {};

  /// Test hook to simulate a failure on the next call.
  bool failNext;

  @override
  String get adapterName => 'local-mock';

  @override
  bool get isMock => true;

  @override
  Future<DispatchResult> notify(Map<String, Object?> payload, {required String idempotencyKey}) async {
    final prior = _byKey[idempotencyKey];
    if (prior != null && prior.state != DispatchState.failed) {
      return DispatchResult(state: prior.state, adapterName: adapterName, isMock: true, duplicate: true);
    }
    for (final k in payload.keys) {
      if (forbiddenPayloadKeys.contains(k)) {
        throw ArgumentError('Payload contains forbidden key "$k"');
      }
    }
    if (failNext) {
      failNext = false;
      final r = DispatchResult(state: DispatchState.failed, adapterName: adapterName, isMock: true, errorAr: 'فشل محاكى في المحاكي المحلي.');
      _byKey[idempotencyKey] = r;
      return r;
    }
    events.add(RecordedEvent(idempotencyKey, Map.unmodifiable(payload), _clock()));
    final r = DispatchResult(state: DispatchState.mockRecorded, adapterName: adapterName, isMock: true);
    _byKey[idempotencyKey] = r;
    return r;
  }
}
