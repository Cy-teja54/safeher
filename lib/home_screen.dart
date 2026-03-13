import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'native_comm_channel.dart';
import 'volume_button_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // ── Replace with your real emergency contact number ──
  static const String emergencyNumber = '+916302620295';

  bool _isLoading = false;
  bool _isAccessibilityEnabled = false;
  late final VolumeButtonService _volumeService;

  // ────────────────────────────────────────────────────────
  // Lifecycle
  // ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
    _checkAccessibility();

    // Start listening for volume button triple-press (foreground)
    _volumeService = VolumeButtonService(
      onTriplePress: _onSosPressed,
    );
    _volumeService.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _volumeService.stop();
    super.dispose();
  }

  /// Re-check accessibility when user returns to the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAccessibility();
    }
  }

  Future<void> _checkAccessibility() async {
    final enabled = await NativeCommChannel.isAccessibilityEnabled();
    if (mounted) {
      setState(() => _isAccessibilityEnabled = enabled);
    }
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.location,
      Permission.sms,
      Permission.phone,
    ].request();

    if (!mounted) return;

    final denied = statuses.entries
        .where((e) => e.value.isDenied || e.value.isPermanentlyDenied)
        .map((e) => e.key.toString())
        .toList();

    if (denied.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location, SMS, and Phone permissions are required for this app to work.',
          ),
        ),
      );
    }
  }

  // ────────────────────────────────────────────────────────
  // Get current GPS position
  // ────────────────────────────────────────────────────────
  Future<Position?> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services.')),
        );
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return null;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission permanently denied. Please enable it in settings.',
            ),
          ),
        );
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return position;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
      return null;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ────────────────────────────────────────────────────────
  // Send SMS directly (no SMS app opens)
  // ────────────────────────────────────────────────────────
  Future<bool> _sendDirectSms(String message) async {
    final smsPermission = await Permission.sms.status;
    if (!smsPermission.isGranted) {
      final result = await Permission.sms.request();
      if (!result.isGranted) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS permission is required to send alerts.')),
        );
        return false;
      }
    }

    final success = await NativeCommChannel.sendSms(
      phoneNumber: emergencyNumber,
      message: message,
    );

    if (!mounted) return success;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '✅ SMS sent successfully!' : '❌ Failed to send SMS.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
    return success;
  }

  // ────────────────────────────────────────────────────────
  // Make a direct call (no dialer opens)
  // ────────────────────────────────────────────────────────
  Future<bool> _makeDirectCall() async {
    final phonePermission = await Permission.phone.status;
    if (!phonePermission.isGranted) {
      final result = await Permission.phone.request();
      if (!result.isGranted) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone permission is required to make calls.')),
        );
        return false;
      }
    }

    final success = await NativeCommChannel.makeDirectCall(
      phoneNumber: emergencyNumber,
    );

    if (!mounted) return success;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to place call.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return success;
  }

  // ────────────────────────────────────────────────────────
  // Button actions
  // ────────────────────────────────────────────────────────
  Future<void> _onSosPressed() async {
    final position = await _getCurrentLocation();
    if (position == null) return;

    final message =
        'I need help! My location: https://maps.google.com/?q=${position.latitude},${position.longitude}';

    // Send SMS first, then make the call
    await _sendDirectSms(message);
    await _makeDirectCall();
  }

  Future<void> _onSendLocationPressed() async {
    final position = await _getCurrentLocation();
    if (position == null) return;

    final message =
        'My location: https://maps.google.com/?q=${position.latitude},${position.longitude}';
    await _sendDirectSms(message);
  }

  Future<void> _onCallPressed() async {
    await _makeDirectCall();
  }

  // ────────────────────────────────────────────────────────
  // UI
  // ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeHer'),
        centerTitle: true,
        backgroundColor: Colors.pink.shade700,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── SOS Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 80,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _onSosPressed,
                      icon: const Icon(Icons.warning_rounded, size: 32),
                      label: const Text(
                        'SOS',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Send Location Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _onSendLocationPressed,
                      icon: const Icon(Icons.location_on, size: 28),
                      label: const Text(
                        'Send Location',
                        style: TextStyle(fontSize: 20),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Call Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _onCallPressed,
                      icon: const Icon(Icons.call, size: 28),
                      label: const Text(
                        'Call',
                        style: TextStyle(fontSize: 20),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Background SOS status ──
                  GestureDetector(
                    onTap: _isAccessibilityEnabled
                        ? null
                        : () => NativeCommChannel.openAccessibilitySettings(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _isAccessibilityEnabled
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isAccessibilityEnabled
                              ? Colors.green.shade300
                              : Colors.orange.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isAccessibilityEnabled
                                    ? Icons.check_circle
                                    : Icons.volume_down,
                                color: _isAccessibilityEnabled
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _isAccessibilityEnabled
                                      ? 'Background SOS active — Vol down 3×'
                                      : 'Tap to enable background SOS',
                                  style: TextStyle(
                                    color: _isAccessibilityEnabled
                                        ? Colors.green.shade800
                                        : Colors.orange.shade800,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!_isAccessibilityEnabled) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Enable SafeHer in Accessibility Settings',
                              style: TextStyle(
                                color: Colors.orange.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Loading overlay ──
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
