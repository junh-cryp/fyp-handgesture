import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

class GestureResult {
  final String word;
  final double matchScore;
  GestureResult(this.word, this.matchScore);
  static GestureResult empty() => GestureResult("", 0.0);
}

class GestureDebugInfo {
  final String fingerStatus;
  final String orientation;
  final String tipPos;
  final String direction;
  final String extra;
  GestureDebugInfo({required this.fingerStatus, required this.orientation, required this.tipPos, required this.direction, this.extra = ""});
}

class HandState {
  final List<Offset> points;
  final bool isThumbUp, isIndexUp, isMiddleUp, isRingUp, isPinkyUp;
  final bool isVertical, isHorizontal;
  final String moveDir;
  final bool thumbVertical, thumbHorizontal;
  final bool indexVertical, indexHorizontal;
  final bool pinkyVertical, pinkyHorizontal;

  HandState({
    required this.points, required this.isThumbUp, required this.isIndexUp, required this.isMiddleUp,
    required this.isRingUp, required this.isPinkyUp, required this.isVertical, required this.isHorizontal,
    required this.moveDir, required this.thumbVertical, required this.thumbHorizontal,
    required this.indexVertical, required this.indexHorizontal,
    required this.pinkyVertical, required this.pinkyHorizontal,
  });

  factory HandState.fromHand(Hand hand) {
    final raw = hand.landmarks;

    // Mapping: Swapping X and Y to correct for 90-degree camera rotation.
    // User UP (Screen) -> Image RIGHT (p.x inc) -> We want dy dec. So dy = 1.0 - p.x
    // User RIGHT (Screen) -> Image UP (p.y dec) -> We want dx dec. So dx = p.y
    final points = raw.map((p) => Offset(p.y, 1.0 - p.x)).toList();

    double dist(Offset a, Offset b) => math.sqrt(math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2));
    bool isExt(int tip, int joint) => dist(points[tip], points[0]) > dist(points[joint], points[0]) + 0.02;

    double h_dist = (points[9].dx - points[0].dx).abs(); // horizontal diff
    double v_dist = (points[9].dy - points[0].dy).abs(); // vertical diff
    
    bool vertical = v_dist > h_dist * 1.3;
    bool horizontal = h_dist > v_dist * 1.3;

    // Specific finger orientations
    double tx_h = (points[4].dx - points[2].dx).abs();
    double ty_v = (points[4].dy - points[2].dy).abs();
    bool thumbV = ty_v > tx_h * 1.1; // Relaxed from 1.2
    bool thumbH = tx_h > ty_v * 1.1;

    double ix_h = (points[8].dx - points[5].dx).abs();
    double iy_v = (points[8].dy - points[5].dy).abs();
    bool indexV = iy_v > ix_h * 1.1; // Relaxed from 1.2
    bool indexH = ix_h > iy_v * 1.1;

    double px_h = (points[20].dx - points[17].dx).abs();
    double py_v = (points[20].dy - points[17].dy).abs();
    bool pinkyV = py_v > px_h * 1.1; // Relaxed from 1.2
    bool pinkyH = px_h > py_v * 1.1;

    // Detect direction based on knuckle (9) relative to wrist (0)
    // dy < : UP (closer to 0), dx < : RIGHT (closer to 0)
    String dir = "UNKNOWN";
    if (vertical) {
      dir = points[9].dy < points[0].dy ? "UP" : "DOWN";
    } else if (horizontal) {
      dir = points[9].dx < points[0].dx ? "RIGHT" : "LEFT";
    }

    return HandState(
      points: points,
      isThumbUp: dist(points[4], points[5]) > 0.06,
      isIndexUp: isExt(8, 6), isMiddleUp: isExt(12, 10), isRingUp: isExt(16, 14), isPinkyUp: isExt(20, 18),
      isVertical: vertical, isHorizontal: horizontal,
      moveDir: dir,
      thumbVertical: thumbV, thumbHorizontal: thumbH,
      indexVertical: indexV, indexHorizontal: indexH,
      pinkyVertical: pinkyV, pinkyHorizontal: pinkyH,
    );
  }
}

class GestureLogic {
  static const double minimumMatchScore = 0.70;

  static double calculateRuleScore(List<bool> conditions) {
    if (conditions.isEmpty) return 0.0;
    final passed = conditions.where((condition) => condition).length;
    return passed / conditions.length;
  }

  static List<GestureResult> analyzeGestures({required List<Hand> hands, Map<PoseLandmarkType, PoseLandmark>? posePoints, required Size? imageSize}) {
    if (hands.isEmpty) return [];
    final hStates = hands.map((h) => HandState.fromHand(h)).toList();
    List<GestureResult> candidates = [];

    // Mapping: Match HandState's rotation (Offset(y, 1.0 - x))
    Offset p2s(PoseLandmark p) => Offset(
          p.y / imageSize!.height,
          1.0 - (p.x / imageSize.width),
        );

    void addCandidate(String word, List<bool> conditions) {
      double score = calculateRuleScore(conditions);
      if (score >= minimumMatchScore) {
        candidates.add(GestureResult(word, score));
      }
    }

    // Single Hand Signs
    for (var state in hStates) {
      // 1. Open Palm Gesture (Hai)
      {
        bool aboveShoulder = false;
        if (posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            final shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
            if (state.points[0].dy < shV) aboveShoulder = true;
          }
        }

        addCandidate("Hai", [
          !state.isThumbUp, state.isIndexUp, state.isMiddleUp, state.isRingUp, state.isPinkyUp,
          state.indexVertical, 
          state.points[8].dy < state.points[5].dy, // Index tip pointing UP
          aboveShoulder
        ]);
      }

      // 2. AMAN (Index + Middle Up, Above Shoulder)
      {
        bool aboveShoulder = false;
        if (posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            final shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
            if (state.points[0].dy < shV) aboveShoulder = true;
          }
        }

        addCandidate("AMAN", [
          state.isIndexUp, state.isMiddleUp, 
          !state.isThumbUp, !state.isRingUp, !state.isPinkyUp,
          state.indexVertical, 
          state.points[8].dy < state.points[5].dy, // Index tip higher than knuckle
          aboveShoulder
        ]);
      }

      // 3. BAGUS (Thumb Vertical Up, Above Shoulder)
      {
        bool aboveShoulder = false;
        if (posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            final shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
            // Using wrist (points[0]) to determine if the hand is above shoulder level
            if (state.points[0].dy < shV) aboveShoulder = true;
          }
        }

        addCandidate("BAGUS", [
          state.isThumbUp, 
          !state.isIndexUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
          state.thumbVertical, 
          state.points[4].dy < state.points[2].dy, // Thumb tip higher than thumb knuckle
          state.indexHorizontal, 
          state.points[8].dx > state.points[5].dx, // Index pointing towards X=1 (Left)
          aboveShoulder
        ]);
      }

      // 4. MINUM (Thumb near mouth)
      if (posePoints != null && imageSize != null) {
        final lMouth = posePoints[PoseLandmarkType.leftMouth];
        final rMouth = posePoints[PoseLandmarkType.rightMouth];
        final nose = posePoints[PoseLandmarkType.nose];

        if (lMouth != null && rMouth != null) {
          final pMouth = Offset((p2s(lMouth).dx + p2s(rMouth).dx) / 2, (p2s(lMouth).dy + p2s(rMouth).dy) / 2);
          double d = (state.points[4] - pMouth).distance;

          addCandidate("MINUM", [
            state.isThumbUp, 
            !state.isIndexUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
            state.thumbHorizontal,
            state.points[4].dx > state.points[2].dx, // Thumb tip pointing towards X=1 (Left)
            d < 0.12 // Strictly close to mouth
          ]);
        } else if (nose != null) {
          final pNose = p2s(nose);
          final pMouth = Offset(pNose.dx, pNose.dy + 0.07);
          double d = (state.points[4] - pMouth).distance;
          
          addCandidate("MINUM", [
            state.isThumbUp, 
            !state.isIndexUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
            state.thumbHorizontal,
            state.points[4].dx > state.points[2].dx,
            d < 0.12
          ]);
        }
      }

      // 7. Berhenti (Closed Fist, Above Shoulder)
      {
        bool aboveShoulder = false;
        if (posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            final shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
            if (state.points[0].dy < shV) aboveShoulder = true;
          }
        }

        addCandidate("Berhenti", [
          !state.isThumbUp, !state.isIndexUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
          state.isVertical,
          state.moveDir == "UP", // Knuckles are above the wrist
          aboveShoulder
        ]);
      }

      // 8. BELI / BELANJA (Thumb Vertical + Index Horizontal, Below Shoulder)
      {
        bool belowShoulder = false;
        if (posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            final shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
            if (state.points[0].dy > shV) belowShoulder = true;
          }
        }

        final beliCond = [
          state.isThumbUp, state.isIndexUp, 
          !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
          state.thumbVertical, 
          state.points[4].dy < state.points[2].dy, // Thumb pointing UP
          state.indexHorizontal,
          belowShoulder
        ];
        addCandidate("BELI", beliCond);
        addCandidate("BELANJA", beliCond);
      }

      // 12. TIDAK BOLEH (Pinky only, Horizontal, Below Shoulder)
      {
        bool belowShoulder = false;
        if (posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            final shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
            if (state.points[0].dy > shV) belowShoulder = true;
          }
        }

        addCandidate("TIDAK BOLEH", [
          state.isPinkyUp, !state.isThumbUp, !state.isIndexUp, !state.isMiddleUp, !state.isRingUp,
          state.pinkyHorizontal,
          belowShoulder
        ]);
      }

      // 19. APA GUNANYA (4 fingers near mouth, thumb folded)
      if (posePoints != null && imageSize != null) {
        final lMouth = posePoints[PoseLandmarkType.leftMouth];
        final rMouth = posePoints[PoseLandmarkType.rightMouth];
        final nose = posePoints[PoseLandmarkType.nose];
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];

        if (lSh != null && rSh != null) {
          final shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
          Offset pMouth;
          if (lMouth != null && rMouth != null) {
            pMouth = Offset((p2s(lMouth).dx + p2s(rMouth).dx) / 2, (p2s(lMouth).dy + p2s(rMouth).dy) / 2);
          } else if (nose != null) {
            final pNose = p2s(nose);
            pMouth = Offset(pNose.dx, pNose.dy + 0.07);
          } else {
            pMouth = const Offset(-1, -1);
          }

          if (pMouth.dx != -1) {
            double dMouth = (state.points[8] - pMouth).distance;
            addCandidate("APA GUNANYA ?", [
              !state.isThumbUp, state.isIndexUp, state.isMiddleUp, state.isRingUp, state.isPinkyUp,
              state.indexVertical, state.pinkyVertical,
              state.points[8].dy < state.points[5].dy, // Index tip pointing UP
              state.points[20].dy < state.points[17].dy, // Pinky tip pointing UP
              dMouth < 0.20, // Close to mouth
              state.points[8].dy < shV // Index tip above shoulder
            ]);
          }
        }
      }

      // 20. OH! BEGITU RUPANYA (Open Palm near chest, Index Horizontal)
      if (posePoints != null && imageSize != null) {
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];
        if (lSh != null && rSh != null) {
          final pLSh = p2s(lSh);
          final pRSh = p2s(rSh);
          final sMid = Offset((pLSh.dx + pRSh.dx) / 2, (pLSh.dy + pRSh.dy) / 2);
          final chest = Offset(sMid.dx, sMid.dy + 0.20);
          double dChest = (state.points[9] - chest).distance;

          addCandidate("OH! BEGITU RUPANYA", [
            state.isThumbUp, state.isIndexUp, state.isMiddleUp, state.isRingUp, state.isPinkyUp,
            state.thumbVertical,
            state.points[4].dy < state.points[2].dy, // Thumb pointing UP
            state.indexHorizontal, 
            dChest < 0.35
          ]);
        }
      }

      // 9. DIAM (Index Up near Mouth)
      if (posePoints != null && imageSize != null) {
        final lMouth = posePoints[PoseLandmarkType.leftMouth];
        final rMouth = posePoints[PoseLandmarkType.rightMouth];
        final nose = posePoints[PoseLandmarkType.nose];
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];
        if (lSh != null && rSh != null) {
          final shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
          Offset pMouth;
          if (lMouth != null && rMouth != null) {
            pMouth = Offset((p2s(lMouth).dx + p2s(rMouth).dx) / 2, (p2s(lMouth).dy + p2s(rMouth).dy) / 2);
          } else if (nose != null) {
            final pNose = p2s(nose);
            pMouth = Offset(pNose.dx, pNose.dy + 0.07);
          } else {
            pMouth = const Offset(-1, -1);
          }

          if (pMouth.dx != -1) {
            double dMouth = (state.points[8] - pMouth).distance;
            bool pointingUp = state.points[8].dy < state.points[5].dy;
            addCandidate("DIAM", [
              state.isIndexUp, 
              !state.isThumbUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
              state.indexVertical, 
              pointingUp,
              dMouth < 0.18, 
              state.points[8].dy < shV
            ]);
          }
        }
      }

      // 10. SAYA
      if (posePoints != null && imageSize != null) {
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];
        if (lSh != null && rSh != null) {
          final pLSh = p2s(lSh);
          final pRSh = p2s(rSh);
          final shV = (pLSh.dy + pRSh.dy) / 2;
          final chest = Offset((pLSh.dx + pRSh.dx) / 2, shV + 0.15);
          double dChest = (state.points[8] - chest).distance;
          addCandidate("SAYA", [
            state.isIndexUp, !state.isThumbUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
            state.indexHorizontal, 
            state.points[8].dx > state.points[5].dx, // Pointing towards X=1 (Left)
            dChest < 0.30, 
            state.points[8].dy > shV // Below shoulder
          ]);
        }
      }

      // 11. FIKIR (Index near Eye)
      if (posePoints != null && imageSize != null) {
        final lEye = posePoints[PoseLandmarkType.leftEye];
        final rEye = posePoints[PoseLandmarkType.rightEye];
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];
        if (lEye != null && rEye != null && lSh != null && rSh != null) {
          final pLEye = p2s(lEye);
          final pREye = p2s(rEye);
          final shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
          double dEye = math.min((state.points[8] - pLEye).distance, (state.points[8] - pREye).distance);
          
          addCandidate("FIKIR", [
            state.isIndexUp, 
            !state.isThumbUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
            state.indexHorizontal, 
            state.points[8].dx > state.points[5].dx, // Pointing towards X=1 (Left)
            dEye < 0.12, 
            state.points[8].dy < shV // Must be above shoulder level
          ]);
        }
      }

      // 21. ANDA
      if (posePoints != null && imageSize != null) {
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];
        if (lSh != null && rSh != null) {
          final shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
          addCandidate("ANDA", [
            state.isIndexUp, !state.isThumbUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
            state.indexHorizontal,
            state.points[8].dy > shV
          ]);
        }
      }

      // 22. SANA (Index Up, Above Shoulder)
      {
        bool aboveShoulder = false;
        if (posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            final shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
            if (state.points[0].dy < shV) aboveShoulder = true;
          }
        }
        addCandidate("SANA", [
          state.isIndexUp, !state.isThumbUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
          (state.indexVertical || state.indexHorizontal),
          aboveShoulder
        ]);
      }
    }

    // Two Hand Signs
    if (hStates.length == 2) {
      // 13. Apa Khabar (Two Thumbs Up near chest, Below Shoulder)
      if (posePoints != null && imageSize != null) {
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];
        if (lSh != null && rSh != null) {
          final pLSh = p2s(lSh);
          final pRSh = p2s(rSh);
          final sMid = Offset((pLSh.dx + pRSh.dx) / 2, (pLSh.dy + pRSh.dy) / 2);
          final chest = Offset(sMid.dx, sMid.dy + 0.20);
          double shV = (pLSh.dy + pRSh.dy) / 2;

          List<bool> khabarCond = [];
          for (var s in hStates) {
            // Finger Status: Thumbs up only
            khabarCond.add(s.isThumbUp && !s.isIndexUp && !s.isMiddleUp && !s.isRingUp && !s.isPinkyUp);
            // Orientation: Thumb Vertical (UP), Index Horizontal
            khabarCond.add(s.thumbVertical && s.points[4].dy < s.points[2].dy);
            khabarCond.add(s.indexHorizontal);
            // Position: Around or Below shoulder
            khabarCond.add(s.points[0].dy > shV - 0.05);
            khabarCond.add((s.points[0] - chest).distance < 0.45);
          }
          addCandidate("Apa Khabar", khabarCond);
        }
      }

      // 14. BOLEH (Two Fists at shoulders)
      if (posePoints != null && imageSize != null) {
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];
        if (lSh != null && rSh != null) {
          final pLSh = p2s(lSh);
          final pRSh = p2s(rSh);
          
          List<bool> bolehCond = [];
          for (var s in hStates) {
            // Finger Status: All closed
            bolehCond.add(!s.isThumbUp && !s.isIndexUp && !s.isMiddleUp && !s.isRingUp && !s.isPinkyUp);
            // Orientation: Vertical pointing UP
            bolehCond.add(s.isVertical && s.moveDir == "UP");
          }
          // Position: Each hand at one shoulder
          bool h0L = (hStates[0].points[0] - pLSh).distance < 0.25;
          bool h0R = (hStates[0].points[0] - pRSh).distance < 0.25;
          bool h1L = (hStates[1].points[0] - pLSh).distance < 0.25;
          bool h1R = (hStates[1].points[0] - pRSh).distance < 0.25;
          
          bolehCond.add((h0L && h1R) || (h0R && h1L));
          addCandidate("BOLEH", bolehCond);
        }
      }

      // 15. TIDAK ADA (Two Open Palms, Below Shoulder)
      {
        List<bool> adaCond = [];
        double shV = 0.5; // Default if pose not found
        if (posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
          }
        }

        for (var s in hStates) {
          // Finger Status: All open
          adaCond.add(s.isThumbUp && s.isIndexUp && s.isMiddleUp && s.isRingUp && s.isPinkyUp);
          // Orientation: Index vertical pointing UP, Thumb horizontal
          adaCond.add(s.indexVertical && s.points[8].dy < s.points[5].dy);
          adaCond.add(s.thumbHorizontal);
          // Position: Below shoulder level
          adaCond.add(s.points[0].dy > shV);
        }
        addCandidate("TIDAK ADA", adaCond);
      }

      // 16. IMEJ (One Hai + One Pinky Only)
      {
        double shV = 0.5;
        if (posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
          }
        }

        HandState h0 = hStates[0];
        HandState h1 = hStates[1];

        List<bool> getConds(HandState hai, HandState pinky) {
          return [
            !hai.isThumbUp, hai.isIndexUp, hai.isMiddleUp, hai.isRingUp, hai.isPinkyUp,
            hai.indexVertical, hai.points[8].dy < hai.points[5].dy, hai.points[0].dy < shV,
            pinky.isPinkyUp, !pinky.isThumbUp, !pinky.isIndexUp, !pinky.isMiddleUp, !pinky.isRingUp,
            pinky.pinkyHorizontal, pinky.points[0].dy > shV
          ];
        }

        List<bool> conds0 = getConds(h0, h1);
        List<bool> conds1 = getConds(h1, h0);
        
        double score0 = calculateRuleScore(conds0);
        double score1 = calculateRuleScore(conds1);
        
        if (score0 >= score1 && score0 >= minimumMatchScore) {
          candidates.add(GestureResult("IMEJ", score0));
        } else if (score1 > score0 && score1 >= minimumMatchScore) {
          candidates.add(GestureResult("IMEJ", score1));
        }
      }

      // 17. BENANG (Two Hands, Pinky Only, Horizontal, Close Together, Below Shoulder)
      {
        double shV = 0.5;
        if (posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
          }
        }

        List<bool> benangCond = [];
        for (var s in hStates) {
          benangCond.add(s.isPinkyUp && !s.isThumbUp && !s.isIndexUp && !s.isMiddleUp && !s.isRingUp);
          benangCond.add(s.pinkyHorizontal);
          benangCond.add(s.points[0].dy > shV);
        }
        // Distance between pinky tips
        double d = (hStates[0].points[20] - hStates[1].points[20]).distance;
        benangCond.add(d < 0.35); 
        
        addCandidate("BENANG", benangCond);
      }

      // 18. NAMA (Two Hands, Index+Middle Up, Horizontal, Close Together, Below Shoulder)
      {
        double shV = 0.5;
        if (posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
          }
        }

        List<bool> namaCond = [];
        for (var s in hStates) {
          namaCond.add(s.isIndexUp && s.isMiddleUp && !s.isRingUp && !s.isPinkyUp);
          namaCond.add(s.indexHorizontal);
          namaCond.add(s.points[0].dy > shV);
        }
        final center0 = Offset((hStates[0].points[8].dx + hStates[0].points[12].dx)/2, (hStates[0].points[8].dy + hStates[0].points[12].dy)/2);
        final center1 = Offset((hStates[1].points[8].dx + hStates[1].points[12].dx)/2, (hStates[1].points[8].dy + hStates[1].points[12].dy)/2);
        namaCond.add((center0 - center1).distance < 0.40);
        addCandidate("NAMA", namaCond);
      }
    }

    // Sort by matchScore so the highest match is always first
    candidates.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    
    // De-duplicate results: if multiple hands perform the same sign, show it only once.
    final seen = <String>{};
    return candidates.where((c) => seen.add(c.word)).toList();
  }

  static List<GestureDebugInfo> getDebugInfo(List<Hand> hands, Map<PoseLandmarkType, PoseLandmark>? pose, Size? size) {
    return hands.map((hand) {
      final state = HandState.fromHand(hand);
      
      String extra = "";
      if (pose != null && size != null) {
        Offset p2s(PoseLandmark p) => Offset(
              p.y / size.height,
              1.0 - (p.x / size.width),
            );
        
        final lEye = pose[PoseLandmarkType.leftEye];
        final rEye = pose[PoseLandmarkType.rightEye];
        final lm = pose[PoseLandmarkType.leftMouth];
        final rm = pose[PoseLandmarkType.rightMouth];
        final ns = pose[PoseLandmarkType.nose];
        
        if (lm != null && rm != null) {
           final m = Offset((p2s(lm).dx + p2s(rm).dx)/2, (p2s(lm).dy + p2s(rm).dy)/2);
           double d = (state.points[8] - m).distance;
           extra = "MDist:${d.toStringAsFixed(2)}";
        } else if (ns != null) {
           final pNose = p2s(ns);
           final m = Offset(pNose.dx, pNose.dy + 0.07);
           double d = (state.points[8] - m).distance;
           extra = "NDist:${d.toStringAsFixed(2)}";
        } else if (lEye != null && rEye != null) {
           final pLEye = p2s(lEye);
           final pREye = p2s(rEye);
           final eyeMid = Offset((pLEye.dx + pREye.dx) / 2, (pLEye.dy + pREye.dy) / 2);
           double d = (state.points[4] - eyeMid).distance;
           extra = "EDist:${d.toStringAsFixed(2)}";
        }
      }

      String pDir = state.pinkyVertical ? (state.points[20].dy < state.points[17].dy ? "P-UP" : "P-DN") : (state.pinkyHorizontal ? "P-HZ" : "P-SL");
      double pExt = (state.points[20] - state.points[17]).distance;

      return GestureDebugInfo(
        fingerStatus: "T:${state.isThumbUp?1:0} I:${state.isIndexUp?1:0} M:${state.isMiddleUp?1:0} R:${state.isRingUp?1:0} P:${state.isPinkyUp?1:0}",
        orientation: state.isVertical ? "Vertical" : (state.isHorizontal ? "Horizontal" : "Slanted"),
        tipPos: "X:${state.points[8].dx.toStringAsFixed(2)} Y:${state.points[8].dy.toStringAsFixed(2)}",
        direction: "${state.moveDir} $pDir E:${pExt.toStringAsFixed(2)}",
        extra: extra,
      );
    }).toList();
  }
}
