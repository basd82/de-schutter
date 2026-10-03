import 'dart:convert';
import 'dart:io';

import '../domain/scorecard.dart';

/// Single-process file storage. Save through one controller to serialize writes.
/// A staged write is flushed before rename; the previous file stays as backup.
class ScorecardStore {
  ScorecardStore(this.directory);
  final Directory directory;
  File get _primary => File('${directory.path}/scorecards.json');
  File get _backup => File('${directory.path}/scorecards.backup.json');
  bool recoveredBackup = false;

  List<Scorecard> _decode(String text) {
    final root = jsonDecode(text) as Map<String, dynamic>;
    if (root['schemaVersion'] != 1)
      throw const FormatException('Onbekende opslagversie.');
    final cards = (root['cards'] as List)
        .map((j) => Scorecard.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
    if (cards.map((c) => c.id).toSet().length != cards.length)
      throw const FormatException('Dubbele kaart-id.');
    return cards;
  }

  Future<List<Scorecard>> load() async {
    recoveredBackup = false;
    if (!await _primary.exists() && !await _backup.exists()) return [];
    try {
      return _decode(await _primary.readAsString());
    } catch (_) {
      if (!await _backup.exists()) rethrow;
      final cards = _decode(await _backup.readAsString());
      recoveredBackup = true;
      return cards;
    }
  }

  Future<void> save(List<Scorecard> cards) async {
    await directory.create(recursive: true);
    final staged = File('${directory.path}/scorecards.tmp');
    await staged.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'cards': cards.map((c) => c.toJson()).toList(),
      }),
      flush: true,
    );
    if (await _primary.exists()) {
      // Keep a corrupt original for troubleshooting without replacing good backup.
      var valid = false;
      try {
        _decode(await _primary.readAsString());
        valid = true;
      } catch (_) {
        /* Preserve damaged original. */
      }
      await _primary.copy(
        valid ? _backup.path : '${directory.path}/scorecards.corrupt.json',
      );
    }
    await staged.rename(_primary.path);
  }
}
