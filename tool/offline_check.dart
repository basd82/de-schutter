// Standalone checks that require only the Dart SDK, without Flutter or packages.
import 'dart:io';

import '../lib/domain/scorecard.dart';
import '../lib/data/scorecard_store.dart';

void check(bool ok, String message) {
  if (!ok) throw StateError(message);
}

Future<void> main() async {
  var checks = 0;
  void verify(bool ok, String message) {
    check(ok, message);
    checks++;
  }

  final empty = Scorecard.create(shooter: 'Bas', endCount: 2);
  var card = empty
      .setArrow(0, 0, Score.parse('X'))
      .setArrow(0, 1, Score.parse('9'))
      .setArrow(0, 2, Score.parse('M'))
      .setArrow(1, 0, Score.parse('10'));
  verify(
    card.total == 29 &&
        card.entered == 4 &&
        card.hits == 3 &&
        card.tens == 2 &&
        card.xs == 1,
    'Wrong summary',
  );
  verify(
    card.cumulative(0) == 19 && card.cumulative(1) == 29,
    'Wrong running total',
  );
  verify(empty.entered == 0, 'Mutation changed previous card');
  final loaded = Scorecard.fromJson(card.toJson());
  verify(
    loaded.total == 29 && loaded.ends[0][0].history.length == 1,
    'Serialization lost data',
  );
  final proposal = ArrowScore().withProposal(Score.parse('9'), .7);
  verify(proposal.finalScore == null, 'Proposal became final automatically');
  final corrected = proposal.confirmProposal().setFinal(Score.parse('10'));
  verify(
    corrected.proposed!.label == '9' &&
        corrected.manualOverride &&
        corrected.history.length == 2,
    'Override lost history',
  );
  verify(
    corrected.withProposal(Score.parse('8'), .99).finalScore!.label == '10',
    'Analysis overwrote human',
  );
  verify(
    corrected.confirmProposal().finalScore!.label == '10',
    'Confirmation overwrote human',
  );
  verify(
    corrected
            .setFinal(null)
            .withProposal(Score.parse('8'), .99)
            .proposed!
            .label ==
        '9',
    'Analysis overwrote cleared human decision',
  );
  var invalid = false;
  try {
    Score.parse('11');
  } on FormatException {
    invalid = true;
  }
  verify(invalid, 'Invalid score accepted');
  final directory = await Directory.systemTemp.createTemp('de-schutter-check-');
  try {
    final store = ScorecardStore(directory);
    await store.save([card]);
    card = card.setArrow(1, 1, Score.parse('8'));
    await store.save([card]);
    verify((await store.load()).single.total == 37, 'Saved scores lost');
    await File('${directory.path}/scorecards.json').writeAsString('broken');
    verify(
      (await store.load()).single.total == 29 && store.recoveredBackup,
      'Recovery failed',
    );
    await store.save([card]);
    verify(
      (await store.load()).single.total == 37 &&
          await File('${directory.path}/scorecards.corrupt.json').exists(),
      'Recovery damaged backup',
    );
    await File('${directory.path}/scorecards.backup.json').delete();
    await File('${directory.path}/scorecards.json').writeAsString('broken');
    invalid = false;
    try {
      await store.load();
    } on FormatException {
      invalid = true;
    }
    verify(invalid, 'Unreadable scores silently discarded');
  } finally {
    await directory.delete(recursive: true);
  }
  stdout.writeln('$checks offline checks passed.');
}
