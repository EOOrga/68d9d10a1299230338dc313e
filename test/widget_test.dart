import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jecker_andre/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('opens the operations dashboard', (tester) async {
    final store = OperationsStore(screenshotMode: true);
    await store.load();

    await tester.pumpWidget(JeckerApp(store: store));

    expect(find.text('JECKER ANDRE'), findsOneWidget);
    expect(find.text('Daily operations'), findsOneWidget);
    expect(find.text('Priority work'), findsOneWidget);
    expect(find.text('Container C-1182'), findsOneWidget);
  });

  testWidgets('creates a local task record', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = OperationsStore(screenshotMode: false);
    await store.load();

    await tester.pumpWidget(JeckerApp(store: store));
    await tester.tap(find.byKey(const ValueKey('nav-tasks')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-task')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('record-title-field')),
      'Prepare Friday roster',
    );
    await tester.tap(find.byKey(const ValueKey('save-record-button')));
    await tester.pumpAndSettle();

    expect(find.text('Prepare Friday roster'), findsOneWidget);
    expect(store.recordsFor(RecordType.task), hasLength(1));
  });
}
