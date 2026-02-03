import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'unified_press.dart';

class NativeContextMenuItem {
  final String title;
  final bool isDestructive;
  final Future<void> Function() onSelected;
  final IconData? icon;
  final Color? iconColor;

  const NativeContextMenuItem({
    required this.title,
    required this.onSelected,
    this.isDestructive = false,
    this.icon,
    this.iconColor,
  });
}

/// 原生风格上下文菜单（iOS: CupertinoContextMenu；其他平台: PopupMenu）
class NativeContextMenu extends StatelessWidget {
  final Widget child;
  final List<NativeContextMenuItem> actions;
  final HitTestBehavior behavior;

  const NativeContextMenu({
    super.key,
    required this.child,
    required this.actions,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  Widget build(BuildContext context) {
    final isIOS = !kIsWeb && Platform.isIOS;

    if (isIOS) {
      return CupertinoContextMenu(
        actions: actions
            .map(
              (item) => CupertinoContextMenuAction(
                isDestructiveAction: item.isDestructive,
                onPressed: () async {
                  Navigator.pop(context);
                  await item.onSelected();
                },
                child: _buildMenuItemLabel(item),
              ),
            )
            .toList(),
        child: child,
      );
    }

    return UnifiedPress(
      behavior: behavior,
      onActivate: (position) => _showMenu(context, position),
      child: child,
    );
  }

  Future<void> _showMenu(BuildContext context, Offset globalPosition) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      overlay.size.width - globalPosition.dx,
      overlay.size.height - globalPosition.dy,
    );

    final selectedIndex = await showMenu<int>(
      context: context,
      position: position,
      items: List.generate(actions.length, (index) {
        final item = actions[index];
        return PopupMenuItem<int>(
          value: index,
          child: _buildMenuItemLabel(item),
        );
      }),
    );

    if (selectedIndex == null) return;
    await actions[selectedIndex].onSelected();
  }

  Widget _buildMenuItemLabel(NativeContextMenuItem item) {
    final textStyle = item.isDestructive
        ? const TextStyle(color: Colors.red, height: 1.0)
        : const TextStyle(height: 1.0);

    if (item.icon == null) {
      return Text(item.title, style: textStyle);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          item.icon,
          size: 18,
          color: item.iconColor ?? (item.isDestructive ? Colors.red : null),
        ),
        const SizedBox(width: 8),
        Text(item.title, style: textStyle),
      ],
    );
  }
}
