import 'dart:async';

import 'package:flutter/services.dart';

/// Listens for volume-down button presses and detects a triple-press pattern.
/// Calls [onTriplePress] when 3 presses are detected within [timeWindow].
class VolumeButtonService {
  static const _eventChannel = EventChannel('com.example.safeher/volume_events');

  /// How many presses needed to trigger SOS.
  static const int requiredPresses = 3;

  /// Time window within which all presses must occur.
  static const Duration timeWindow = Duration(seconds: 2);

  final VoidCallback onTriplePress;

  StreamSubscription? _subscription;
  final List<DateTime> _pressTimestamps = [];

  VolumeButtonService({required this.onTriplePress});

  /// Start listening for volume button presses.
  void start() {
    _subscription = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event == 'volume_down') {
        _onVolumeDown();
      }
    });
  }

  /// Stop listening.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _pressTimestamps.clear();
  }

  void _onVolumeDown() {
    final now = DateTime.now();

    // Remove presses that are outside the time window
    _pressTimestamps.removeWhere(
      (t) => now.difference(t) > timeWindow,
    );

    _pressTimestamps.add(now);

    if (_pressTimestamps.length >= requiredPresses) {
      _pressTimestamps.clear(); // reset after triggering
      onTriplePress();
    }
  }
}
