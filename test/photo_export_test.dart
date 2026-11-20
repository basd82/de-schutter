import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:de_schutter/domain/scorecard.dart';
import 'package:de_schutter/features/export/photo_export.dart';
import 'package:de_schutter/features/photo/photo_analyzer.dart';
import 'package:de_schutter/features/photo/photo_service.dart';

void main() {
  test(
    'ZIP contains original images, reviewed metadata and selected card only',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'schutter-export-test-',
      );
      try {
        final card = Scorecard.create(
          shooter: 'Bas',
          endCount: 2,
        ).setArrow(0, 0, Score.parse('8'));
        final directory = await Directory('${root.path}/photos').create();
        for (final id in ['one', 'two', 'other']) {
          final capture = PhotoCapture(
            id: id,
            cardId: id == 'other' ? 'other-card' : card.id,
            endIndex: id == 'two' ? 1 : 0,
            fileName: '$id.jpg',
            createdAt: DateTime.utc(2026),
          );
          await File('${directory.path}/$id.jpg').writeAsBytes([1, 2, 3, 255]);
          await File('${directory.path}/$id.json').writeAsString(
            jsonEncode({
              ...capture.toJson(),
              'review': {
                'engine': 'test',
                'hits': [
                  {'score': '8', 'corrected': true},
                ],
              },
            }),
          );
        }
        final zip = await PhotoExport.create(card, PhotoService(root), root);
        final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
        expect(
          archive.files.map((f) => f.name),
          unorderedEquals([
            'scorekaart.json',
            'LEESMIJ.txt',
            'photos/serie-1/foto-1.jpg',
            'photos/serie-1/foto-1.jpg.json',
            'photos/serie-2/foto-1.jpg',
            'photos/serie-2/foto-1.jpg.json',
          ]),
        );
        final image = archive.findFile('photos/serie-1/foto-1.jpg')!;
        expect(image.content, [1, 2, 3, 255]);
        final scores = jsonDecode(
          utf8.decode(archive.findFile('scorekaart.json')!.content),
        );
        expect(Scorecard.fromJson(scores).total, 8);
        final metadata = jsonDecode(
          utf8.decode(
            archive.findFile('photos/serie-1/foto-1.jpg.json')!.content,
          ),
        );
        expect(metadata['review']['hits'][0]['corrected'], isTrue);
        expect(metadata['fileName'], 'photos/serie-1/foto-1.jpg');
        final empty = await PhotoExport.create(
          Scorecard.create(shooter: 'Geen foto'),
          PhotoService(root),
          root,
        );
        expect(
          ZipDecoder().decodeBytes(await empty.readAsBytes()).files.length,
          2,
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
