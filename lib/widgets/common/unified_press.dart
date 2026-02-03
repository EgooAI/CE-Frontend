import 'package:flutter/material.dart';

/// 统一右键与长按触发的操作
class UnifiedPress extends StatelessWidget {
  const UnifiedPress({
    super.key,
    required this.child,
    required this.onActivate,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final ValueChanged<Offset> onActivate;
  final HitTestBehavior behavior;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: behavior,
      onLongPressStart: (details) => onActivate(details.globalPosition),
      onSecondaryTapDown: (details) => onActivate(details.globalPosition),
      child: child,
    );
  }
}
