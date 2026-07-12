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
    if (hands.isEmpty) return "Scanning...";

    String result = "";
    for (int i = 0; i < hands.length; i++) {
      final hand = hands[i];
      String label = hands.length > 1 ? "H${i + 1}" : "";
      
      String handGesture = _analyzeSingleHand(hand, posePoints, imageSize);
      result += "${label.isNotEmpty ? '$label: ' : ''}$handGesture   ";
    }

    if (hands.length >= 2) {
      if (_isBothHandsFists(hands)) {
        final h1 = hands[0].landmarks[0];
        final h2 = hands[1].landmarks[0];
        final d = math.sqrt(math.pow(h1.x - h2.x, 2) + math.pow(h1.y - h2.y, 2));
        if (d < 0.15) return "SIGN: STOP / BERHENTI";
      }
    }

    return result.trim();
  }

  static String _analyzeSingleHand(Hand hand, Map<PoseLandmarkType, PoseLandmark>? pose, Size? size) {
    final points = hand.landmarks;
    if (points.length < 21) return "...";

    // 1. Finger extension (Vector distance logic)
    bool iUp = _isExtended(points, 8, 6);
    bool mUp = _isExtended(points, 12, 10);
    bool rUp = _isExtended(points, 16, 14);
    bool pUp = _isExtended(points, 20, 18);
    bool tUp = _dist(points[4].x, points[4].y, points[5].x, points[5].y) > 0.07;

    // 2. Body-Relative Context (Unified Coordinate Space)
    if (pose != null && pose.isNotEmpty && size != null) {
      final nose = pose[PoseLandmarkType.nose];
      final lSh = pose[PoseLandmarkType.leftShoulder];
      final rSh = pose[PoseLandmarkType.rightShoulder];

      if (lSh != null && rSh != null) {
        // Normalize Body points to 0..1 Screen space
        // This math matches PosePainter's translation logic for 270deg rotation
        double noseX = 1.0 - (nose!.x / size.height);
        double noseY = nose.y / size.width;
        
        double lsX = 1.0 - (lSh.x / size.height);
        double rsX = 1.0 - (rSh.x / size.height);
        double lsY = lSh.y / size.width;
        double rsY = rSh.y / size.width;

        // Dynamic Ruler: Shoulder width in normalized space
        double sw = math.sqrt(math.pow(lsX - rsX, 2) + math.pow(lsY - rsY, 2));
        
        // Hand coordinates (already 0..1 Screen space)
        double hx = points[0].x; 
        double hy = points[0].y;
        double tx = points[8].x; // Index tip for pointing
        double ty = points[8].y;

        // THINK Sign: Index tip near the nose dot
        if (iUp && !mUp) {
          double dToHead = math.sqrt(math.pow(tx - noseX, 2) + math.pow(ty - noseY, 2));
          if (dToHead / sw < 0.5) return "THINK";
        }
        
        // SAYA Sign: Hand near the chest (midpoint between normalized shoulders)
        double midX = (lsX + rsX) / 2;
        double midY = (lsY + rsY) / 2 + (sw * 0.3);
        if (tUp && !iUp) {
          double dToChest = math.sqrt(math.pow(hx - midX, 2) + math.pow(hy - midY, 2));
          if (dToChest / sw < 0.45) return "SAYA";
        }
      }
    }

    // 3. Defaults
    if (iUp && mUp && rUp && pUp && tUp) return "OPEN";
    if (tUp && !iUp && !mUp && !rUp && !pUp) return "GOOD";
    if (iUp && mUp && !rUp && !pUp) return "PEACE";
    if (iUp && !mUp && !rUp && !pUp) return "POINT";
    if (!iUp && !mUp && !rUp && !pUp) return "FIST";

    return "HAND";
  }

  static bool _isExtended(List<Landmark> p, int tip, int joint) {
    return _dist(p[tip].x, p[tip].y, p[0].x, p[0].y) > _dist(p[joint].x, p[joint].y, p[0].x, p[0].y) + 0.02;
  }

  static bool _isBothHandsFists(List<Hand> hands) {
    for (var h in hands) {
      if (_isExtended(h.landmarks, 8, 6)) return false;
    }
    return true;
  }

  static double _dist(double x1, double y1, double x2, double y2) => math.sqrt(math.pow(x1 - x2, 2) + math.pow(y1 - y2, 2));
}
