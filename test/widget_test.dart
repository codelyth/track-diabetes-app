import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_diabetes/core/theme/app_theme.dart';
import 'package:track_diabetes/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('Kayıt ekranı açılır ve giriş ekranına dönülür', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    );

    final registerButton = find.widgetWithText(TextButton, 'Kayıt Olun');

    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    expect(find.text('Takibe İlk Adımı Atın'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Şeker Takibi'), findsOneWidget);
  });
}
