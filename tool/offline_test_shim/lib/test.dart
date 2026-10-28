/// Minimal, dependency-free stand-in for a subset of `package:test`.
///
/// Used ONLY to execute the sukkar_core test suite in environments where
/// pub.dev is unreachable (the sandbox this project was built in). On a normal
/// machine run `dart test` in packages/sukkar_core, which uses the real
/// package:test. See tool/run_core_tests_offline.sh.
library;

import 'dart:async';
import 'dart:io';

typedef _Body = FutureOr<void> Function();

class _Test {
  _Test(this.name, this.body, this.setUps, this.tearDowns);
  final String name;
  final _Body body;
  final List<_Body> setUps;
  final List<_Body> tearDowns;
}

final _tests = <_Test>[];
final _groupStack = <String>[];
final _setUpStack = <List<_Body>>[[]];
final _tearDownStack = <List<_Body>>[[]];
var _scheduled = false;
final _pending = <Future<void>>[];

void group(String name, void Function() body) {
  _groupStack.add(name);
  _setUpStack.add([]);
  _tearDownStack.add([]);
  body();
  _setUpStack.removeLast();
  _tearDownStack.removeLast();
  _groupStack.removeLast();
}

void setUp(_Body f) => _setUpStack.last.add(f);
void tearDown(_Body f) => _tearDownStack.last.add(f);

void test(String name, _Body body, {Object? skip}) {
  if (skip != null && skip != false) return;
  final full = [..._groupStack, name].join(' › ');
  _tests.add(_Test(full, body, [for (final s in _setUpStack) ...s], [for (final t in _tearDownStack.reversed) ...t]));
  if (!_scheduled) {
    _scheduled = true;
    Timer.run(_runAll);
  }
}

Future<void> _runAll() async {
  var passed = 0;
  final failures = <String>[];
  for (final t in _tests) {
    try {
      for (final s in t.setUps) {
        await s();
      }
      await t.body();
      while (_pending.isNotEmpty) {
        await _pending.removeAt(0);
      }
      for (final td in t.tearDowns) {
        await td();
      }
      passed++;
      stdout.writeln('  ✓ ${t.name}');
    } catch (e, st) {
      for (final p in _pending) {
        p.ignore();
      }
      _pending.clear();
      failures.add(t.name);
      stdout.writeln('  ✗ ${t.name}\n      $e\n${st.toString().split('\n').take(4).map((l) => '      $l').join('\n')}');
    }
  }
  stdout.writeln('\n${_tests.length} tests: $passed passed, ${failures.length} failed.');
  exitCode = failures.isEmpty ? 0 : 1;
}

class TestFailure implements Exception {
  TestFailure(this.message);
  final String message;
  @override
  String toString() => 'TestFailure: $message';
}

// ------------------------------------------------------------------ matchers

abstract class Matcher {
  const Matcher();
  bool matches(Object? actual);
  String describe();
}

class _Pred extends Matcher {
  const _Pred(this._f, this._d);
  final bool Function(Object?) _f;
  final String _d;
  @override
  bool matches(Object? a) => _f(a);
  @override
  String describe() => _d;
}

bool _deepEq(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEq(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Set && b is Set) return a.length == b.length && a.containsAll(b);
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_deepEq(a[k], b[k])) return false;
    }
    return true;
  }
  return a == b;
}

Matcher equals(Object? expected) => _Pred((a) => _deepEq(a, expected), 'equals $expected');
const Matcher isTrue = _Pred(_isTrue, 'is true');
const Matcher isFalse = _Pred(_isFalse, 'is false');
const Matcher isNull = _Pred(_isNull, 'is null');
const Matcher isNotNull = _Pred(_isNotNull, 'is not null');
const Matcher isEmpty = _Pred(_isEmpty, 'is empty');
const Matcher isNotEmpty = _Pred(_isNotEmpty, 'is not empty');
bool _isTrue(Object? a) => a == true;
bool _isFalse(Object? a) => a == false;
bool _isNull(Object? a) => a == null;
bool _isNotNull(Object? a) => a != null;
bool _isEmpty(Object? a) => (a is Iterable && a.isEmpty) || (a is Map && a.isEmpty) || (a is String && a.isEmpty);
bool _isNotEmpty(Object? a) => !_isEmpty(a) && a != null;

Matcher closeTo(num value, num delta) => _Pred((a) => a is num && (a - value).abs() <= delta, 'within $delta of $value');
Matcher greaterThan(num v) => _Pred((a) => a is num && a > v, 'greater than $v');
Matcher lessThan(num v) => _Pred((a) => a is num && a < v, 'less than $v');
Matcher greaterThanOrEqualTo(num v) => _Pred((a) => a is num && a >= v, '>= $v');
Matcher lessThanOrEqualTo(num v) => _Pred((a) => a is num && a <= v, '<= $v');
Matcher hasLength(int n) => _Pred((a) => (a is Iterable && a.length == n) || (a is Map && a.length == n) || (a is String && a.length == n), 'has length $n');
Matcher contains(Object? x) => _Pred(
    (a) => (a is String && x is String && a.contains(x)) || (a is Iterable && a.any((e) => _deepEq(e, x))) || (a is Map && a.containsKey(x)),
    'contains $x');
Matcher matches(Pattern p) => _Pred((a) => a is String && (p is RegExp ? p.hasMatch(a) : a.contains(p)), 'matches $p');
Matcher isA<T>() => _Pred((a) => a is T, 'is a $T');
Matcher predicate(bool Function(dynamic) f, [String d = 'satisfies predicate']) => _Pred((a) => f(a), d);
Matcher anyElement(Object? m) => _Pred((a) => a is Iterable && a.any((e) => _wrap(m).matches(e)), 'any element ${_wrap(m).describe()}');
Matcher everyElement(Object? m) => _Pred((a) => a is Iterable && a.every((e) => _wrap(m).matches(e)), 'every element ${_wrap(m).describe()}');
Matcher isNot(Object? m) => _Pred((a) => !_wrap(m).matches(a), 'not ${_wrap(m).describe()}');
Matcher allOf(Object? a, Object? b, [Object? c]) =>
    _Pred((x) => _wrap(a).matches(x) && _wrap(b).matches(x) && (c == null || _wrap(c).matches(x)), 'all of');

class _Throws extends Matcher {
  const _Throws(this.inner);
  final Matcher? inner;
  @override
  bool matches(Object? a) => throw UnsupportedError('handled in expect');
  @override
  String describe() => 'throws ${inner?.describe() ?? ''}';
}

Matcher throwsA(Object? m) => _Throws(_wrap(m));
const Matcher throwsArgumentError = _Throws(_Pred(_isArgErr, 'ArgumentError'));
const Matcher throwsStateError = _Throws(_Pred(_isStateErr, 'StateError'));
bool _isArgErr(Object? e) => e is ArgumentError;
bool _isStateErr(Object? e) => e is StateError;

Matcher _wrap(Object? m) => m is Matcher ? m : equals(m);

void expect(Object? actual, Object? matcher, {String? reason}) {
  final m = _wrap(matcher);
  if (m is _Throws) {
    if (actual is! Function) throw TestFailure('expected a function for throws matcher');
    Object? result;
    try {
      result = (actual as dynamic)();
    } catch (e) {
      if (m.inner == null || m.inner!.matches(e)) return;
      throw TestFailure('threw $e which does not match ${m.inner!.describe()}${reason == null ? '' : ' ($reason)'}');
    }
    if (result is Future) {
      // Like package:test, an async closure is awaited before the test ends.
      _pending.add(result.then<void>(
        (_) => throw TestFailure('expected future to throw ${m.describe()}${reason == null ? '' : ' ($reason)'}'),
        onError: (Object e) {
          if (e is TestFailure) throw e;
          if (m.inner == null || m.inner!.matches(e)) return;
          throw TestFailure('threw $e which does not match ${m.inner!.describe()}');
        },
      ));
      return;
    }
    throw TestFailure('expected to throw ${m.describe()}${reason == null ? '' : ' ($reason)'}');
  }
  if (!m.matches(actual)) {
    throw TestFailure('expected ${m.describe()} but was $actual${reason == null ? '' : ' ($reason)'}');
  }
}

Future<void> expectLater(Future<Object?> actual, Object? matcher) async {
  final m = _wrap(matcher);
  if (m is _Throws) {
    try {
      await actual;
    } catch (e) {
      if (m.inner == null || m.inner!.matches(e)) return;
      throw TestFailure('threw $e which does not match ${m.inner!.describe()}');
    }
    throw TestFailure('expected future to throw');
  }
  expect(await actual, m);
}
