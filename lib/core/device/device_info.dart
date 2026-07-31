import 'package:flutter/services.dart';

/// Tiny wrapper over the native `com.zipx/device` method channel that tells
/// us whether we're running on a TV (Fire TV / Android TV). Resolved once at
/// startup and cached, then read synchronously everywhere via [isTv] so
/// layouts can adapt without every widget doing an async call.
class DeviceInfo {
  static const MethodChannel _channel = MethodChannel('com.zipx/device');

  bool _isTv = false;
  bool get isTv => _isTv;

  Future<void> initialize() async {
    try {
      _isTv = await _channel.invokeMethod<bool>('isTv') ?? false;
    } catch (_) {
      // Non-Android platforms / channel not available -> treat as non-TV.
      _isTv = false;
    }
  }
}
