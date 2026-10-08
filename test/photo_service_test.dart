import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:de_schutter/domain/scorecard.dart';
import 'package:de_schutter/features/photo/photo_analyzer.dart';
import 'package:de_schutter/features/photo/photo_service.dart';

void main() {
  test(
    'desktop lists saved photos for the requested card and end only',
    () async {
      final root = await Directory.systemTemp.createTemp('de-schutter-photos-');
      try {
        final directory = await Directory('${root.path}/photos').create();
        final capture = PhotoCapture(
          id: 'one',
          cardId: 'card',
          endIndex: 1,
          fileName: 'one.png',
          createdAt: DateTime.utc(2026),
        );
        await File('${directory.path}/one.png').writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jX1kAAAAASUVORK5CYII=',
          ),
        );
        await File(
          '${directory.path}/one.json',
        ).writeAsString(jsonEncode(capture.toJson()));
        final photos = PhotoService(root);
        final saved = (await photos.list('card', 1)).single;
        expect(saved.capture.id, 'one');
        expect(await photos.readReview(saved), isNull);
        await photos.saveReview(saved, {'hits': [], 'engine': 'test'});
        expect((await photos.readReview(saved))!['engine'], 'test');
        expect((await photos.list('card', 1)).single.capture.id, 'one');
        expect(await photos.list('other', 1), isEmpty);
        expect(await photos.list('card', 0), isEmpty);
        await expectLater(
          photos.capture(
            Scorecard.create(shooter: 'Bas'),
            0,
            ImageSource.camera,
          ),
          throwsUnsupportedError,
        );
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
