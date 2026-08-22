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

      // 1. Two "GOOD" signs = APA KHABAR
      if (s1 == "BAGUS" && s2 == "BAGUS") return "APA KHABAR";

      // 2. Two "AMAN" signs = NAMA
      if (s1 == "AMAN" && s2 == "AMAN") return "NAMA";

      // 3. Two fists = BOLEH
      if (s1 == "Berhenti" && s2 == "Berhenti") {
        if (posePoints != null && imageSize != null) {
          final chest = _getChestPoint(posePoints, imageSize);
          if (chest != null) {
            final h1 = hands[0].landmarks[0];
            final h2 = hands[1].landmarks[0];
            final d = _dist(h1.x, h1.y, h2.x, h2.y);
          }
        }
        return "BOLEH";
      }

      //4. Two "HAI" signs = TIDAK ADA
      if (s1 == "Hai" && s2 == "Hai") return "TIDAK ADA";

      //5. Two "Pinky" = BENANG
      if((s1== "TIDAK BOLEH" || s1 == "TIDAK BOLEH") && (s2 == "TIDAK BOLEH" || s2== "TIDAK BOLEH")) return "BENANG";


      // Check for body context for two-handed signs
      if (posePoints != null && posePoints.isNotEmpty && imageSize != null) {
        final chest = _getChestPoint(posePoints, imageSize);
        if (chest != null) {
          final sw = _getShoulderWidth(posePoints, imageSize);
          
          // 2. Two Fists logic already handled above by s1/s2 comparison
          // but we can add secondary check if needed.
          
          // 4. Any combination of Open hand (Hai/OK/BERHENTI) and Thumbs up (BAGUS) meeting near chest = BERHENTI
          bool h1Stop = (s1 == "Hai" || s1 == "TIDAK BOLEH" || s1 == "BAGUS" || s1 == "BERHENTI");
          bool h2Stop = (s2 == "Hai" || s2 == "TIDAK BOLEH" || s2 == "BAGUS" || s2 == "BERHENTI");
          // If both are BAGUS, it already returned "APA KHABAR" at the start,
          // so this handles Hai+Hai, Hai+BAGUS, BERHENTI+Hai, etc.
          if (h1Stop && h2Stop) {
            final h1 = hands[0].landmarks[0];
            final h2 = hands[1].landmarks[0];
            final d = _dist(h1.x, h1.y, h2.x, h2.y);
            final dToChest = _dist((h1.x + h2.x) / 2, (h1.y + h2.y) / 2, chest.dx, chest.dy);
            
            if (d < 0.25 && dToChest / sw < 0.6) return "BERHENTI";
          }
        }
      }
    }

    return results.join(" ");
  }

  static String _analyzeSingleHand(Hand hand, Map<PoseLandmarkType, PoseLandmark>? pose, Size? size) {
    final points = hand.landmarks;
    if (points.length < 21) return "";

    bool iUp = _isExtended(points, 8, 6);
    bool mUp = _isExtended(points, 12, 10);
    bool rUp = _isExtended(points, 16, 14);
    bool pUp = _isExtended(points, 20, 18);
    bool tUp = _dist(points[4].x, points[4].y, points[5].x, points[5].y) > 0.07;

    double? shY; // Shoulder level for height check

    if (pose != null && pose.isNotEmpty && size != null) {
      final sw = _getShoulderWidth(pose, size);
      final chest = _getChestPoint(pose, size);

      final lSh = pose[PoseLandmarkType.leftShoulder];
      final rSh = pose[PoseLandmarkType.rightShoulder];
      if (lSh != null && rSh != null) {
        shY = (lSh.y / size.width + rSh.y / size.width) / 2;
      }
      
      double tx = points[8].x; 
      double ty = points[8].y;

      // THINK Sign: Index tip near eye
      if (iUp && !mUp && !rUp && !pUp) {
        final lEye = pose[PoseLandmarkType.leftEye];
        final rEye = pose[PoseLandmarkType.rightEye];
        if (lEye != null && rEye != null) {
          double leX = 1.0 - (lEye.x / size.height);
          double reX = 1.0 - (rEye.x / size.height);
          double leY = lEye.y / size.width;
          double reY = rEye.y / size.width;

          double dToLE = _dist(tx, ty, leX, leY);
          double dToRE = _dist(tx, ty, reX, reY);

          if (dToLE / sw < 0.35 || dToRE / sw < 0.35) return "FIKIR";
        }
      }
      
      // SAYA Sign: Pointing to chest
      if (chest != null && iUp && !mUp && !rUp && !pUp) {
        double dToChest = _dist(tx, ty, chest.dx, chest.dy);
        if (dToChest / sw < 0.45) return "SAYA";
      }

      // MINUM Sign: Thumb near mouth
      if (tUp && !iUp && !mUp && !rUp && !pUp) {
        final lMouth = pose[PoseLandmarkType.leftMouth];
        final rMouth = pose[PoseLandmarkType.rightMouth];
        if (lMouth != null && rMouth != null) {
          double lmX = 1.0 - (lMouth.x / size.height);
          double rmX = 1.0 - (rMouth.x / size.height);
          double lmY = lMouth.y / size.width;
          double rmY = rMouth.y / size.width;
          double mX = (lmX + rmX) / 2;
          double mY = (lmY + rmY) / 2;
          if (_dist(points[4].x, points[4].y, mX, mY) / sw < 0.35) return "MINUM";
        }
      }
    }



    if (!iUp && !mUp && !rUp && pUp) return "TIDAK BOLEH";

    if (tUp && iUp && !mUp && !rUp && !pUp) return "BELI";


    if (iUp && mUp && rUp && pUp) {
      // Check orientation: horizontal hand = BERHENTI, vertical hand = Hai
      double dx = (points[9].x - points[0].x).abs();
      double dy = (points[9].y - points[0].y).abs();

      if (dy > dx * 1.2) {
        // Horizontal orientation: Only BERHENTI if hand is BELOW shoulder level
        // In this coordinate space, larger Y means ABOVE (towards head)
        if (shY != null && points[0].y > shY) {
          return ""; // Above shoulders and horizontal -> Ignore (Nothing)
        }
        return "BERHENTI";
      }
      return "Hai";
    }
    if (tUp && !iUp && !mUp && !rUp && !pUp) return "BAGUS";
    if (iUp && mUp && !rUp && !pUp) return "AMAN";
    if (!iUp && !mUp && !rUp && !pUp) return "Berhenti";




    return "";
  }

  static Offset? _getChestPoint(Map<PoseLandmarkType, PoseLandmark> pose, Size size) {
    final lSh = pose[PoseLandmarkType.leftShoulder];
    final rSh = pose[PoseLandmarkType.rightShoulder];
    if (lSh == null || rSh == null) return null;

    double lsX = 1.0 - (lSh.x / size.height);
    double rsX = 1.0 - (rSh.x / size.height);
    double lsY = lSh.y / size.width;
    double rsY = rSh.y / size.width;

    double midX = (lsX + rsX) / 2;
    double midY = (lsY + rsY) / 2;

    final lH = pose[PoseLandmarkType.leftHip];
    final rH = pose[PoseLandmarkType.rightHip];
    if (lH != null && rH != null && lH.likelihood > 0.4) {
      double lhX = 1.0 - (lH.x / size.height);
      double rhX = 1.0 - (rH.x / size.height);
      double lhY = lH.y / size.width;
      double rhY = rH.y / size.width;
      midX = midX + ((lhX + rhX) / 2 - midX) * 0.27;
      midY = midY + ((lhY + rhY) / 2 - midY) * 0.27;
    } else {
      double sw = _dist(lsX, lsY, rsX, rsY);
      midY += (sw * 0.35);
    }
    return Offset(midX, midY);
  }

  static double _getShoulderWidth(Map<PoseLandmarkType, PoseLandmark> pose, Size size) {
    final lSh = pose[PoseLandmarkType.leftShoulder];
    final rSh = pose[PoseLandmarkType.rightShoulder];
    if (lSh == null || rSh == null) return 0.2; // Default fallback

    double lsX = 1.0 - (lSh.x / size.height);
    double rsX = 1.0 - (rSh.x / size.height);
    double lsY = lSh.y / size.width;
    double rsY = rSh.y / size.width;
    return _dist(lsX, lsY, rsX, rsY);
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
