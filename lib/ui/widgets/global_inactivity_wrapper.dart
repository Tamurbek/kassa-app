import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/features/auth_provider.dart';

class GlobalInactivityWrapper extends StatefulWidget {
  final Widget child;
  const GlobalInactivityWrapper({super.key, required this.child});

  @override
  State<GlobalInactivityWrapper> createState() => _GlobalInactivityWrapperState();
}

class _GlobalInactivityWrapperState extends State<GlobalInactivityWrapper> {
  Timer? _inactivityTimer;
  static const inactivityTimeout = Duration(minutes: 5);

  void _resetInactivityTimer() {
    // Only manage timer if user is logged in
    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) {
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
      return;
    }

    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityTimeout, () {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        if (auth.currentUser != null) {
          auth.logout();
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Start timer if user is already logged in (unlikely at this stage but safe)
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
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      ),
    );
  }
}
