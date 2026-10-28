import 'dart:math';

import 'package:sukkar_core/sukkar_core.dart';

/// camelCase enum name → snake_case wire value (matches the SQL checks).
String wire(Enum e) => e.name.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

T fromWire<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final v in values) {
    if (wire(v) == raw) return v;
  }
  return fallback;
}

DateTime? parseDate(Object? raw) => raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
String? dateOnlyWire(DateTime? d) => d == null ? null : isoDate(d);
double? numOrNull(Object? raw) => raw is num ? raw.toDouble() : (raw is String ? double.tryParse(raw) : null);

final _rnd = Random.secure();

/// RFC 4122 version-4 UUID (used for client-generated primary keys).
String newUuid() {
  final b = List<int>.generate(16, (_) => _rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Short pseudonymous reference for display (e.g. "REQ-7Q2K9D").
String newPseudoRef(String prefix) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return '$prefix-${List.generate(6, (_) => alphabet[_rnd.nextInt(alphabet.length)]).join()}';
}

DataQuality qualityFromJson(Object? raw) {
  if (raw is! Map) {
    return const DataQuality(daysOfData: null, coveragePercent: null, coverageSource: 'غير معروف', sufficient: false, reasonsAr: ['لا تتوفر معلومات جودة البيانات.']);
  }
  return DataQuality(
    daysOfData: (raw['days_of_data'] as num?)?.toInt(),
    coveragePercent: numOrNull(raw['coverage_percent']),
    coverageSource: '${raw['coverage_source'] ?? ''}',
    sufficient: raw['sufficient'] == true,
    reasonsAr: [for (final r in (raw['reasons'] as List?) ?? const []) '$r'],
    duplicateReadings: (raw['duplicate_readings'] as num?)?.toInt() ?? 0,
    conflictingDuplicates: (raw['conflicting_duplicates'] as num?)?.toInt() ?? 0,
    invalidReadings: (raw['invalid_readings'] as num?)?.toInt() ?? 0,
    gapCount: (raw['gap_count'] as num?)?.toInt() ?? 0,
    longestGapMinutes: (raw['longest_gap_minutes'] as num?)?.toInt() ?? 0,
  );
}
