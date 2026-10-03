import 'package:flutter_test/flutter_test.dart';
import 'package:de_schutter/domain/scorecard.dart';

void main() {
  test('X, miss, unset and cumulative totals stay distinct', () {
    var card = Scorecard.create(shooter: 'Bas', endCount: 2);
    card = card
        .setArrow(0, 0, Score.parse('X'))
        .setArrow(0, 1, Score.parse('9'))
        .setArrow(0, 2, Score.parse('M'));
    card = card.setArrow(1, 0, Score.parse('10'));
    expect(card.total, 29);
    expect(card.entered, 4);
    expect(card.hits, 3);
    expect(card.tens, 2);
    expect(card.xs, 1);
    expect(card.cumulative(0), 19);
    expect(card.cumulative(1), 29);
  });
  test(
    'manual correction preserves proposal and cannot be overwritten by analysis',
    () {
      final original = ArrowScore().withProposal(Score.parse('9'), .7);
      expect(original.finalScore, isNull);
      final confirmed = original.confirmProposal();
      final corrected = confirmed.setFinal(Score.parse('10'));
      expect(corrected.proposed!.label, '9');
      expect(corrected.finalScore!.label, '10');
      expect(corrected.manualOverride, isTrue);
      expect(corrected.history.length, 2);
      expect(
        corrected.withProposal(Score.parse('8'), .99).finalScore!.label,
        '10',
      );
      expect(corrected.confirmProposal().finalScore!.label, '10');
      expect(
        corrected
            .setFinal(null)
            .withProposal(Score.parse('8'), .99)
            .proposed!
            .label,
        '9',
      );
    },
  );
  test('serialization preserves edits and original card is immutable', () {
    final empty = Scorecard.create(shooter: 'Bas');
    final scored = empty
        .setArrow(0, 0, Score.parse('M'))
        .setArrow(0, 0, Score.parse('X'));
    final loaded = Scorecard.fromJson(scored.toJson());
    expect(empty.entered, 0);
    expect(loaded.total, 10);
    expect(loaded.ends.first.first.history.length, 2);
    expect(() => empty.ends.first.clear(), throwsUnsupportedError);
  });
  test('invalid data is rejected', () {
    expect(() => Score.parse('11'), throwsFormatException);
    expect(() => ArrowScore(confidence: double.nan), throwsFormatException);
    final json = Scorecard.create(shooter: 'Bas').toJson();
    json['schemaVersion'] = 99;
    expect(() => Scorecard.fromJson(json), throwsFormatException);
  });
}
