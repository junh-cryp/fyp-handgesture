import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

class GestureLogic {
  static String analyzeGestures({
    required List<Hand> hands,
    Map<PoseLandmarkType, PoseLandmark>? posePoints,
    required Size? imageSize,
  }) {
    if (hands.isEmpty) return "";

    List<String> results = [];
    for (int i = 0; i < hands.length; i++) {
      final hand = hands[i];
      String handGesture = _analyzeSingleHand(hand, posePoints, imageSize);
      if (handGesture.isNotEmpty) {
        results.add(handGesture);
      }
    }

    if (hands.length >= 2) {
      String s1 = _analyzeSingleHand(hands[0], posePoints, imageSize);
      String s2 = _analyzeSingleHand(hands[1], posePoints, imageSize);

      if (s1 == "BAGUS" && s2 == "BAGUS") return "APA KHABAR";
      if (s1 == "AMAN" && s2 == "AMAN") return "NAMA";
      if (s1 == "Berhenti" && s2 == "Berhenti") return "BOLEH";
      if (s1 == "Hai" && s2 == "Hai") return "TIDAK ADA";
      if (s1 == "TIDAK BOLEH" && s2 == "TIDAK BOLEH") return "BENANG";

      if (posePoints != null && posePoints.isNotEmpty && imageSize != null) {
        final chest = _getChestPoint(posePoints, imageSize);
        if (chest != null) {
          final sw = _getShoulderWidth(posePoints, imageSize);
          bool h1Stop = (s1 == "Hai" || s1 == "TIDAK BOLEH" || s1 == "BAGUS" || s1 == "BERHENTI");
          bool h2Stop = (s2 == "Hai" || s2 == "TIDAK BOLEH" || s2 == "BAGUS" || s2 == "BERHENTI");

          if (h1Stop && h2Stop) {
            final h1 = hands[0].landmarks[0];
            final h2 = hands[1].landmarks[0];
            final h1s = Offset(1.0 - h1.x, h1.y);
            final h2s = Offset(1.0 - h2.x, h2.y);
            final d = _dist(h1s.dx, h1s.dy, h2s.dx, h2s.dy);
            final dToChest = _dist((h1s.dx + h2s.dx) / 2, (h1s.dy + h2s.dy) / 2, chest.dx, chest.dy);
            if (d < 0.25 && dToChest / sw < 0.6) return "BERHENTI";
          }
        }
      }
    }

    return results.join(" ");
  }

  static String _analyzeSingleHand(Hand hand, Map<PoseLandmarkType, PoseLandmark>? pose, Size? size) {
    final rawPoints = hand.landmarks;
    if (rawPoints.length < 21) return "";

    // Hand points (from plugin) are usually upright/mirrored correctly
    final points = rawPoints.map((p) => Offset(1.0 - p.x, p.y)).toList();

    bool iUp = _isExtendedLocal(points, 8, 6);
    bool mUp = _isExtendedLocal(points, 12, 10);
    bool rUp = _isExtendedLocal(points, 16, 14);
    bool pUp = _isExtendedLocal(points, 20, 18);
    bool tUp = _dist(points[4].dx, points[4].dy, points[5].dx, points[5].dy) > 0.07;
    
    // Vertical distance (y is smaller at top) vs Horizontal distance
    double tdy = (points[2].dy - points[4].dy); // positive if tip is above base
    double tdx = (points[4].dx - points[2].dx).abs();
    // Allow for more tilt (tdy > tdx * 0.5) to handle "inward" pointing thumbs
    bool tPointingUp = tUp && tdy > 0.03 && tdy > (tdx * 0.5);

    // Index orientation
    double idx = (points[8].dx - points[5].dx).abs();
    double idy = (points[8].dy - points[5].dy).abs();
    bool indexVertical = idy > idx * 1.5;
    bool indexHorizontal = idx > idy;

    double? shY;
    double sw = 0.2;

    if (pose != null && pose.isNotEmpty && size != null) {
      sw = _getShoulderWidth(pose, size);
      final chest = _getChestPoint(pose, size);
      
      final lSh = pose[PoseLandmarkType.leftShoulder];
      final rSh = pose[PoseLandmarkType.rightShoulder];
      if (lSh != null && rSh != null) {
        shY = (lSh.x + rSh.x) / (2 * size.height); // Screen Y
      }

      // Helper for Pose -> Screen mapping (Mirror Horizontal)
      Offset p2s(PoseLandmark p) => Offset(1.0 - (p.y / size.width), p.x / size.height);

      // DIAM Sign: Index strictly vertical near mouth
      if (iUp && !mUp && !rUp && !pUp && indexHorizontal) {
        final mouth = _getMouthPoint(pose, size);
        if (mouth != null) {
          if (_dist(points[8].dx, points[8].dy, mouth.dx, mouth.dy) / sw < 0.3) return "DIAM";
        }
      }

      // THINK Sign: Index mostly horizontal near eye
      if (iUp && !mUp && !rUp && !pUp && indexVertical) {
        final lEye = pose[PoseLandmarkType.leftEye];
        final rEye = pose[PoseLandmarkType.rightEye];
        if (lEye != null && rEye != null) {
          final le = p2s(lEye);
          final re = p2s(rEye);
          if (_dist(points[8].dx, points[8].dy, le.dx, le.dy) / sw < 0.35 || 
              _dist(points[8].dx, points[8].dy, re.dx, re.dy) / sw < 0.35) return "FIKIR";
        }
      }

      // SAYA Sign: Pointing to chest
      if (chest != null && iUp && !mUp && !rUp && !pUp) {
        if (_dist(points[8].dx, points[8].dy, chest.dx, chest.dy) / sw < 0.45) return "SAYA";
      }

      // MINUM vs BAGUS
      if (tUp && !iUp && !mUp && !rUp && !pUp) {
        final lMouth = pose[PoseLandmarkType.leftMouth];
        final rMouth = pose[PoseLandmarkType.rightMouth];
        if (lMouth != null && rMouth != null) {
          final lmS = p2s(lMouth);
          final rmS = p2s(rMouth);
          final mX = (lmS.dx + rmS.dx) / 2;
          final mY = (lmS.dy + rmS.dy) / 2;

          // If near mouth and thumb is horizontal-ish -> MINUM
          if (_dist(points[4].dx, points[4].dy, mX, mY) / sw < 0.35 && tdy < tdx) return "MINUM";
        }
        
        if (tPointingUp) return "BAGUS";
        if (shY != null && (points[0].dy - shY).abs() < 0.15) return "BAGUS";
      }
    }

    if (!iUp && !mUp && !rUp && pUp) return "TIDAK BOLEH";
    if (tUp && iUp && !mUp && !rUp && !pUp) return "BELI";

    if (iUp && mUp && rUp && pUp) {
      double dx = (points[9].dx - points[0].dx).abs();
      double dy = (points[9].dy - points[0].dy).abs();
      if (dy > dx * 1.2) {
        if (shY != null && points[0].dy > shY + 0.05) return "";
        return "BERHENTI";
      }
      return "Hai";
    }

    if (tUp && !iUp && !mUp && !rUp && !pUp) return "BAGUS";
    if (iUp && mUp && !rUp && !pUp) return "AMAN";
    if (!iUp && !mUp && !rUp && !pUp) return "Berhenti";
    if (iUp && !mUp && !rUp && !pUp) return "SANA";

    return "";
  }

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
      double lhX = 1.0 - (lH.y / size.width);
      double rhX = 1.0 - (rH.y / size.width);
      double lhY = lH.x / size.height;
      double rhY = rH.x / size.height;
      midX = midX + ((lhX + rhX) / 2 - midX) * 0.27;
      midY = midY + ((lhY + rhY) / 2 - midY) * 0.27;
    } else {
      double sw = _dist(lsX, lsY, rsX, rsY);
      midY += (sw * 0.35);
    }
    return Offset(midX, midY);
  }

  static Offset? _getMouthPoint(Map<PoseLandmarkType, PoseLandmark> pose, Size size) {
    final lMouth = pose[PoseLandmarkType.leftMouth];
    final rMouth = pose[PoseLandmarkType.rightMouth];
    if (lMouth == null || rMouth == null) return null;

    double lmX = 1.0 - (lMouth.y / size.width);
    double rmX = 1.0 - (rMouth.y / size.width);
    double lmY = lMouth.x / size.height;
    double rmY = rMouth.x / size.height;

    return Offset((lmX + rmX) / 2, (lmY + rmY) / 2);
  }

  static double _getShoulderWidth(Map<PoseLandmarkType, PoseLandmark> pose, Size size) {
    final lSh = pose[PoseLandmarkType.leftShoulder];
    final rSh = pose[PoseLandmarkType.rightShoulder];
    if (lSh == null || rSh == null) return 0.2;
    double lsX = 1.0 - (lSh.y / size.width);
    double rsX = 1.0 - (rSh.y / size.width);
    double lsY = lSh.x / size.height;
    double rsY = rSh.x / size.height;
    return _dist(lsX, lsY, rsX, rsY);
  }

  static bool _isExtendedLocal(List<Offset> p, int tip, int joint) {
    return _dist(p[tip].dx, p[tip].dy, p[0].dx, p[0].dy) > 
           _dist(p[joint].dx, p[joint].dy, p[0].dx, p[0].dy) + 0.02;
  }

  static double _dist(double x1, double y1, double x2, double y2) =>
      math.sqrt(math.pow(x1 - x2, 2) + math.pow(y1 - y2, 2));
}
