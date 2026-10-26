import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifilter/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('dashboard shows real state and exactly three priorities', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('notifilter/native'),
          (call) async => switch (call.method) {
            'state' => {
              'onboarded': true,
              'enabled': false,
              'access': false,
              'analyzed': 0,
            },
            'history' || 'rules' => [],
            _ => null,
          },
        );
    await tester.pumpWidget(const Notifilter());
    await tester.pumpAndSettle();
    expect(find.text('Enable monitoring'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    for (final label in ['HIGH', 'NORMAL', 'LOW']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('CRITICAL'), findsNothing);
  });
}
