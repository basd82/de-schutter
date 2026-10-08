import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:de_schutter/domain/scorecard.dart';
import 'package:de_schutter/features/photo/photo_analyzer.dart';
import 'package:de_schutter/features/photo/target_geometry.dart';
import 'package:de_schutter/ui/photo_review_dialog.dart';

void main() {
  testWidgets(
    'requires each review and allows manual override of every score',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ReviewedPhoto? reviewed;
      final image = img.Image(width: 400, height: 400);
      final analysis = PhotoAnalysis(
        available: true,
        message: 'Test',
        geometry: TargetGeometry([150, 0, 200, 0, 150, 200, 0, 0]),
        imageWidth: 400,
        imageHeight: 400,
        preview: Uint8List.fromList(img.encodePng(image)),
        proposals: [
          for (var i = 0; i < 3; i++)
            ArrowProposal(
              x: .5 + i * .05,
              y: .5,
              score: Score.parse('10'),
              confidence: 0,
            ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  reviewed = await showDialog<ReviewedPhoto>(
                    context: context,
                    builder: (_) => PhotoReviewDialog(
                      analysis: analysis,
                      card: Scorecard.create(shooter: 'Test'),
                      end: 0,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      FilledButton save() => tester.widget(
        find.widgetWithText(FilledButton, 'Bevestigen en opslaan'),
      );
      expect(save().onPressed, isNull);
      final checks = find.byType(CheckboxListTile);
      // Small-ten, X, then target and the three arrows.
      for (var i = 2; i < 6; i++) {
        await tester.ensureVisible(checks.at(i));
        await tester.tap(checks.at(i));
        await tester.pumpAndSettle();
      }
      expect(save().onPressed, isNotNull);
      final miss = find.widgetWithText(ChoiceChip, 'M').first;
      await tester.ensureVisible(miss);
      await tester.tap(miss);
      await tester.pumpAndSettle();
      expect(save().onPressed, isNull);
      await tester.ensureVisible(checks.at(3));
      await tester.tap(checks.at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bevestigen en opslaan'));
      await tester.pumpAndSettle();
      expect(reviewed!.scores.first.label, 'M');
      expect(reviewed!.proposals.first.label, '10');
      expect(reviewed!.corrected, contains(0));
      expect(tester.takeException(), isNull);
    },
  );
}
