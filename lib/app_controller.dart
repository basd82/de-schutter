import 'package:flutter/foundation.dart';

import 'data/scorecard_store.dart';
import 'domain/scorecard.dart';

class AppController extends ChangeNotifier {
  AppController(this.store);
  final ScorecardStore store;
  List<Scorecard> _cards = [];
  List<Scorecard> get cards => List.unmodifiable(_cards);
  bool busy = false;
  Future<void> load() async {
    _cards = await store.load();
    notifyListeners();
  }

  Future<void> _commit(List<Scorecard> next) async {
    if (busy) {
      throw StateError('Er wordt nog opgeslagen.');
    }
    busy = true;
    notifyListeners();
    try {
      await store.save(next);
      _cards = next;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> add(Scorecard card) {
    if (_cards.any((c) => c.id == card.id)) {
      throw const FormatException('Deze kaart bestaat al.');
    }
    return _commit([card, ..._cards]);
  }

  Future<void> setScore(String id, int end, int arrow, Score? score) =>
      _commit([
        for (final card in _cards)
          if (card.id == id) card.setArrow(end, arrow, score) else card,
      ]);
  Future<void> confirmPhotoEnd(
    String id,
    int end,
    List<Score> scores, {
    Set<int> corrected = const {},
    List<Score>? proposals,
  }) => _commit([
    for (final card in _cards)
      if (card.id == id)
        card.confirmPhotoEnd(
          end,
          scores,
          corrected: corrected,
          proposals: proposals,
        )
      else
        card,
  ]);
}
