import 'dart:async';

import 'package:flutter/foundation.dart';

/// Counts wrong-password attempts per email and locks that account out for a
/// cooldown once [maxAttempts] failures have been reached.
///
/// The guard is deliberately client-side and in-memory: it protects the login
/// form from casual retry storms and gives the user a clear countdown, while
/// Firebase Auth keeps enforcing its own server-side throttling. Restarting the
/// app starts from a clean slate, which is acceptable for a UX guard (it is
/// not a security boundary).
///
/// Only credential failures should be recorded — network errors or a malformed
/// email must not burn an attempt (see `AuthFailureKind`).
class LoginAttemptGuard extends ChangeNotifier {
  LoginAttemptGuard({
    this.maxAttempts = 3,
    this.lockDuration = const Duration(minutes: 1),
    DateTime Function()? clock,
  }) : assert(maxAttempts > 0),
       _clock = clock ?? DateTime.now;

  /// Wrong passwords allowed before the lock starts.
  final int maxAttempts;

  /// How long the form stays locked after the last allowed failure.
  final Duration lockDuration;

  /// Injectable so tests can move time forward without waiting.
  final DateTime Function() _clock;

  final Map<String, _Attempt> _attempts = <String, _Attempt>{};
  Timer? _ticker;

  /// Emails are compared the same way [AuthRepository.signIn] trims them, so
  /// `" A@B.com "` and `"a@b.com"` share one counter.
  static String _key(String email) => email.trim().toLowerCase();

  bool isLocked(String email) => remainingLock(email) > Duration.zero;

  /// Time left on the lock, or [Duration.zero] when the email is free to try.
  Duration remainingLock(String email) {
    final DateTime? until = _attempts[_key(email)]?.lockedUntil;
    if (until == null) return Duration.zero;
    final Duration left = until.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  /// Wrong passwords still allowed before the lock starts (0 while locked).
  int attemptsLeft(String email) {
    if (isLocked(email)) return 0;
    return maxAttempts - (_attempts[_key(email)]?.failures ?? 0);
  }

  /// Records one wrong password for [email], starting the cooldown when the
  /// third failure lands.
  void recordFailure(String email) {
    // A tap that arrives while the lock is active must not extend it.
    if (isLocked(email)) {
      notifyListeners();
      return;
    }

    final _Attempt attempt = _attempts.putIfAbsent(_key(email), _Attempt.new);
    attempt.lockedUntil = null; // an expired lock no longer applies
    attempt.failures += 1;

    if (attempt.failures >= maxAttempts) {
      attempt.lockedUntil = _clock().add(lockDuration);
      // A fresh set of attempts is granted once the cooldown ends.
      attempt.failures = 0;
      _startTicker();
    }
    notifyListeners();
  }

  /// A successful sign-in wipes the counter for that email.
  void recordSuccess(String email) {
    if (_attempts.remove(_key(email)) == null) return;
    _stopTickerIfIdle();
    notifyListeners();
  }

  /// Clears every counter (used when tests or a sign-out need a blank slate).
  void clear() {
    if (_attempts.isEmpty) return;
    _attempts.clear();
    _stopTickerIfIdle();
    notifyListeners();
  }

  void _startTicker() {
    if (_ticker != null) return;
    // Only ticks while a lock is running, so an idle login screen does no work.
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      final DateTime now = _clock();
      for (final _Attempt attempt in _attempts.values) {
        final DateTime? until = attempt.lockedUntil;
        if (until != null && !until.isAfter(now)) {
          attempt.lockedUntil = null;
        }
      }
      if (!_attempts.values.any((_Attempt a) => a.lockedUntil != null)) {
        _stopTickerIfIdle();
      }
      // Repaint the countdown (and re-enable the button on expiry).
      notifyListeners();
    });
  }

  void _stopTickerIfIdle() {
    if (_attempts.values.any((_Attempt a) => a.lockedUntil != null)) return;
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}

class _Attempt {
  int failures = 0;
  DateTime? lockedUntil;
}
