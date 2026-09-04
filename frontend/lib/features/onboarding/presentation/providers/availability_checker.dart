import 'package:apsbrat_frontend/features/onboarding/data/models/availability_model.dart';
import 'package:flutter/widgets.dart';

/// Checks one text field against the server once the user leaves it
/// (focus lost) and exposes the result for the UI.
///
///   checking  → a request is in flight
///   error     → server said "not available" — show this message, block Next
///   confirmed → server said "available" for the current text
class AvailabilityChecker extends ChangeNotifier {
  AvailabilityChecker({required this.controller, required this.fetch}) {
    focus.addListener(_onFocusChange);
    controller.addListener(_onTextChanged);
  }

  final TextEditingController controller;
  final Future<Availability> Function(String value) fetch;
  final focus = FocusNode();

  bool checking = false;
  String? error;
  bool confirmed = false;

  String? _lastChecked;
  Future<void>? _inFlight;
  bool _disposed = false;

  /// Runs the check for the current text. Skips if empty or already checked.
  Future<void> check() {
    // Share one request if Next is tapped while a blur-check is running.
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  /// True when the current value is allowed to go forward.
  Future<bool> passes() async {
    await check();
    return error == null;
  }

  Future<void> _run() async {
    final value = controller.text.trim();
    if (value.isEmpty || value == _lastChecked) return;

    checking = true;
    error = null;
    _notify();
    try {
      final result = await fetch(value);
      _lastChecked = value;
      confirmed = result.available;
      error = result.available ? null : result.message;
    } catch (_) {
      // Network problem: leave it unverified — registration re-checks anyway.
    }
    checking = false;
    _notify();
  }

  void _onFocusChange() {
    if (!focus.hasFocus) check();
  }

  void _onTextChanged() {
    if (error != null || confirmed) {
      error = null;
      confirmed = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(_onTextChanged);
    focus.dispose();
    super.dispose();
  }
}
