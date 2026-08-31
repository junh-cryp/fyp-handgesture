import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

// DESCRIPTION: Data structure to hold the result of a gesture analysis
class GestureResult {
  final String word;
  final double confidence; // 0.0 to 1.0 (DESCRIPTION: Represents the accuracy of the detection)

  GestureResult(this.word, this.confidence);

  static GestureResult empty() => GestureResult("", 0.0);
}

class GestureLogic {
  // DESCRIPTION: Main function for gesture translation and accuracy calculation
  static GestureResult analyzeGestures({
    required List<Hand> hands,
    Map<PoseLandmarkType, PoseLandmark>? posePoints,
    required Size? imageSize,
  }) {
    if (hands.isEmpty) return GestureResult.empty();

    // DESCRIPTION: ACCURACY - Base landmark tracking confidence from ML models
    double poseConf = 1.0;
    if (posePoints != null && posePoints.isNotEmpty) {
      int count = 0;
      double sum = 0;
      posePoints.forEach((_, p) {
        sum += p.likelihood;
        count++;
      });
      poseConf = count > 0 ? sum / count : 1.0;
    }

    // DESCRIPTION: TRANSLATE - Two-Hand Combined Gestures logic
    if (hands.length >= 2) {
      final r1 = _analyzeSingleHandWithScore(hands[0], posePoints, imageSize);
      final r2 = _analyzeSingleHandWithScore(hands[1], posePoints, imageSize);
      final s1 = r1.word;
      final s2 = r2.word;

      String combined = "";
      if (s1 == "BAGUS" && s2 == "BAGUS") {
        combined = "APA KHABAR";
      } else if (s1 == "AMAN" && s2 == "AMAN") {
        combined = "NAMA";
      } else if (s1 == "Berhenti" && s2 == "Berhenti") {
        combined = "BOLEH";
      } else if (s1 == "Hai" && s2 == "Hai") {
        combined = "TIDAK ADA";
      } else if (s1 == "TIDAK BOLEH" && s2 == "TIDAK BOLEH") {
        combined = "BENANG";
      }

      if (combined.isNotEmpty) {
        // DESCRIPTION: ACCURACY - Averaging individual hand scores with pose confidence
        double avgScore = (r1.confidence + r2.confidence) / 2;
        return GestureResult(combined, (avgScore * 0.7 + poseConf * 0.3).clamp(0.0, 1.0));
      }

      // DESCRIPTION: TRANSLATE - Specific logic for IMEJ (Pinky on Palm)
      bool isH1 = (s1 == "Hai" || s1 == "BERHENTI");
      bool isH2 = (s2 == "Hai" || s2 == "BERHENTI");
      bool isT1 = (s1 == "TIDAK BOLEH");
      bool isT2 = (s2 == "TIDAK BOLEH");
      if ((isH1 && isT2) || (isH2 && isT1)) {
        final haiHand = isH1 ? hands[0] : hands[1];
        final tbHand = isT1 ? hands[0] : hands[1];
        final d = _dist(haiHand.landmarks[9].x, haiHand.landmarks[9].y, tbHand.landmarks[20].x, tbHand.landmarks[20].y);
        if (d < 0.20) {
          // DESCRIPTION: ACCURACY - Proximity-based score for IMEJ
          double matchScore = (1.0 - (d / 0.20)).clamp(0.5, 1.0);
          return GestureResult("IMEJ", (matchScore * 0.8 + poseConf * 0.2));
        }
      }
    }

    // DESCRIPTION: TRANSLATE - Single Hand Gestures fallback
    for (int i = 0; i < hands.length; i++) {
      final result = _analyzeSingleHandWithScore(hands[i], posePoints, imageSize);
      if (result.word.isNotEmpty) {
        // DESCRIPTION: ACCURACY - Single hand score combined with pose confidence
        return GestureResult(result.word, (result.confidence * 0.7 + poseConf * 0.3).clamp(0.0, 1.0));
      }
    }

    return GestureResult.empty();
  }

  // DESCRIPTION: Internal function to analyze a single hand and assign an accuracy score
  static GestureResult _analyzeSingleHandWithScore(Hand hand, Map<PoseLandmarkType, PoseLandmark>? pose, Size? size) {
    final rawPoints = hand.landmarks;
    if (rawPoints.length < 21) return GestureResult.empty();

    final points = rawPoints.map((p) => Offset(1.0 - p.x, p.y)).toList();

    // Finger state detection
    bool iUp = _isExtendedLocal(points, 8, 6);
    bool mUp = _isExtendedLocal(points, 12, 10);
    bool rUp = _isExtendedLocal(points, 16, 14);
    bool pUp = _isExtendedLocal(points, 20, 18);
    bool tUp = _dist(points[4].dx, points[4].dy, points[5].dx, points[5].dy) > 0.07;

    double idx = (points[8].dx - points[5].dx).abs();
    double idy = (points[8].dy - points[5].dy).abs();
    bool indexVertical = idy > idx * 1.5;
    bool indexHorizontal = idx > idy;

    if (pose != null && pose.isNotEmpty && size != null) {
      final sw = _getShoulderWidth(pose, size);
      final chest = _getChestPoint(pose, size);
      final mouth = _getMouthPoint(pose, size);
      Offset p2s(PoseLandmark p) => Offset(1.0 - (p.y / size.width), p.x / size.height);

      // DESCRIPTION: TRANSLATE - DIAM (Index finger to mouth)
      if (iUp && !mUp && !rUp && !pUp && indexHorizontal && mouth != null) {
        double d = _dist(points[8].dx, points[8].dy, mouth.dx, mouth.dy) / sw;
        if (d < 0.3) {
          // DESCRIPTION: ACCURACY - Proximity to mouth normalized by shoulder width
          double score = (1.0 - (d / 0.3)).clamp(0.7, 0.98);
          return GestureResult("DIAM", score);
        }
      }

      // DESCRIPTION: TRANSLATE - FIKIR (Index finger to eye/temple)
      if (iUp && !mUp && !rUp && !pUp && indexVertical) {
        final lEye = pose[PoseLandmarkType.leftEye];
        final rEye = pose[PoseLandmarkType.rightEye];
        if (lEye != null && rEye != null) {
          double d1 = _dist(points[8].dx, points[8].dy, p2s(lEye).dx, p2s(lEye).dy) / sw;
          double d2 = _dist(points[8].dx, points[8].dy, p2s(rEye).dx, p2s(rEye).dy) / sw;
          double minD = math.min(d1, d2);
          if (minD < 0.35) {
            // DESCRIPTION: ACCURACY - Proximity to eyes
            double score = (1.0 - (minD / 0.35)).clamp(0.7, 0.98);
            return GestureResult("FIKIR", score);
          }
        }
      }

      // DESCRIPTION: TRANSLATE - SAYA (Index finger to chest)
      if (chest != null && iUp && !mUp && !rUp && !pUp && indexVertical) {
        double d = _dist(points[8].dx, points[8].dy, chest.dx, chest.dy) / sw;
        if (d < 0.45) {
          // DESCRIPTION: ACCURACY - Proximity to chest
          double score = (1.0 - (d / 0.45)).clamp(0.7, 0.98);
          return GestureResult("SAYA", score);
        }
      }
    }

    // DESCRIPTION: TRANSLATE - Default pattern-based simple detections
    if (!iUp && !mUp && !rUp && pUp) return GestureResult("TIDAK BOLEH", 0.95);
    if (tUp && iUp && !mUp && !rUp && !pUp) return GestureResult("BELI", 0.92);

    if (iUp && mUp && rUp && pUp) {
      double dx = (points[9].dx - points[0].dx).abs();
      double dy = (points[9].dy - points[0].dy).abs();
      if (dy > dx * 1.2) return GestureResult("BERHENTI", 0.90);
      return GestureResult("Hai", 0.88);
    }

    if (tUp && !iUp && !mUp && !rUp && !pUp) return GestureResult("BAGUS", 0.96);
    if (iUp && mUp && !rUp && !pUp) return GestureResult("AMAN", 0.94);
    if (iUp && !mUp && !rUp && !pUp) return GestureResult("SANA", 0.85);
    if (!iUp && !mUp && !rUp && !pUp) return GestureResult("Berhenti", 0.80);

    return GestureResult.empty();
  }

  // DESCRIPTION: Helper functions for body landmark mapping and distance
  static Offset? _getChestPoint(Map<PoseLandmarkType, PoseLandmark> pose, Size size) {
    final lSh = pose[PoseLandmarkType.leftShoulder];
    final rSh = pose[PoseLandmarkType.rightShoulder];
    if (lSh == null || rSh == null) return null;
    double lsX = 1.0 - (lSh.y / size.width);
    double rsX = 1.0 - (rSh.y / size.width);
    double lsY = lSh.x / size.height;
    double rsY = rSh.x / size.height;
    double midX = (lsX + rsX) / 2;
    double midY = (lsY + rsY) / 2;
    final lH = pose[PoseLandmarkType.leftHip];
    final rH = pose[PoseLandmarkType.rightHip];
    if (lH != null && rH != null && lH.likelihood > 0.4) {
      double lhY = lH.x / size.height;
      double rhY = rH.x / size.height;
      midY = midY + ((lhY + rhY) / 2 - midY) * 0.18;
    } else {
      midY += (_dist(lsX, lsY, rsX, rsY) * 0.22);
    }
    return Offset(midX, midY);
  }

  static Offset? _getMouthPoint(Map<PoseLandmarkType, PoseLandmark> pose, Size size) {
    final lM = pose[PoseLandmarkType.leftMouth];
    final rM = pose[PoseLandmarkType.rightMouth];
    if (lM == null || rM == null) return null;
    return Offset((1.0 - (lM.y / size.width) + 1.0 - (rM.y / size.width)) / 2, (lM.x / size.height + rM.x / size.height) / 2);
  }

  static double _getShoulderWidth(Map<PoseLandmarkType, PoseLandmark> pose, Size size) {
    final l = pose[PoseLandmarkType.leftShoulder];
    final r = pose[PoseLandmarkType.rightShoulder];
    if (l == null || r == null) return 0.2;
    return _dist(1.0 - (l.y / size.width), l.x / size.height, 1.0 - (r.y / size.width), r.x / size.height);
  }

  static bool _isExtendedLocal(List<Offset> p, int tip, int joint) {
    return _dist(p[tip].dx, p[tip].dy, p[0].dx, p[0].dy) > _dist(p[joint].dx, p[joint].dy, p[0].dx, p[0].dy) + 0.02;
  }

  static double _dist(double x1, double y1, double x2, double y2) => math.sqrt(math.pow(x1 - x2, 2) + math.pow(y1 - y2, 2));
}
