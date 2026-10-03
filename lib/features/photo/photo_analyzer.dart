import 'dart:io';

import '../../domain/scorecard.dart';

class ArrowProposal {
  const ArrowProposal({
    required this.x,
    required this.y,
    required this.score,
    required this.confidence,
    this.needsReview = true,
  });

  /// Coordinates in the rectified target plane, normalized to [0, 1].
  final double x, y;
  final Score score;

  /// Only show calibrated confidence from a validated model.
  final double confidence;
  final bool needsReview;
}

class PhotoAnalysis {
  const PhotoAnalysis({
    required this.proposals,
    required this.message,
    required this.available,
  });
  final List<ArrowProposal> proposals;
  final String message;
  final bool available;
}

abstract interface class PhotoAnalyzer {
  Future<PhotoAnalysis> analyze(
    File photo, {
    required String target,
    required int expectedArrows,
  });
}

/// Explicit foundation for the future on-device engine. No fabricated results.
class PendingPhotoAnalyzer implements PhotoAnalyzer {
  @override
  Future<PhotoAnalysis> analyze(
    File photo, {
    required String target,
    required int expectedArrows,
  }) async => const PhotoAnalysis(
    proposals: [],
    available: false,
    message: 'Automatische herkenning is nog in ontwikkeling. Vul de scores handmatig in; de foto blijft lokaal bewaard.',
  );
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
