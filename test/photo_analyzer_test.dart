import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:de_schutter/features/photo/local_photo_analyzer.dart';
import 'package:de_schutter/features/photo/target_geometry.dart';
import 'package:de_schutter/domain/scorecard.dart';

void main() {
  test('projective map and four-anchor calibration round trip', () {
    final g = TargetGeometry([150, 15, 200, 5, 100, 170, .12, -.08]);
    final restored = TargetGeometry.fromAnchors([
      g.imagePoint(0, -1),
      g.imagePoint(1, 0),
      g.imagePoint(0, 1),
      g.imagePoint(-1, 0),
    ]);
    for (final p in [const math.Point(.2, -.3), const math.Point(-.9, .8)]) {
      final image = restored.imagePoint(p.x, p.y);
      final result = g.targetPoint(image.x, image.y);
      expect(result.x, closeTo(p.x, 1e-8));
      expect(result.y, closeTo(p.y, 1e-8));
    }
  });

  test('shaft radius awards a touched line, not a near miss', () {
    const s = TargetScoring(diameterRatio: .015);
    expect(s.score(.215, 0).label, '9');
    expect(s.score(.216, 0).label, '8');
    expect(s.score(1.015, 0).label, '1');
    expect(s.score(1.016, 0).label, 'M');
    expect(const TargetScoring().score(.215, 0).label, '8');
    expect(const TargetScoring(smallTen: true).score(.06, 0).label, '9');
    expect(const TargetScoring(countX: false).score(0, 0).label, '10');
  });

  test('reviewed photos preserve manually entered and cleared scores', () {
    var card = Scorecard.create(shooter: 'Test', endCount: 1);
    card = card.setArrow(0, 0, Score.parse('7'));
    card = card.setArrow(0, 1, Score.parse('8')).setArrow(0, 1, null);
    card = card.confirmPhotoEnd(
      0,
      [Score.parse('10'), Score.parse('9'), Score.parse('8')],
      corrected: {2},
      proposals: [Score.parse('10'), Score.parse('9'), Score.parse('9')],
    );
    expect(card.ends[0][0].finalScore!.label, '7');
    expect(card.ends[0][1].finalScore, isNull);
    expect(card.ends[0][2].finalScore!.label, '8');
    expect(card.ends[0][2].proposed!.label, '9');
    expect(card.ends[0][2].history.last.source, ScoreSource.manual);
    expect(Scorecard.fromJson(card.toJson()).total, 15);
  });

  test('invalid photos and unsupported faces never fabricate scores', () {
    for (final target in ['WA 10-ringen', 'Field']) {
      final a = LocalPhotoAnalyzer.analyzeBytes(
        Uint8List(0),
        target: target,
        expectedArrows: 3,
      );
      expect(a.available, isFalse);
      expect(a.proposals, isEmpty);
    }
  });

  test('finds a perspective target and elongated shafts, rejects old holes', () {
    final g = TargetGeometry([180, 10, 300, 8, 150, 260, .09, -.05]);
    final image = img.Image(width: 600, height: 550);
    final colors = [
      img.ColorRgb8(250, 220, 30),
      img.ColorRgb8(220, 30, 40),
      img.ColorRgb8(30, 155, 220),
      img.ColorRgb8(25, 25, 25),
      img.ColorRgb8(240, 240, 240),
    ];
    img.fill(image, color: img.ColorRgb8(180, 180, 180));
    for (final p in image) {
      final t = g.targetPoint(p.x.toDouble(), p.y.toDouble());
      final r = t.distanceTo(const math.Point(0.0, 0.0));
      if (r <= 1) {
        final c = colors[math.min(4, (r / .2).floor())];
        p
          ..r = c.r
          ..g = c.g
          ..b = c.b;
      }
    }
    for (final point in [
      const math.Point(.1, -.12),
      const math.Point(-.32, .25),
      const math.Point(.43, .18),
    ]) {
      final a = g.imagePoint(point.x, point.y);
      final distance = point.distanceTo(const math.Point(0.0, 0.0));
      final b = g.imagePoint(
        point.x * (1 + .8 / distance),
        point.y * (1 + .8 / distance),
      );
      img.drawLine(
        image,
        x1: a.x.round(),
        y1: a.y.round(),
        x2: b.x.round(),
        y2: b.y.round(),
        thickness: 4,
        color: img.ColorRgb8(155, 95, 40),
      );
    }
    for (final point in [const math.Point(-.1, .1), const math.Point(.1, .4)]) {
      final p = g.imagePoint(point.x, point.y);
      img.fillCircle(
        image,
        x: p.x.round(),
        y: p.y.round(),
        radius: 2,
        color: img.ColorRgb8(10, 10, 10),
      );
    }
    final a = LocalPhotoAnalyzer.analyzeBytes(
      Uint8List.fromList(img.encodePng(image)),
      target: 'WA 10-ringen',
      expectedArrows: 3,
    );
    expect(a.geometry, isNotNull);
    final center = a.geometry!.imagePoint(0, 0);
    expect(center.x, closeTo(300, 10));
    expect(center.y, closeTo(260, 10));
    expect(a.proposals.length, 3);
    for (final expected in [
      const math.Point(.1, -.12),
      const math.Point(-.32, .25),
      const math.Point(.43, .18),
    ]) {
      expect(
        a.proposals.any(
          (p) =>
              a.geometry!
                  .imagePoint(p.x * 2 - 1, p.y * 2 - 1)
                  .distanceTo(g.imagePoint(expected.x, expected.y)) <
              12,
        ),
        isTrue,
        reason:
            'Expected $expected; proposals: ${a.proposals.map((p) => (p.x * 2 - 1, p.y * 2 - 1)).toList()}',
      );
    }
    expect(
      a.proposals.every((p) => p.needsReview && p.confidence == 0),
      isTrue,
    );
  });
}
