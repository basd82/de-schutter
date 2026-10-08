import 'dart:convert';

/// An empty arrow is null. M is a scored miss and X counts as ten.
class Score {
  const Score._(this.label);
  final String label;
  static const labels = [
    'X',
    '10',
    '9',
    '8',
    '7',
    '6',
    '5',
    '4',
    '3',
    '2',
    '1',
    'M',
  ];
  factory Score.parse(String value) {
    if (!labels.contains(value)) {
      throw FormatException('Ongeldige score: $value');
    }
    return Score._(value);
  }
  int get points => label == 'X'
      ? 10
      : label == 'M'
      ? 0
      : int.parse(label);
}

enum ScoreSource { manual, photoConfirmed }

class ScoreChange {
  const ScoreChange({
    required this.at,
    required this.before,
    required this.after,
    required this.source,
  });
  final DateTime at;
  final String? before;
  final String? after;
  final ScoreSource source;
  Map<String, dynamic> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'before': before,
    'after': after,
    'source': source.name,
  };
  factory ScoreChange.fromJson(Map<String, dynamic> json) => ScoreChange(
    at: DateTime.parse(json['at'] as String),
    before: json['before'] == null
        ? null
        : Score.parse(json['before'] as String).label,
    after: json['after'] == null
        ? null
        : Score.parse(json['after'] as String).label,
    source: ScoreSource.values.byName(json['source'] as String),
  );
}

class ArrowScore {
  ArrowScore({
    this.proposed,
    this.finalScore,
    this.confidence,
    List<ScoreChange> history = const [],
  }) : history = List.unmodifiable(history) {
    if (confidence != null &&
        (!confidence!.isFinite || confidence! < 0 || confidence! > 1)) {
      throw const FormatException('Zekerheid moet tussen 0 en 1 liggen.');
    }
  }
  final Score? proposed;
  final Score? finalScore;
  final double? confidence;
  final List<ScoreChange> history;
  bool get manualOverride =>
      proposed != null &&
      history.isNotEmpty &&
      history.last.source == ScoreSource.manual;

  /// A recognition result never replaces an entered or confirmed score.
  ArrowScore withProposal(Score score, double confidence) =>
      finalScore != null || history.isNotEmpty
      ? this
      : ArrowScore(proposed: score, confidence: confidence);

  ArrowScore setFinal(
    Score? score, {
    ScoreSource source = ScoreSource.manual,
    DateTime? at,
  }) {
    if (score?.label == finalScore?.label) {
      return this;
    }
    return ArrowScore(
      proposed: proposed,
      finalScore: score,
      confidence: confidence,
      history: [
        ...history,
        ScoreChange(
          at: at ?? DateTime.now().toUtc(),
          before: finalScore?.label,
          after: score?.label,
          source: source,
        ),
      ],
    );
  }

  ArrowScore confirmProposal() {
    if (proposed == null) {
      throw StateError('Er is geen scorevoorstel.');
    }
    if (finalScore != null || history.isNotEmpty) {
      return this;
    }
    return setFinal(proposed, source: ScoreSource.photoConfirmed);
  }

  Map<String, dynamic> toJson() => {
    'proposed': proposed?.label,
    'final': finalScore?.label,
    'confidence': confidence,
    'history': history.map((h) => h.toJson()).toList(),
  };
  factory ArrowScore.fromJson(Map<String, dynamic> json) => ArrowScore(
    proposed: json['proposed'] == null
        ? null
        : Score.parse(json['proposed'] as String),
    finalScore: json['final'] == null
        ? null
        : Score.parse(json['final'] as String),
    confidence: (json['confidence'] as num?)?.toDouble(),
    history: (json['history'] as List)
        .map((h) => ScoreChange.fromJson(Map<String, dynamic>.from(h as Map)))
        .toList(),
  );
}

class Scorecard {
  Scorecard({
    required this.id,
    required this.shooter,
    required this.club,
    required this.date,
    required this.distance,
    required this.target,
    required this.bow,
    required this.arrowsPerEnd,
    required this.targetCm,
    required this.shaftMm,
    required this.smallTen,
    required this.countX,
    required List<List<ArrowScore>> ends,
    required this.updatedAt,
  }) : ends = List.unmodifiable(
         ends.map((e) => List<ArrowScore>.unmodifiable(e)),
       ) {
    if (id.isEmpty ||
        shooter.trim().isEmpty ||
        distance <= 0 ||
        distance > 1000 ||
        ![3, 6].contains(arrowsPerEnd) ||
        ![20.0, 40.0, 60.0, 80.0, 122.0].contains(targetCm) ||
        !shaftMm.isFinite || shaftMm < 0 || shaftMm > 20 ||
        (smallTen && countX) ||
        ends.isEmpty ||
        ends.length > 60 ||
        ends.any((e) => e.length != arrowsPerEnd)) {
      throw const FormatException('Ongeldige scorekaart.');
    }
  }
  factory Scorecard.create({
    required String shooter,
    String club = '',
    int distance = 18,
    String target = 'WA 10-ringen',
    String bow = 'Recurve',
    int arrowsPerEnd = 3,
    int endCount = 12,
    double targetCm = 40,
    double shaftMm = 0,
    bool smallTen = false,
    bool countX = false,
  }) {
    final now = DateTime.now().toUtc();
    return Scorecard(
      id: now.microsecondsSinceEpoch.toString(),
      shooter: shooter.trim(),
      club: club.trim(),
      date: now,
      distance: distance,
      target: target,
      bow: bow,
      arrowsPerEnd: arrowsPerEnd,
      targetCm: targetCm,
      shaftMm: shaftMm,
      smallTen: smallTen,
      countX: countX,
      ends: List.generate(
        endCount,
        (_) => List.generate(arrowsPerEnd, (_) => ArrowScore()),
      ),
      updatedAt: now,
    );
  }
  final String id, shooter, club, target, bow;
  final DateTime date, updatedAt;
  final int distance, arrowsPerEnd;
  final double targetCm, shaftMm;
  final bool smallTen, countX;
  final List<List<ArrowScore>> ends;
  Iterable<ArrowScore> get arrows => ends.expand((e) => e);
  int get total => arrows.fold(0, (s, a) => s + (a.finalScore?.points ?? 0));
  int get entered => arrows.where((a) => a.finalScore != null).length;
  int get hits => arrows.where((a) => (a.finalScore?.points ?? 0) > 0).length;
  int get tens => arrows.where((a) => a.finalScore?.points == 10).length;
  int get xs => arrows.where((a) => a.finalScore?.label == 'X').length;
  int endTotal(int index) =>
      ends[index].fold(0, (s, a) => s + (a.finalScore?.points ?? 0));
  int cumulative(int index) =>
      List.generate(index + 1, endTotal).fold(0, (a, b) => a + b);
  Scorecard setArrow(int end, int arrow, Score? score) {
    final copy = ends.map((e) => e.toList()).toList();
    copy[end][arrow] = copy[end][arrow].setFinal(score);
    return Scorecard(
      id: id,
      shooter: shooter,
      club: club,
      date: date,
      distance: distance,
      target: target,
      bow: bow,
      arrowsPerEnd: arrowsPerEnd,
      targetCm: targetCm,
      shaftMm: shaftMm,
      smallTen: smallTen,
      countX: countX,
      ends: copy,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Saves one reviewed photo end atomically and preserves entered scores.
  Scorecard confirmPhotoEnd(
    int end,
    List<Score> scores, {
    Set<int> corrected = const {},
    List<Score>? proposals,
  }) {
    if (scores.length != arrowsPerEnd ||
        (proposals != null && proposals.length != scores.length)) {
      throw const FormatException('Controleer alle pijlen van de serie.');
    }
    final copy = ends.map((e) => e.toList()).toList();
    for (var i = 0; i < scores.length; i++) {
      final current = copy[end][i];
      if (current.finalScore != null || current.history.isNotEmpty) continue;
      copy[end][i] = current
          .withProposal(proposals?[i] ?? scores[i], 0)
          .setFinal(
            scores[i],
            source: corrected.contains(i)
                ? ScoreSource.manual
                : ScoreSource.photoConfirmed,
          );
    }
    return Scorecard(
      id: id,
      shooter: shooter,
      club: club,
      date: date,
      distance: distance,
      target: target,
      bow: bow,
      arrowsPerEnd: arrowsPerEnd,
      targetCm: targetCm,
      shaftMm: shaftMm,
      smallTen: smallTen,
      countX: countX,
      ends: copy,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'shooter': shooter,
    'club': club,
    'date': date.toIso8601String(),
    'distance': distance,
    'target': target,
    'bow': bow,
    'arrowsPerEnd': arrowsPerEnd,
    'targetCm': targetCm,
    'shaftMm': shaftMm,
    'smallTen': smallTen,
    'countX': countX,
    'ends': ends.map((e) => e.map((a) => a.toJson()).toList()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());
  factory Scorecard.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1) {
      throw const FormatException('Onbekende bestandsversie.');
    }
    return Scorecard(
      id: j['id'] as String,
      shooter: j['shooter'] as String,
      club: j['club'] as String,
      date: DateTime.parse(j['date'] as String),
      distance: j['distance'] as int,
      target: j['target'] as String,
      bow: j['bow'] as String,
      arrowsPerEnd: j['arrowsPerEnd'] as int,
      targetCm: (j['targetCm'] as num?)?.toDouble() ?? 40,
      shaftMm: (j['shaftMm'] as num?)?.toDouble() ?? 0,
      smallTen: j['smallTen'] as bool? ?? (j['bow'] == 'Compound' && (j['distance'] as int) <= 25),
      countX: j['countX'] as bool? ?? ((j['distance'] as int) > 25),
      ends: (j['ends'] as List)
          .map(
            (e) => (e as List)
                .map(
                  (a) =>
                      ArrowScore.fromJson(Map<String, dynamic>.from(a as Map)),
                )
                .toList(),
          )
          .toList(),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }
}
