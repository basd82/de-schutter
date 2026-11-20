import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

import '../../domain/scorecard.dart';
import '../photo/photo_service.dart';

/// A portable analysis package. Original photos are never re-encoded.
class PhotoExport {
  static Future<File> create(
    Scorecard card,
    PhotoService photos,
    Directory destination,
  ) async {
    final entries = <({String path, String name, String metadata})>[];
    for (var end = 0; end < card.ends.length; end++) {
      final saved = await photos.list(card.id, end);
      for (var i = 0; i < saved.length; i++) {
        final photo = saved[i];
        final extension = photo.capture.fileName.split('.').last;
        final name = 'photos/serie-${end + 1}/foto-${i + 1}.$extension';
        entries.add((
          path: photo.file.path,
          name: name,
          metadata: jsonEncode({
            ...photo.capture.toJson(),
            'fileName': name,
            'review': await photos.readReview(photo),
          }),
        ));
      }
    }
    final json = card.exportJson();
    final directory = await destination.createTemp('de-schutter-export-');
    final output = '${directory.path}/de-schutter-met-fotos.zip';
    try {
      await Isolate.run(() {
        final zip = ZipFileEncoder()..create(output);
        void text(String name, String value) {
          final bytes = utf8.encode(value);
          zip.addArchiveFile(ArchiveFile(name, bytes.length, bytes));
        }

        try {
          text('scorekaart.json', json);
          text(
            'LEESMIJ.txt',
            'De Schutter: scorekaart met originele foto’s.\n'
                'De mappen serie-1, serie-2, enz. horen bij de series op de kaart.\n'
                'Bij elke foto staat JSON met detecties en handmatige correcties, indien bewaard.\n'
                'De scorekaart bevat de definitieve scores.\n'
                'Dit ZIP-bestand is voor delen/analyse; importeer scorekaart.json via JSON-import.\n'
                'Foto’s worden bij die JSON-import niet teruggezet.\n',
          );
          for (final entry in entries) {
            zip.addFileSync(File(entry.path), entry.name);
            text('${entry.name}.json', entry.metadata);
          }
        } finally {
          zip.closeSync();
        }
      });
      return File(output);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }
}
