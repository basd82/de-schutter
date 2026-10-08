import 'dart:io';
import 'dart:typed_data';

import 'target_geometry.dart';

import '../../domain/scorecard.dart';

class ArrowProposal {
  const ArrowProposal({
    required this.x,
    required this.y,
    required this.score,
    required this.confidence,
    this.needsReview = true,
    this.lineCase = false,
  });

  /// Coordinates in the rectified target plane, normalized to [0, 1].
  final double x, y;
  final Score score;

  /// Zero means uncalibrated; never present it as a probability.
  final double confidence;
  final bool needsReview;
  final bool lineCase;
}

class PhotoAnalysis {
  const PhotoAnalysis({
    required this.proposals,
    required this.message,
    required this.available,
    this.geometry,
    this.preview,
    this.imageWidth = 0,
    this.imageHeight = 0,
  });
  final List<ArrowProposal> proposals;
  final String message;
  final bool available;
  final TargetGeometry? geometry;
  final Uint8List? preview;
  final int imageWidth, imageHeight;
}

abstract interface class PhotoAnalyzer {
  Future<PhotoAnalysis> analyze(
    File photo, {
    required String target,
    required int expectedArrows,
  });
}

class PhotoCapture {
  const PhotoCapture({
    required this.id,
    required this.cardId,
    required this.endIndex,
    required this.fileName,
    required this.createdAt,
  });
  final String id, cardId, fileName;
  final int endIndex;
  final DateTime createdAt;
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'cardId': cardId,
    'endIndex': endIndex,
    'fileName': fileName,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}
