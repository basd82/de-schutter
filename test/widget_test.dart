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
    final store = _MemoryStore();
    final controller = AppController(store);
    final card = Scorecard.create(shooter: 'Bas', endCount: 2);
    await controller.add(card);
    await tester.pumpWidget(
      ScorecardApp(
        controller: controller,
        photos: PhotoService(Directory.systemTemp),
      ),
    );
    expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
    expect(find.byIcon(Icons.photo_outlined), findsNWidgets(2));
    expect(find.byTooltip('Bestaande foto openen'), findsNWidgets(2));
    await tester.tap(find.text('—').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'X'));
    await tester.pumpAndSettle();
    expect(store.saved.single.total, 10);
    expect(controller.cards.single.xs, 1);
  });
}

// Filesystem persistence is covered by store_test; widget tests use a fake clock.
class _MemoryStore extends ScorecardStore {
  _MemoryStore() : super(Directory.systemTemp);
  List<Scorecard> saved = [];

  @override
  Future<void> save(List<Scorecard> cards) async {
    saved = List.of(cards);
  }
}
