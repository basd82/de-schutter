import 'dart:io';

import 'package:image/image.dart' as img;

import 'package:de_schutter/features/photo/local_photo_analyzer.dart';

/// Private fixture evaluation; source photographs are never uploaded by this tool.
Future<void> main(List<String> args) async {
  final directory = Directory(args.first);
  final output = Directory(
    args.length > 1 ? args[1] : '/tmp/schutter-evaluation',
  );
  await output.create(recursive: true);
  var index = 0;
  await for (final file in directory.list(recursive: true)) {
    if (file is! File || !file.path.endsWith('.jpeg')) continue;
    final result = LocalPhotoAnalyzer.analyzeBytes(
      await file.readAsBytes(),
      target: 'WA 10-ringen',
      expectedArrows: 3,
      trace: (v) => stdout.writeln(v),
    );
    stdout.writeln(
      '${file.uri.pathSegments.last}: target=${result.geometry != null} '
      'hits=${result.proposals.length} '
      'scores=${result.proposals.map((p) => p.score.label).join(",")}',
    );
    if (result.preview == null) continue;
    final image = img.decodeJpg(result.preview!)!;
    final g = result.geometry;
    if (g != null) {
      final c = g.imagePoint(0, 0);
      img.drawCircle(
        image,
        x: c.x.round(),
        y: c.y.round(),
        radius: 5,
        color: img.ColorRgb8(0, 255, 0),
      );
      for (final p in result.proposals) {
        final pos = g.imagePoint(p.x * 2 - 1, p.y * 2 - 1);
        img.drawCircle(
          image,
          x: pos.x.round(),
          y: pos.y.round(),
          radius: 10,
          color: img.ColorRgb8(255, 0, 255),
        );
      }
    }
    await File(
      '${output.path}/${index++}.jpg',
    ).writeAsBytes(img.encodeJpg(image));
  }
}
