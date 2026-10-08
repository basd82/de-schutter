import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/scorecard.dart';
import '../features/photo/photo_analyzer.dart';
import '../features/photo/target_geometry.dart';

class ReviewedPhoto {
  ReviewedPhoto(this.scores, this.proposals, this.corrected, this.metadata);
  final List<Score> scores, proposals;
  final Set<int> corrected;
  final Map<String, dynamic> metadata;
}

class PhotoReviewDialog extends StatefulWidget {
  const PhotoReviewDialog({
    super.key,
    required this.analysis,
    required this.card,
    required this.end,
    this.previous,
  });
  final PhotoAnalysis analysis;
  final Scorecard card;
  final int end;
  final Map<String, dynamic>? previous;
  @override
  State<PhotoReviewDialog> createState() => _PhotoReviewDialogState();
}

class _Hit {
  _Hit(
    this.point,
    this.score, {
    this.corrected = false,
    this.overridden = false,
  }) : proposed = score;
  Offset point;
  Score score, proposed;
  bool corrected, overridden, checked = false;
}

class _PhotoReviewDialogState extends State<PhotoReviewDialog> {
  late TargetGeometry geometry;
  late List<Offset> anchors;
  final hits = <_Hit>[];
  int selected = 0;
  bool calibration = false, targetChecked = false, shaftValid = true;
  double shaftMm = 0, targetCm = 40;
  late bool smallTen, countX;
  String? error;
  TargetScoring get scoring => TargetScoring(
    diameterRatio: shaftMm / (targetCm * 10),
    smallTen: smallTen,
    countX: countX,
  );

  @override
  void initState() {
    super.initState();
    final a = widget.analysis;
    geometry =
        a.geometry ??
        TargetGeometry([
          a.imageWidth * .4,
          0,
          a.imageWidth / 2,
          0,
          a.imageHeight * .4,
          a.imageHeight / 2,
          0,
          0,
        ]);
    smallTen = widget.card.bow == 'Compound' && widget.card.distance <= 25;
    countX = widget.card.distance > 25;
    for (final p in a.proposals) {
      hits.add(_Hit(Offset(p.x * 2 - 1, p.y * 2 - 1), p.score));
    }
    final old = widget.previous;
    if (old != null) {
      try {
        geometry = TargetGeometry(
          (old['geometry'] as List).map((v) => (v as num).toDouble()).toList(),
        );
        shaftMm = (old['shaftMm'] as num).toDouble();
        targetCm = (old['targetCm'] as num).toDouble();
        smallTen = old['smallTen'] as bool;
        countX = old['countX'] as bool;
        hits.clear();
        for (final h in old['hits'] as List) {
          hits.add(
            _Hit(
              Offset((h['x'] as num).toDouble(), (h['y'] as num).toDouble()),
              Score.parse(h['score'] as String),
              corrected: h['corrected'] as bool,
              overridden: h['overridden'] as bool? ?? h['corrected'] as bool,
            ),
          );
          hits.last.proposed = Score.parse(
            h['proposed'] as String? ?? h['score'] as String,
          );
        }
      } catch (_) {
        error = 'Eerdere correcties konden niet worden geladen.';
      }
    }
    anchors = [
      for (final p in [(0.0, -1.0), (1.0, 0.0), (0.0, 1.0), (-1.0, 0.0)])
        _offset(geometry.imagePoint(p.$1, p.$2)),
    ];
    calibration = a.geometry == null && old == null;
    _rescore();
  }

  Offset _offset(math.Point<double> p) => Offset(p.x, p.y);
  void _rescore() {
    for (final h in hits) {
      if (!h.overridden) {
        h.score = scoring.score(h.point.dx, h.point.dy);
        h.proposed = h.score;
      }
      h.checked = false;
    }
  }

  void _moveAnchor(int i, Offset p) {
    final next = anchors.toList()..[i] = p;
    try {
      final updated = TargetGeometry.fromAnchors([
        for (final p in next) math.Point(p.dx, p.dy),
      ]);
      // Keep arrow markers on the same image pixels while changing calibration.
      for (final h in hits) {
        final image = geometry.imagePoint(h.point.dx, h.point.dy);
        h.point = _offset(updated.targetPoint(image.x, image.y));
      }
      geometry = updated;
      anchors = next;
      targetChecked = false;
      _rescore();
      error = null;
    } on FormatException catch (e) {
      error = e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.analysis;
    final canSave =
        targetChecked &&
        hits.length == widget.card.arrowsPerEnd &&
        hits.every((h) => h.checked);
    return AlertDialog(
      title: Text('Pijlen controleren · serie ${widget.end + 1}'),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.message),
              const SizedBox(height: 8),
              if (a.preview != null)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final scale = width / a.imageWidth;
                    return InteractiveViewer(
                      maxScale: 5,
                      child: SizedBox(
                        width: width,
                        height: width * a.imageHeight / a.imageWidth,
                        child: GestureDetector(
                          onTapUp: calibration
                              ? null
                              : (details) => setState(() {
                                  if (hits.length >= widget.card.arrowsPerEnd) {
                                    error =
                                        'Verwijder eerst een fout gevonden pijl.';
                                    return;
                                  }
                                  final p = geometry.targetPoint(
                                    details.localPosition.dx / scale,
                                    details.localPosition.dy / scale,
                                  );
                                  if (p.x.abs() > 1.2 || p.y.abs() > 1.2) {
                                    return;
                                  }
                                  hits.add(
                                    _Hit(_offset(p), scoring.score(p.x, p.y)),
                                  );
                                  selected = hits.length - 1;
                                  error = null;
                                }),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.memory(
                                  a.preview!,
                                  fit: BoxFit.fill,
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _RingsPainter(geometry, scale),
                                  ),
                                ),
                              ),
                              if (calibration)
                                for (var i = 0; i < 4; i++)
                                  _marker(
                                    anchors[i] * scale,
                                    ['B', 'R', 'O', 'L'][i],
                                    Colors.green,
                                    (delta) => _moveAnchor(
                                      i,
                                      anchors[i] + delta / scale,
                                    ),
                                  ),
                              if (!calibration)
                                for (var i = 0; i < hits.length; i++)
                                  _marker(
                                    _offset(
                                          geometry.imagePoint(
                                            hits[i].point.dx,
                                            hits[i].point.dy,
                                          ),
                                        ) *
                                        scale,
                                    '${i + 1}',
                                    i == selected
                                        ? Colors.orange
                                        : Colors.purple,
                                    (delta) {
                                      final current = geometry.imagePoint(
                                        hits[i].point.dx,
                                        hits[i].point.dy,
                                      );
                                      final p = geometry.targetPoint(
                                        current.x + delta.dx / scale,
                                        current.y + delta.dy / scale,
                                      );
                                      hits[i].point = _offset(p);
                                      hits[i].corrected = true;
                                      hits[i].overridden = false;
                                      hits[i].score = scoring.score(p.x, p.y);
                                      hits[i].proposed = hits[i].score;
                                      hits[i].checked = false;
                                      selected = i;
                                    },
                                    onTap: () => selected = i,
                                  ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              Text(
                calibration
                    ? 'Sleep B/R/O/L naar boven, rechts, onder en links op de buitenste '
                          '1-ring. De getekende ringen moeten samenvallen met het blazoen.'
                    : 'Tik voor een ontbrekende pijl. Sleep een nummer naar het '
                          'inslagpunt. Knijp om in te zoomen.',
              ),
              TextButton(
                onPressed: () => setState(() {
                  calibration = !calibration;
                  targetChecked = false;
                }),
                child: Text(
                  calibration
                      ? 'Klaar met blazoen afstellen'
                      : 'Blazoen afstellen',
                ),
              ),
              Wrap(
                spacing: 12,
                children: [
                  DropdownButton<double>(
                    value: targetCm,
                    items: [20.0, 40.0, 60.0, 80.0, 122.0]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('Blazoen ${v.toInt()} cm'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      targetCm = v!;
                      _rescore();
                    }),
                  ),
                  SizedBox(
                    width: 170,
                    child: TextFormField(
                      initialValue: '$shaftMm',
                      decoration: const InputDecoration(
                        labelText: 'Pijldiameter (mm)',
                        helperText: '0 = onbekend; lijn controleren',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) => setState(() {
                        final value = double.tryParse(v.replaceAll(',', '.'));
                        if (value == null ||
                            !value.isFinite ||
                            value < 0 ||
                            value > 20) {
                          shaftValid = false;
                          error = 'Pijldiameter moet tussen 0 en 20 mm liggen.';
                        } else {
                          shaftValid = true;
                          shaftMm = value;
                          error = null;
                          _rescore();
                        }
                      }),
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kleine compound-10 (binnenring)'),
                value: smallTen,
                onChanged: (v) => setState(() {
                  smallTen = v!;
                  if (smallTen) countX = false;
                  _rescore();
                }),
              ),
              if (!smallTen)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Binnenring als X tellen'),
                  value: countX,
                  onChanged: (v) => setState(() {
                    countX = v!;
                    _rescore();
                  }),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Blazoen en scoringsringen gecontroleerd'),
                value: targetChecked,
                onChanged: calibration
                    ? null
                    : (v) => setState(() => targetChecked = v!),
              ),
              for (var i = 0; i < hits.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pijl ${i + 1}: ${hits[i].score.label}'
                              '${scoring.lineCase(hits[i].point.dx, hits[i].point.dy) ? ' · lijngeval' : ''}',
                            ),
                          ),
                          if (i < widget.card.arrowsPerEnd &&
                              (widget.card.ends[widget.end][i].finalScore !=
                                      null ||
                                  widget
                                      .card
                                      .ends[widget.end][i]
                                      .history
                                      .isNotEmpty))
                            Flexible(
                              child: Text(
                                'Kaart: '
                                '${widget.card.ends[widget.end][i].finalScore?.label ?? "leeg"} '
                                '(behouden)',
                              ),
                            ),
                          PopupMenuButton<String>(
                            tooltip: 'Pijl verplaatsen of verwijderen',
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'up',
                                enabled: i > 0,
                                child: const Text('Naar vorige plek'),
                              ),
                              PopupMenuItem(
                                value: 'down',
                                enabled: i < hits.length - 1,
                                child: const Text('Naar volgende plek'),
                              ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('Pijl verwijderen'),
                              ),
                            ],
                            onSelected: (action) => setState(() {
                              if (action == 'remove') {
                                hits.removeAt(i);
                                selected = 0;
                              } else {
                                final to = action == 'up' ? i - 1 : i + 1;
                                final swap = hits[to];
                                hits[to] = hits[i];
                                hits[i] = swap;
                                selected = to;
                              }
                              for (final h in hits) {
                                h.checked = false;
                              }
                            }),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          for (final label in Score.labels)
                            ChoiceChip(
                              label: Text(label),
                              selected: hits[i].score.label == label,
                              onSelected: (_) => setState(() {
                                hits[i].score = Score.parse(label);
                                hits[i].overridden = true;
                                hits[i].corrected = true;
                                hits[i].checked = false;
                                selected = i;
                              }),
                            ),
                        ],
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Inslagpunt en score gecontroleerd'),
                        value: hits[i].checked,
                        onChanged: (v) => setState(() => hits[i].checked = v!),
                      ),
                    ],
                  ),
                ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Text(
                '${hits.length}/${widget.card.arrowsPerEnd} pijlen. '
                'Een gemiste pijl voeg je toe en geef je handmatig M.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
        FilledButton(
          onPressed: canSave && error == null
              ? () => Navigator.pop(
                  context,
                  ReviewedPhoto(
                    [for (final h in hits) h.score],
                    [for (final h in hits) h.proposed],
                    {
                      for (var i = 0; i < hits.length; i++)
                        if (hits[i].corrected) i,
                    },
                    {
                      'engine': 'classical-v1',
                      'geometry': geometry.h,
                      'shaftMm': shaftMm,
                      'targetCm': targetCm,
                      'smallTen': smallTen,
                      'countX': countX,
                      'hits': [
                        for (final h in hits)
                          {
                            'x': h.point.dx,
                            'y': h.point.dy,
                            'score': h.score.label,
                            'corrected': h.corrected,
                            'overridden': h.overridden,
                            'proposed': h.proposed.label,
                          },
                      ],
                    },
                  ),
                )
              : null,
          child: const Text('Bevestigen en opslaan'),
        ),
      ],
    );
  }

  Widget _marker(
    Offset position,
    String label,
    Color color,
    void Function(Offset) move, {
    VoidCallback? onTap,
  }) => Positioned(
    left: position.dx - 18,
    top: position.dy - 18,
    child: GestureDetector(
      onTap: () => setState(() {
        onTap?.call();
      }),
      onPanUpdate: (d) => setState(() => move(d.delta)),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .7),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.geometry, this.scale);
  final TargetGeometry geometry;
  final double scale;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in [.05, for (var i = 1; i <= 10; i++) i / 10]) {
      final path = Path();
      for (var j = 0; j <= 90; j++) {
        final a = j * 2 * math.pi / 90;
        final p = geometry.imagePoint(r * math.cos(a), r * math.sin(a));
        if (j == 0) {
          path.moveTo(p.x * scale, p.y * scale);
        } else {
          path.lineTo(p.x * scale, p.y * scale);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) =>
      oldDelegate.geometry != geometry || oldDelegate.scale != scale;
}
