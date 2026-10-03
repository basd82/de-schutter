import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:de_schutter/app_controller.dart';
import 'package:de_schutter/data/scorecard_store.dart';
import 'package:de_schutter/domain/scorecard.dart';
import 'package:de_schutter/features/photo/photo_service.dart';
import 'package:de_schutter/ui/scorecard_app.dart';

void main() {
  testWidgets('desktop edits a score, persists it and has no photo action', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'de-schutter-widget-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final controller = AppController(ScorecardStore(directory));
    final card = Scorecard.create(shooter: 'Bas', endCount: 2);
    await controller.add(card);
    await tester.pumpWidget(
      ScorecardApp(controller: controller, photos: PhotoService(directory)),
    );
    expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
    await tester.tap(find.text('—').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'X'));
    await tester.pump();
    await tester.runAsync(() async {
      while (controller.busy) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect((await ScorecardStore(directory).load()).single.total, 10);
    });
    await tester.pumpAndSettle();
    expect(controller.cards.single.xs, 1);
  });
}
