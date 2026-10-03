import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:de_schutter/app_controller.dart';
import 'package:de_schutter/data/scorecard_store.dart';
import 'package:de_schutter/domain/scorecard.dart';
import 'package:de_schutter/features/photo/photo_service.dart';
import 'package:de_schutter/ui/scorecard_app.dart';

void main() {
  testWidgets('desktop edits scores and views photos without camera action', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'de-schutter-widget-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final controller = AppController(ScorecardStore(directory));
    final card = Scorecard.create(shooter: 'Bas', endCount: 2);
    await tester.runAsync(() => controller.add(card));
    await tester.pumpWidget(
      ScorecardApp(controller: controller, photos: PhotoService(directory)),
    );
    expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
    expect(find.byIcon(Icons.photo_outlined), findsNWidgets(2));
    expect(find.byTooltip('Bestaande foto openen'), findsNWidgets(2));
    await tester.tap(find.text('—').first);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'X'));
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (controller.busy) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Score opslaan bleef langer dan vijf seconden bezig.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect((await ScorecardStore(directory).load()).single.total, 10);
    });
    await tester.pumpAndSettle();
    expect(controller.cards.single.xs, 1);
  });
}
