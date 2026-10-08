import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../domain/scorecard.dart';
import 'photo_analyzer.dart';
import 'target_geometry.dart';

/// Deterministic offline baseline. Heuristic detections always require review.
class LocalPhotoAnalyzer implements PhotoAnalyzer {
  @override
  Future<PhotoAnalysis> analyze(
    File photo, {
    required String target,
    required int expectedArrows,
  }) async {
    try {
      final bytes = await photo.readAsBytes();
      return await Isolate.run(
        () =>
            analyzeBytes(bytes, target: target, expectedArrows: expectedArrows),
      );
    } catch (_) {
      return const PhotoAnalysis(
        proposals: [],
        available: false,
        message: 'Foto kon niet worden verwerkt. Vul de scores handmatig in.',
      );
    }
  }

  /// Public for reproducible image fixtures and command-line evaluation.
  static PhotoAnalysis analyzeBytes(
    Uint8List bytes, {
    required String target,
    required int expectedArrows,
  }) {
    if (target != 'WA 10-ringen') {
      return const PhotoAnalysis(
        proposals: [],
        available: false,
        message:
            'Herkenning ondersteunt nu alleen WA 10-ringen. '
            'Gebruik voor dit blazoen handmatige scores.',
      );
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return const PhotoAnalysis(
        proposals: [],
        available: false,
        message: 'Onleesbare foto. Kies een JPEG- of PNG-foto.',
      );
    }
    final oriented = img.bakeOrientation(decoded);
    final scale = 900 / math.max(oriented.width, oriented.height);
    final image = scale < 1
        ? img.copyResize(
            oriented,
            width: (oriented.width * scale).round(),
            height: (oriented.height * scale).round(),
          )
        : oriented;
    final preview = Uint8List.fromList(img.encodeJpg(image, quality: 90));
    final geometry = _findTarget(image);
    if (geometry == null) {
      return PhotoAnalysis(
        proposals: [],
        available: false,
        preview: preview,
        imageWidth: image.width,
        imageHeight: image.height,
        message:
            'Geen eenduidig WA-blazoen gevonden. Fotografeer één volledig '
            'blazoen van dichterbij, zonder afgesneden ringen.',
      );
    }
    final points = _findShafts(image, geometry);
    final proposals = <ArrowProposal>[];
    for (final p in points) {
      if (proposals.any(
        (other) =>
            math.sqrt(
              math.pow(other.x * 2 - 1 - p.x, 2) +
                  math.pow(other.y * 2 - 1 - p.y, 2),
            ) <
            .04,
      )) {
        continue;
      }
      const scoring = TargetScoring();
      proposals.add(
        ArrowProposal(
          x: (p.x + 1) / 2,
          y: (p.y + 1) / 2,
          score: scoring.score(p.x, p.y),
          confidence: 0,
          lineCase: scoring.lineCase(p.x, p.y),
        ),
      );
    }
    // Do not invent missing arrows or silently discard surplus detections.
    return PhotoAnalysis(
      proposals: proposals,
      available: true,
      geometry: geometry,
      preview: preview,
      imageWidth: image.width,
      imageHeight: image.height,
      message:
          '${proposals.length} mogelijke pijlen gevonden; verwacht: '
          '$expectedArrows. Controleer het blazoen, alle inslagpunten en scores. '
          'Oude gaten, schaduwen en overlappende pijlen kunnen fouten geven. '
          'Zekerheid is niet gekalibreerd.',
    );
  }
}

int _color(img.Pixel p) {
  final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();
  if (r > 100 && g > 85 && b < .65 * math.min(r, g) && r < 1.45 * g) return 1;
  if (r > 75 && r > g * 1.4 && r > b * 1.35) return 2;
  if (b > 65 && b > r * 1.25 && g > r * 1.15) return 3;
  return 0;
}

TargetGeometry? _findTarget(img.Image image) {
  final w = image.width, h = image.height;
  final colors = Uint8List(w * h);
  for (final p in image) {
    colors[p.y * w + p.x] = _color(p);
  }
  // Only connected yellow areas seed targets; reject several comparable faces.
  final components =
      _components(
          colors,
          w,
          h,
          (v) => v == 1,
        ).where((c) => c.length > 60).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  if (components.isEmpty ||
      (components.length > 1 &&
          components[1].length > components[0].length * .55))
    return null;
  final yellow = components.first;
  var cx = 0.0, cy = 0.0, xx = 0.0, yy = 0.0, xy = 0.0;
  for (final i in yellow) {
    cx += i % w;
    cy += i ~/ w;
  }
  cx /= yellow.length;
  cy /= yellow.length;
  for (final i in yellow) {
    final x = i % w - cx, y = i ~/ w - cy;
    xx += x * x;
    yy += y * y;
    xy += x * y;
  }
  xx /= yellow.length;
  yy /= yellow.length;
  xy /= yellow.length;
  final angle = .5 * math.atan2(2 * xy, xx - yy);
  final diff = math.sqrt(math.pow(xx - yy, 2) + 4 * xy * xy);
  final a = 10 * math.sqrt((xx + yy + diff) / 2);
  final b = 10 * math.sqrt((xx + yy - diff) / 2);
  if (!a.isFinite || !b.isFinite || b < 20 || a / b > 3) return null;
  var geometry = TargetGeometry([
    a * math.cos(angle),
    -b * math.sin(angle),
    cx,
    a * math.sin(angle),
    b * math.cos(angle),
    cy,
    0,
    0,
  ]);
  // Extract yellow/red and red/blue boundary pixels. Fit both concentric rings
  // to constrain a projective transform, including perspective terms.
  final samples = <(double, double, double)>[];
  for (var y = 2; y < h - 2; y += 2) {
    for (var x = 2; x < w - 2; x += 2) {
      final c = colors[y * w + x];
      if (c != 1 && c != 2) continue;
      final point = geometry.targetPoint(x.toDouble(), y.toDouble());
      final radius = point.distanceTo(const math.Point(0.0, 0.0));
      final ring = c == 1 ? .2 : .4;
      if ((radius - ring).abs() > .09) continue;
      if ([
        colors[y * w + x + 2],
        colors[y * w + x - 2],
        colors[(y + 2) * w + x],
        colors[(y - 2) * w + x],
      ].contains(c + 1)) {
        samples.add((x.toDouble(), y.toDouble(), ring));
      }
    }
  }
  if (samples.where((s) => s.$3 == .2).length < 12 ||
      samples.where((s) => s.$3 == .4).length < 20)
    return null;
  double loss(TargetGeometry g) {
    var sum = 0.0;
    for (final s in samples) {
      final p = g.targetPoint(s.$1, s.$2);
      final error = (p.distanceTo(const math.Point(0.0, 0.0)) - s.$3).abs();
      if (!error.isFinite) return double.infinity;
      sum += math.min(error * error, .0036);
    }
    return sum / samples.length;
  }

  var best = loss(geometry);
  final steps = [a * .02, b * .02, 2.0, a * .02, b * .02, 2.0, .02, .02];
  for (var pass = 0; pass < 80; pass++) {
    var improved = false;
    for (var i = 0; i < 8; i++) {
      for (final sign in [-1, 1]) {
        final candidate = geometry.h.toList();
        candidate[i] += sign * steps[i];
        if (candidate[6].abs() + candidate[7].abs() > .65) continue;
        final g = TargetGeometry(candidate);
        final error = loss(g);
        if (error < best) {
          geometry = g;
          best = error;
          improved = true;
        }
      }
    }
    if (!improved) {
      for (var i = 0; i < steps.length; i++) {
        steps[i] *= .65;
      }
    }
  }
  if (best > .0008) return null;
  // Verify radial colors around the entire face, not merely a yellow object.
  var good = 0, total = 0;
  for (var sector = 0; sector < 36; sector++) {
    final t = sector * 2 * math.pi / 36;
    for (final (r, color) in [(.15, 1), (.3, 2), (.5, 3)]) {
      final p = geometry.imagePoint(r * math.cos(t), r * math.sin(t));
      if (p.x < 0 || p.y < 0 || p.x >= w || p.y >= h) return null;
      if (colors[p.y.toInt() * w + p.x.toInt()] == color) good++;
      total++;
    }
    final outer = geometry.imagePoint(math.cos(t), math.sin(t));
    if (outer.x < 0 || outer.y < 0 || outer.x >= w || outer.y >= h) return null;
  }
  return good / total >= .65 ? geometry : null;
}

List<List<int>> _components(
  Uint8List mask,
  int w,
  int h,
  bool Function(int) accept,
) {
  final seen = Uint8List(mask.length), result = <List<int>>[];
  for (var i = 0; i < mask.length; i++) {
    if (seen[i] != 0 || !accept(mask[i])) continue;
    final queue = <int>[i];
    seen[i] = 1;
    for (var head = 0; head < queue.length; head++) {
      final j = queue[head], x = j % w, y = j ~/ w;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final n = ny * w + nx;
          if (seen[n] == 0 && accept(mask[n])) {
            seen[n] = 1;
            queue.add(n);
          }
        }
      }
    }
    result.add(queue);
  }
  return result;
}

List<math.Point<double>> _findShafts(img.Image image, TargetGeometry g) {
  // Rectify to a fixed resolution before finding shafts. Ring position and
  // minimum shaft length then have the same meaning for every photo.
  const size = 480, radius = 200.0;
  final rectified = img.Image(width: size, height: size);
  final valid = Uint8List(size * size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final p = g.imagePoint((x - size / 2) / radius, (y - size / 2) / radius);
      if (p.x < 0 || p.y < 0 || p.x >= image.width || p.y >= image.height)
        continue;
      final c = image.getPixel(p.x.toInt(), p.y.toInt());
      rectified.setPixelRgb(x, y, c.r, c.g, c.b);
      valid[y * size + x] = 1;
    }
  }
  final mask = Uint8List(size * size);
  for (var y = 4; y < size - 4; y++) {
    for (var x = 4; x < size - 4; x++) {
      final r =
          math.sqrt(math.pow(x - size / 2, 2) + math.pow(y - size / 2, 2)) /
          radius;
      if (r > 1.08 || valid[y * size + x] == 0) continue;
      final c = rectified.getPixel(x, y);
      final wood = c.r > c.g * 1.25 && c.g > c.b * 1.25 && c.g > 35;
      // Local tangential contrast removes smooth radial rings, including black.
      final t = math.atan2(y - size / 2, x - size / 2);
      final dx = (5 * math.sin(t)).round(), dy = (5 * math.cos(t)).round();
      final left = rectified.getPixel(x + dx, y - dy);
      final right = rectified.getPixel(x - dx, y + dy);
      double light(img.Pixel p) => (p.r + p.g + p.b) / 3;
      final dark = light(c) + 40 < math.min(light(left), light(right));
      if (wood || dark) mask[y * size + x] = 1;
    }
  }
  final components = _components(mask, size, size, (v) => v == 1);
  final hits = <math.Point<double>>[];
  for (final pixels in components) {
    if (pixels.length < 25 || pixels.length > 5000) continue;
    var cx = 0.0, cy = 0.0;
    for (final i in pixels) {
      cx += i % size;
      cy += i ~/ size;
    }
    cx /= pixels.length;
    cy /= pixels.length;
    var xx = 0.0, yy = 0.0, xy = 0.0;
    for (final i in pixels) {
      final x = i % size - cx, y = i ~/ size - cy;
      xx += x * x;
      yy += y * y;
      xy += x * y;
    }
    final angle = .5 * math.atan2(2 * xy, xx - yy);
    final vx = math.cos(angle), vy = math.sin(angle);
    var lo = double.infinity, hi = double.negativeInfinity, width = 0.0;
    for (final i in pixels) {
      final x = i % size - cx, y = i ~/ size - cy;
      final u = x * vx + y * vy;
      lo = math.min(lo, u);
      hi = math.max(hi, u);
      width += math.pow(-x * vy + y * vx, 2);
    }
    width = math.sqrt(width / pixels.length);
    final length = hi - lo;
    if (length < 24 || length / math.max(width, 1) < 7 || width > 8) continue;
    final a = math.Point(
      (cx + lo * vx - size / 2) / radius,
      (cy + lo * vy - size / 2) / radius,
    );
    final b = math.Point(
      (cx + hi * vx - size / 2) / radius,
      (cy + hi * vy - size / 2) / radius,
    );
    // The inner endpoint is a candidate, never a certified entry location.
    final p =
        a.distanceTo(const math.Point(0.0, 0.0)) <
            b.distanceTo(const math.Point(0.0, 0.0))
        ? a
        : b;
    if (p.distanceTo(const math.Point(0.0, 0.0)) <= 1.02) hits.add(p);
  }
  return hits;
}
