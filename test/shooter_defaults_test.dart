import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:de_schutter/app_controller.dart';
import 'package:de_schutter/data/scorecard_store.dart';
import 'package:de_schutter/domain/scorecard.dart';

void main() {
  test(
    'name and club survive restart and old score edits do not change defaults',
    () async {
      final root = await Directory.systemTemp.createTemp('schutter-defaults-');
      try {
        final controller = AppController(ScorecardStore(root));
        expect(controller.shooterDefaults, (shooter: '', club: ''));
        final old = Scorecard.create(shooter: 'Oud', club: 'Oude club');
        final newer = Scorecard.create(shooter: 'Bas', club: 'Mijn vereniging');
        await controller.add(old);
        await controller.add(newer);
        await controller.setScore(old.id, 0, 0, Score.parse('10'));
        final restarted = AppController(ScorecardStore(root));
        await restarted.load();
        expect(restarted.shooterDefaults, (
          shooter: 'Bas',
          club: 'Mijn vereniging',
        ));
        await restarted.add(Scorecard.create(shooter: 'Bas', club: ''));
        final again = AppController(ScorecardStore(root));
        await again.load();
        expect(again.shooterDefaults, (shooter: 'Bas', club: ''));
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
