import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../../domain/scorecard.dart';
import 'photo_analyzer.dart';

class SavedPhoto {
  const SavedPhoto(this.file, this.capture);
  final File file;
  final PhotoCapture capture;
}

class PhotoService {
  PhotoService(this.root, {ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final Directory root;
  final ImagePicker _picker;
  static bool get supported => Platform.isAndroid || Platform.isIOS;
  File get _pending => File('${root.path}/pending-capture.json');

  Future<SavedPhoto> _persist(
    XFile selected,
    String cardId,
    int endIndex,
  ) async {
    final now = DateTime.now().toUtc();
    final id = now.microsecondsSinceEpoch.toString();
    final directory = Directory('${root.path}/photos');
    await directory.create(recursive: true);
    final extension = selected.path.split('.').last.toLowerCase();
    final safeExtension =
        ['jpg', 'jpeg', 'png', 'heic', 'webp'].contains(extension)
        ? extension
        : 'jpg';
    final file = File('${directory.path}/$id.$safeExtension');
    await selected.saveTo(file.path);
    final capture = PhotoCapture(
      id: id,
      cardId: cardId,
      endIndex: endIndex,
      fileName: '$id.$safeExtension',
      createdAt: now,
    );
    await File('${directory.path}/$id.json')
        .writeAsString(jsonEncode(capture.toJson()), flush: true);
    return SavedPhoto(file, capture);
  }

  Future<SavedPhoto?> capture(
    Scorecard card,
    int endIndex,
    ImageSource source,
  ) async {
    if (!supported && source == ImageSource.camera) {
      throw UnsupportedError('Foto maken is alleen beschikbaar op mobiel.');
    }
    await root.create(recursive: true);
    await _pending.writeAsString(
      jsonEncode({'cardId': card.id, 'endIndex': endIndex}),
      flush: true,
    );
    final selected = await _picker.pickImage(
      source: source,
      requestFullMetadata: false,
    );
    final saved = selected == null
        ? null
        : await _persist(selected, card.id, endIndex);
    if (await _pending.exists()) {
      await _pending.delete();
    }
    return saved;
  }

  /// Android can restart the activity while the system camera is open.
  Future<SavedPhoto?> recover() async {
    if (!Platform.isAndroid || !await _pending.exists()) {
      return null;
    }
    final context =
        jsonDecode(await _pending.readAsString()) as Map<String, dynamic>;
    final lost = await _picker.retrieveLostData();
    if (lost.exception != null) {
      throw lost.exception!;
    }
    final files = lost.files;
    final saved = files == null || files.isEmpty
        ? null
        : await _persist(
            files.first,
            context['cardId'] as String,
            context['endIndex'] as int,
          );
    await _pending.delete();
    return saved;
  }

  Future<Map<String, dynamic>?> readReview(SavedPhoto photo) async {
    final file = File('${root.path}/photos/${photo.capture.id}.json');
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return json['review'] == null
        ? null
        : Map<String, dynamic>.from(json['review'] as Map);
  }

  Future<void> saveReview(SavedPhoto photo, Map<String, dynamic> review) async {
    final file = File('${root.path}/photos/${photo.capture.id}.json');
    final next = File('${file.path}.tmp');
    await next.writeAsString(
      jsonEncode({...photo.capture.toJson(), 'review': review}),
      flush: true,
    );
    await next.rename(file.path);
  }

  Future<List<SavedPhoto>> list(String cardId, int endIndex) async {
    final directory = Directory('${root.path}/photos');
    if (!await directory.exists()) {
      return [];
    }
    final result = <SavedPhoto>[];
    await for (final file in directory.list()) {
      if (file is! File || !file.path.endsWith('.json')) {
        continue;
      }
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (json['cardId'] != cardId || json['endIndex'] != endIndex) {
        continue;
      }
      final name = json['fileName'] as String;
      if (name.contains('/') || name.contains('\\')) {
        throw const FormatException('Ongeldig fotopad.');
      }
      final image = File('${directory.path}/$name');
      if (!await image.exists()) {
        continue;
      }
      result.add(
        SavedPhoto(
          image,
          PhotoCapture(
            id: json['id'] as String,
            cardId: cardId,
            endIndex: endIndex,
            fileName: name,
            createdAt: DateTime.parse(json['createdAt'] as String),
          ),
        ),
      );
    }
    result.sort((a, b) => b.capture.createdAt.compareTo(a.capture.createdAt));
    return result;
  }
}
