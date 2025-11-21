import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ce_frontend/pages/login_page.dart';

void main() {
  group('LoginPage', () {
    testWidgets('Password field has done action and submits on Enter', (WidgetTester tester) async {
      // Build the LoginPage widget
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      // Verify that the login page is rendered
      expect(find.text('登录'), findsOneWidget);

      // Find the username and password fields
      final usernameField = find.widgetWithText(TextFormField, '用户名或邮箱');
      final passwordField = find.widgetWithText(TextFormField, '密码');

      expect(usernameField, findsOneWidget);
      expect(passwordField, findsOneWidget);

      // Check that username field has next action
      final usernameTextFormField = tester.widget<TextFormField>(usernameField);
      expect(usernameTextFormField.textInputAction, TextInputAction.next);

      // Check that password field has done action
      final passwordTextFormField = tester.widget<TextFormField>(passwordField);
      expect(passwordTextFormField.textInputAction, TextInputAction.done);

      // Check that password field has onFieldSubmitted callback
      expect(passwordTextFormField.onFieldSubmitted, isNotNull);
    });

    testWidgets('Username and password fields are properly configured', (WidgetTester tester) async {
      // Build the LoginPage widget
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      // Find the username field
      final usernameField = find.widgetWithText(TextFormField, '用户名或邮箱');
      expect(usernameField, findsOneWidget);

      // Find the password field
      final passwordField = find.widgetWithText(TextFormField, '密码');
      expect(passwordField, findsOneWidget);

      // Verify password field is obscured
      final passwordTextFormField = tester.widget<TextFormField>(passwordField);
      expect(passwordTextFormField.obscureText, isTrue);
    });

    testWidgets('Login button exists and is enabled initially', (WidgetTester tester) async {
      // Build the LoginPage widget
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      // Find the login button
      final loginButton = find.widgetWithText(ElevatedButton, '登录');
      expect(loginButton, findsOneWidget);

      // Verify the button is enabled (not loading)
      final button = tester.widget<ElevatedButton>(loginButton);
      expect(button.onPressed, isNotNull);
    });
  });
}
