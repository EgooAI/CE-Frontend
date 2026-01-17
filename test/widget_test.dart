// CE-Frontend 基础启动测试

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ce_frontend/main.dart';

void main() {
  testWidgets('App should launch without errors', (WidgetTester tester) async {
    // 构建应用并触发一帧
    await tester.pumpWidget(const MyApp());

    // 验证应用能正常启动（MaterialApp 存在）
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
