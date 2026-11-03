import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Debug-only logging for the Firebase phone sign-in flow.
///
/// Each step is collected with [event]; [flush] then prints the whole flow as
/// one pretty JSON object to the IDE debug console (via `dart:developer`, so it
/// is not split into `flutter:` lines or truncated). Values include tokens, so
/// nothing is collected or printed outside debug builds.
abstract final class AuthLog {
  static const _name = '🔐 AUTH';

  static const _encoder = JsonEncoder.withIndent('  ', _toEncodable);

  static final Map<String, Object?> _steps = {};

  /// Clears the collected steps; call when a new sign-in starts.
  static void start() {
    if (kDebugMode) _steps.clear();
  }

  /// Records one step of the flow under [title].
  static void event(String title, [Map<String, Object?> fields = const {}]) {
    if (!kDebugMode) return;
    var key = title;
    // Keep repeated steps (e.g. a second wrong code) instead of overwriting.
    for (var i = 2; _steps.containsKey(key); i++) {
      key = '$title #$i';
    }
    _steps[key] = fields;
  }

  /// Prints everything recorded so far as one JSON object, then clears it.
  static void flush(String outcome) {
    if (!kDebugMode || _steps.isEmpty) return;
    final json = _encoder.convert({'outcome': outcome, 'steps': _steps});
    developer.log(json, name: _name);
    _steps.clear();
  }

  /// Makes Firebase values (dates, enums, exceptions) JSON-safe.
  static Object? _toEncodable(Object? value) {
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Map) {
      return value.map((k, v) => MapEntry('$k', v));
    }
    return '$value';
  }
}
