import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/features/auth_provider.dart';
import '../../providers/features/settings_provider.dart';

class GlobalInactivityWrapper extends StatefulWidget {
  final Widget child;
  const GlobalInactivityWrapper({super.key, required this.child});

  @override
  State<GlobalInactivityWrapper> createState() => _GlobalInactivityWrapperState();
}

class _GlobalInactivityWrapperState extends State<GlobalInactivityWrapper> {
  Timer? _inactivityTimer;

  void _resetInactivityTimer() {
    // Only manage timer if user is logged in
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) {
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
      return;
    }

    final settings = context.read<SettingsProvider>();
    final timeout = Duration(minutes: settings.inactivityTimeoutMinutes);

    // If timeout is 0 or less, disable inactivity logout
    if (timeout.inMinutes <= 0) {
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
      return;
    }

    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(timeout, () {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        if (auth.currentUser != null) {
          debugPrint('GlobalInactivityWrapper: Timeout reached (${timeout.inMinutes} min). Logging out...');
          auth.logout();
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetInactivityTimer());
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        _resetInactivityTimer();
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerDown: (_) => _resetInactivityTimer(),
        onPointerMove: (_) => _resetInactivityTimer(),
        onPointerUp: (_) => _resetInactivityTimer(),
        onPointerHover: (_) => _resetInactivityTimer(),
        onPointerSignal: (_) => _resetInactivityTimer(),
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      ),
    );
  }
}
