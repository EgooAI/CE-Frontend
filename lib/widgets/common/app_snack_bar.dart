import 'dart:async';

import 'package:flutter/material.dart';

class AppSnackBar {
  static OverlayEntry? _entry;
  static _AppSnackBarOverlayState? _entryState;
  static Timer? _timer;

  static void show(
    BuildContext context,
    SnackBar snackBar, {
    Duration? duration,
  }) {
    final previousEntry = _entry;
    final previousState = _entryState;
    if (previousEntry != null) {
      _dismissEntry(previousEntry, previousState);
    }

    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    final theme = Theme.of(context).snackBarTheme;
    final displayDuration = duration ?? snackBar.duration;

    _entry = OverlayEntry(
      builder: (context) => _AppSnackBarOverlay(
        snackBar: snackBar,
        theme: theme,
        onDismissed: hide,
        onStateReady: (state) {
          _entryState = state;
        },
      ),
    );

    overlay.insert(_entry!);

    _timer = Timer(displayDuration, () {
      hide();
    });
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    final currentEntry = _entry;
    final currentState = _entryState;
    if (currentEntry == null) return;
    _dismissEntry(currentEntry, currentState);
  }

  static void _dismissEntry(
    OverlayEntry entry,
    _AppSnackBarOverlayState? state,
  ) {
    if (state == null) {
      entry.remove();
      if (identical(_entry, entry)) {
        _entry = null;
        _entryState = null;
      }
      return;
    }

    state.dismiss().whenComplete(() {
      entry.remove();
      if (identical(_entry, entry)) {
        _entry = null;
        _entryState = null;
      }
    });
  }
}

void showAppSnackBar(BuildContext context, SnackBar snackBar) {
  AppSnackBar.show(context, snackBar);
}

class _AppSnackBarOverlay extends StatefulWidget {
  const _AppSnackBarOverlay({
    super.key,
    required this.snackBar,
    required this.theme,
    required this.onDismissed,
    required this.onStateReady,
  });

  final SnackBar snackBar;
  final SnackBarThemeData theme;
  final VoidCallback onDismissed;
  final ValueChanged<_AppSnackBarOverlayState> onStateReady;

  @override
  State<_AppSnackBarOverlay> createState() => _AppSnackBarOverlayState();
}

class _AppSnackBarOverlayState extends State<_AppSnackBarOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    widget.onStateReady(this);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> dismiss() async {
    if (!_controller.isAnimating && _controller.value == 0) return;
    await _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final insetPadding =
        theme.insetPadding ??
        const EdgeInsets.symmetric(horizontal: 80, vertical: 24);
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    final padding = insetPadding.copyWith(
      bottom: insetPadding.bottom + bottomSafe + 56,
    );
    final backgroundColor = widget.snackBar.backgroundColor ?? Colors.white;
    final shape =
        widget.snackBar.shape ??
        theme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: padding,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: ScaleTransition(
                scale: _scale,
                child: Material(
                  color: backgroundColor,
                  shape: shape,
                  elevation: theme.elevation ?? 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: DefaultTextStyle(
                      style:
                          theme.contentTextStyle ??
                          const TextStyle(color: Colors.black, fontSize: 13),
                      child: widget.snackBar.content,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
