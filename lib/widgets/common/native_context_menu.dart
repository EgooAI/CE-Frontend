import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

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

/// 原生风格上下文菜单（长按触发）
/// iOS: CupertinoContextMenu，child 限高避免全屏遮挡菜单
/// Android/Web: AdaptiveContextMenu（Material3）
/// Desktop: 右键触发 Material PopupMenu
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
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    final adaptiveActions = actions
        .map(
          (item) => AdaptiveContextMenuAction(
            title: item.title,
            icon: item.icon,
            isDestructive: item.isDestructive,
            onPressed: () => item.onSelected(),
          ),
        )
        .toList();

    // ── iOS：CupertinoContextMenu，限制 child 高度避免全屏遮挡菜单 ──
    if (isIOS) {
      return CupertinoContextMenu(
        actions: actions
            .map(
              (item) => CupertinoContextMenuAction(
                isDestructiveAction: item.isDestructive,
                trailingIcon: item.icon,
                onPressed: () {
                  Navigator.pop(context);
                  item.onSelected();
                },
                child: Text(item.title),
              ),
            )
            .toList(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 32,
            maxHeight: 160,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
        ),
      );
    }

    // ── 桌面端：额外保留右键触发 ──
    if (isDesktop) {
      return GestureDetector(
        behavior: behavior,
        onSecondaryTapDown: (details) =>
            _showDesktopMenu(context, details.globalPosition),
        child: AdaptiveContextMenu(actions: adaptiveActions, child: child),
      );
    }

    // ── Android / Web ──
    return AdaptiveContextMenu(actions: adaptiveActions, child: child);
  }

  Future<void> _showDesktopMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
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
    final color = item.isDestructive ? Colors.red : null;
    if (item.icon == null) {
      return Text(item.title, style: TextStyle(color: color, height: 1.0));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(item.icon, size: 18, color: item.iconColor ?? color),
        const SizedBox(width: 8),
        Text(item.title, style: TextStyle(color: color, height: 1.0)),
      ],
    );
  }
}
