import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:de_schutter/data/scorecard_store.dart';
import 'package:de_schutter/domain/scorecard.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('de-schutter-test-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test(
    'scores survive reopening and damaged primary recovers last backup',
    () async {
      final store = ScorecardStore(directory);
      final card = Scorecard.create(shooter: 'Bas');
      await store.save([card]);
      await store.save([card.setArrow(0, 0, Score.parse('9'))]);
      expect((await ScorecardStore(directory).load()).single.total, 9);
      await File('${directory.path}/scorecards.json').writeAsString('broken');
      final recovery = ScorecardStore(directory);
      expect((await recovery.load()).single.total, 0);
      expect(recovery.recoveredBackup, isTrue);
      await recovery.save([card.setArrow(0, 0, Score.parse('X'))]);
      expect((await recovery.load()).single.total, 10);
      expect(
        await File('${directory.path}/scorecards.corrupt.json').readAsString(),
        'broken',
      );
    },
  );
  test('unreadable data without backup is never silently replaced', () async {
    await File('${directory.path}/scorecards.json').writeAsString('broken');
    await expectLater(ScorecardStore(directory).load(), throwsFormatException);
  });
}
