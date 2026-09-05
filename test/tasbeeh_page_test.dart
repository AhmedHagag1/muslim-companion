import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/data/repositories/tasbeeh_repository.dart';
import 'package:quran_app/features/tasbeeh/tasbeeh_controller.dart';
import 'package:quran_app/features/tasbeeh/tasbeeh_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'custom target dialog submits and cancels without teardown errors',
    (tester) async {
      final controller = TasbeehController(
        repository: TasbeehRepository(store: _Store()),
      );
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(home: TasbeehPage(controller: controller)),
      );

      await tester.tap(find.text('هدف مخصص'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '7');
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(controller.state?.target, 7);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('هدف مخصص'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(controller.state?.target, 7);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}

class _Store implements TasbeehStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
