import 'dart:math' as math;

import '../../domain/scorecard.dart';

/// Projective map from unit target coordinates (-1..1) to image pixels.
class TargetGeometry {
  TargetGeometry(List<double> coefficients)
    : h = List.unmodifiable(coefficients) {
    if (coefficients.length != 8 || coefficients.any((v) => !v.isFinite)) {
      throw const FormatException('Ongeldige blazoengeometrie.');
    }
  }
  final List<double> h;

  math.Point<double> imagePoint(double x, double y) {
    final w = h[6] * x + h[7] * y + 1;
    return math.Point(
      (h[0] * x + h[1] * y + h[2]) / w,
      (h[3] * x + h[4] * y + h[5]) / w,
    );
  }

  math.Point<double> targetPoint(double x, double y) {
    final a = h[0] - x * h[6], b = h[1] - x * h[7];
    final c = h[3] - y * h[6], d = h[4] - y * h[7];
    final e = x - h[2], f = y - h[5];
    final det = a * d - b * c;
    return math.Point((e * d - b * f) / det, (a * f - e * c) / det);
  }

  /// Four cardinal outer-ring points: top, right, bottom, left.
  static TargetGeometry fromAnchors(List<math.Point<double>> points) {
    const source = [(0.0, -1.0), (1.0, 0.0), (0.0, 1.0), (-1.0, 0.0)];
    final rows = <List<double>>[];
    for (var i = 0; i < 4; i++) {
      final (x, y) = source[i];
      final u = points[i].x, v = points[i].y;
      rows.add([x, y, 1, 0, 0, 0, -u * x, -u * y, u]);
      rows.add([0, 0, 0, x, y, 1, -v * x, -v * y, v]);
    }
    for (var col = 0; col < 8; col++) {
      var pivot = col;
      for (var row = col + 1; row < 8; row++) {
        if (rows[row][col].abs() > rows[pivot][col].abs()) pivot = row;
      }
      if (rows[pivot][col].abs() < 1e-8) {
        throw const FormatException('Blazoenpunten vallen samen.');
      }
      final swap = rows[col];
      rows[col] = rows[pivot];
      rows[pivot] = swap;
      final divisor = rows[col][col];
      for (var k = col; k <= 8; k++) {
        rows[col][k] /= divisor;
      }
      for (var row = 0; row < 8; row++) {
        if (row == col) continue;
        final factor = rows[row][col];
        for (var k = col; k <= 8; k++) {
          rows[row][k] -= factor * rows[col][k];
        }
      }
    }
    final g = TargetGeometry([for (final row in rows) row[8]]);
    if (g.h[6].abs() + g.h[7].abs() >= .9 || g.radiusPixels < 5) {
      throw const FormatException(
        'Blazoenpunten vormen geen bruikbare cirkel.',
      );
    }
    return g;
  }

  double get radiusPixels => math.sqrt((h[0] * h[4] - h[1] * h[3]).abs());
}

/// Diameter is a ratio of shaft diameter to the physical target diameter.
/// Setting it to zero avoids awarding a line touch with an unknown diameter.
class TargetScoring {
  const TargetScoring({
    this.diameterRatio = 0,
    this.smallTen = false,
    this.countX = true,
  });
  final double diameterRatio;
  final bool smallTen, countX;

  Score score(double x, double y) {
    final edge = math.max(0.0, math.sqrt(x * x + y * y) - diameterRatio);
    if (edge <= .05 + 1e-9) {
      return Score.parse(smallTen || !countX ? '10' : 'X');
    }
    for (var value = smallTen ? 9 : 10; value >= 1; value--) {
      if (edge <= (11 - value) / 10 + 1e-9) {
        return Score.parse('$value');
      }
    }
    return Score.parse('M');
  }

  bool lineCase(double x, double y, {double uncertainty = .015}) {
    final r = math.sqrt(x * x + y * y) - diameterRatio;
    return [
      if (countX || smallTen) .05,
      for (var i = 1; i <= 10; i++) i / 10,
    ].any((ring) => (r - ring).abs() <= uncertainty);
  }
}
