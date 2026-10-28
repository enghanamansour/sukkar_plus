// Pure Dart (no Flutter): checks that every enum value the app writes to
// Supabase is allowed by the CHECK constraints in the SQL migration, so a
// mismatch is caught here rather than at runtime in live mode.
import 'dart:io';

import 'package:sukkar_core/sukkar_core.dart';
import 'package:sukkar_plus/data/supabase/wire.dart';
import 'package:test/test.dart';

String _schema() {
  for (final p in ['../supabase/migrations/20261028000001_schema.sql', 'supabase/migrations/20261028000001_schema.sql']) {
    final f = File(p);
    if (f.existsSync()) return f.readAsStringSync();
  }
  throw StateError('schema migration not found');
}

/// Values allowed by `check (<column> in ('a', 'b'))` inside `create table <table>`.
Set<String> allowed(String sql, String table, String column) {
  final start = sql.indexOf('create table public.$table (');
  if (start < 0) throw StateError('table $table not found');
  final end = sql.indexOf('\n);', start);
  final body = sql.substring(start, end);
  final m = RegExp('check \\($column in \\(([^)]*)\\)\\)').firstMatch(body);
  if (m == null) throw StateError('check for $table.$column not found');
  return RegExp("'([^']+)'").allMatches(m.group(1)!).map((x) => x.group(1)!).toSet();
}

void main() {
  final sql = _schema();

  void same(String table, String column, Iterable<String> dart) {
    expect(dart.toSet(), equals(allowed(sql, table, column)), reason: '$table.$column');
  }

  test('wire() converts camelCase enum names to snake_case', () {
    expect(wire(TargetProfile.generalAdultT1T2), 'general_adult_t1_t2');
    expect(wire(ValueOrigin.calculatedFromReadings), 'calculated_from_readings');
    expect(fromWire(LabTestCode.values, 'fasting_plasma_glucose', LabTestCode.other), LabTestCode.fastingPlasmaGlucose);
    expect(fromWire(LabTestCode.values, 'unknown', LabTestCode.other), LabTestCode.other);
  });

  test('profiles', () => same('profiles', 'target_profile', TargetProfile.values.map(wire)));
  test('device_reports', () {
    same('device_reports', 'provenance', DataProvenance.values.map(wire));
    same('device_reports', 'source_type', ReportSourceType.values.map(wire));
  });
  test('verified_metrics', () {
    same('verified_metrics', 'origin', ValueOrigin.values.map(wire));
    same('verified_metrics', 'verification_status', VerificationStatus.values.map(wire));
  });
  test('extracted_fields', () {
    same('extracted_fields', 'extraction_status', ExtractionStatus.values.map(wire));
    same('extracted_fields', 'validation_status', FieldValidation.values.map(wire));
    same('extracted_fields', 'method', ExtractionMethod.values.map(wire));
  });
  test('lab_results', () {
    same('lab_results', 'test_code', LabTestCode.values.map(wire));
    same('lab_results', 'source', LabSource.values.map(wire));
    same('lab_results', 'verification_status', VerificationStatus.values.map(wire));
  });
  test('test_reminders', () {
    same('test_reminders', 'schedule_source', ScheduleSource.values.map(wire));
    same('test_reminders', 'status', ReminderStatus.values.map(wire));
  });
  test('analysis_runs', () => same('analysis_runs', 'outcome', ReviewOutcome.values.map((o) => o.wireName)));
  test('followup_requests', () {
    same('followup_requests', 'status', FollowUpStatus.values.map((s) => s.wireName));
    same('followup_requests', 'decision', ReviewDecision.values.map((d) => d.wireName));
    same('followup_requests', 'trigger_type', FollowUpTrigger.values.map((t) => t.wireName));
  });
  test('metric keys are snake_case and unique', () {
    final names = MetricKey.values.map((k) => k.wireName).toList();
    expect(names.toSet(), hasLength(names.length));
    expect(names.every((n) => RegExp(r'^[a-z_]+$').hasMatch(n)), isTrue);
  });
  test('client-generated ids are valid UUID v4', () {
    final re = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    for (var i = 0; i < 50; i++) {
      expect(re.hasMatch(newUuid()), isTrue);
    }
    expect(newPseudoRef('REQ'), matches(RegExp(r'^REQ-[A-Z2-9]{6}$')));
  });
  test('quality JSON round-trips', () {
    const q = DataQuality(daysOfData: 14, coveragePercent: 88.5, coverageSource: 'x', sufficient: true, reasonsAr: ['a'], gapCount: 2);
    final back = qualityFromJson(q.toJson());
    expect(back.daysOfData, 14);
    expect(back.coveragePercent, 88.5);
    expect(back.sufficient, isTrue);
    expect(back.gapCount, 2);
    expect(qualityFromJson(null).sufficient, isFalse);
  });
}
