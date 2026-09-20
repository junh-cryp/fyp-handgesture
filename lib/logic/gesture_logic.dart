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
    
    // Calculate a dynamic scale based on hand size (wrist to middle knuckle)
    double handScale = dist(points[0], points[9]);
    if (handScale < 0.05) handScale = 0.2; // Fallback for edge cases

    // Dynamic buffer for "extended" fingers based on hand size
    bool isExt(int tip, int joint) => dist(points[tip], points[0]) > dist(points[joint], points[0]) + (handScale * 0.1);

    double h_dist = (points[9].dx - points[0].dx).abs(); // horizontal diff
    double v_dist = (points[9].dy - points[0].dy).abs(); // vertical diff

    bool vertical = v_dist > h_dist * 1.2;
    bool horizontal = h_dist > v_dist * 1.2;

    // Specific finger orientations - relaxed slightly to allow natural tilt
    double tx_h = (points[4].dx - points[2].dx).abs();
    double ty_v = (points[4].dy - points[2].dy).abs();
    bool thumbV = ty_v > tx_h * 1.0; 
    bool thumbH = tx_h > ty_v * 1.0;

    double ix_h = (points[8].dx - points[5].dx).abs();
    double iy_v = (points[8].dy - points[5].dy).abs();
    bool indexV = iy_v > ix_h * 1.0; 
    bool indexH = ix_h > iy_v * 1.0;

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
      isThumbUp: dist(points[4], points[5]) > (handScale * 0.4), // Dynamic thumb threshold
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
    List<GestureResult> singleCandidates = [];
    List<GestureResult> twoCandidates = [];

    // Mapping: Match HandState's rotation (Offset(y, 1.0 - x))
    Offset p2s(PoseLandmark p) => Offset(
      p.y / imageSize!.height,
      1.0 - (p.x / imageSize.width),
    );

    void addSingle(String word, List<bool> strict, [List<bool> scoring = const []]) {
      if (!strict.every((c) => c)) return;
      double score = calculateRuleScore([...strict, ...scoring]);
      if (score >= minimumMatchScore) {
        singleCandidates.add(GestureResult(word, score));
      }
    }

    void addTwo(String word, List<bool> strict, [List<bool> scoring = const []]) {
      if (!strict.every((c) => c)) return;
      double score = calculateRuleScore([...strict, ...scoring]);
      if (score >= minimumMatchScore) {
        twoCandidates.add(GestureResult(word, score));
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

        addSingle("Hai", [
          !state.isThumbUp, state.isIndexUp, state.isMiddleUp, state.isRingUp, state.isPinkyUp,
          state.indexVertical,
          aboveShoulder,
        ], [
          state.points[8].dy < state.points[5].dy, // Index tip pointing UP
        ]);
      }


      // 2. PEACE (Index + Middle Up, Above Shoulder)
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

        addSingle("PEACE", [
          state.isIndexUp, state.isMiddleUp,
          !state.isRingUp, !state.isPinkyUp,
          state.indexVertical,
        ], [
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
            if (state.points[0].dy < shV) aboveShoulder = true;
          }
        }

        addSingle("BAGUS", [
          state.isThumbUp,
          !state.isIndexUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
          state.thumbVertical,
          state.indexHorizontal,
        ], [
          state.points[4].dy < state.points[2].dy, // Thumb tip higher than thumb knuckle
          state.points[8].dx > state.points[5].dx, // Index pointing towards X=1 (Left)
          aboveShoulder
        ]);

        addSingle("MANA",[
          state.isIndexUp,
          !state.isThumbUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
          state.indexVertical,
          aboveShoulder
        ]);
      }

      // 4. MINUM (Thumb near mouth)
      if (posePoints != null && imageSize != null) {
        final lMouth = posePoints[PoseLandmarkType.leftMouth];
        final rMouth = posePoints[PoseLandmarkType.rightMouth];
        final nose = posePoints[PoseLandmarkType.nose];

        Offset? pMouth;
        if (lMouth != null && rMouth != null) {
          pMouth = Offset((p2s(lMouth).dx + p2s(rMouth).dx) / 2, (p2s(lMouth).dy + p2s(rMouth).dy) / 2);
        } else if (nose != null) {
          final pNose = p2s(nose);
          pMouth = Offset(pNose.dx, pNose.dy + 0.07);
        }

        if (pMouth != null) {
          double d = (state.points[4] - pMouth).distance;
          addSingle("MINUM", [
            state.isThumbUp,
            !state.isIndexUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
            state.thumbHorizontal,
          ], [
            state.points[4].dx > state.points[2].dx, // Thumb tip pointing towards X=1 (Left)
            d < 0.40, // Relaxed distance
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

        addSingle("Berhenti", [
          !state.isThumbUp, !state.isIndexUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
          state.isVertical,
        ], [
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

        final strictBeli = [
          state.isThumbUp, state.isIndexUp,
          !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
          state.thumbVertical,
          state.indexHorizontal,
        ];
        final scoreBeli = [
          state.points[4].dy < state.points[2].dy, // Thumb pointing UP
          belowShoulder
        ];
        addSingle("BELI", strictBeli, scoreBeli);
        addSingle("BELANJA", strictBeli, scoreBeli);
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

        addSingle("TIDAK BOLEH", [
          state.isPinkyUp, !state.isThumbUp, !state.isIndexUp, !state.isMiddleUp, !state.isRingUp,
          state.pinkyHorizontal,
        ], [
          belowShoulder
        ]);

        addSingle("SAMA-SAMA", [
          state.isPinkyUp, state.isThumbUp, !state.isIndexUp, !state.isMiddleUp, !state.isRingUp,
          state.pinkyHorizontal,state.thumbVertical,
        ], [
          belowShoulder
        ]);
      }

      //TERIMA KASIH
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
            addSingle("TERIMA KASIH", [
              state.isThumbUp, state.isIndexUp, state.isMiddleUp, state.isRingUp, state.isPinkyUp,
              state.indexVertical, state.pinkyVertical,
              dMouth < 0.45, // Strict position requirement: must be near mouth
              state.points[0].dy >shV
            ], [
              state.points[8].dy < state.points[5].dy, // Index tip pointing UP
              state.points[20].dy < state.points[17].dy, // Pinky tip pointing UP
              state.points[8].dy < shV // Index tip above shoulder
            ]);
          }

          //SALAH
          if (pMouth.dx != -1) {
            double dMouth = (state.points[20] - pMouth).distance;
            addSingle("SALAH", [
              state.isThumbUp, !state.isIndexUp, !state.isMiddleUp, !state.isRingUp, state.isPinkyUp,
              state.indexVertical, state.pinkyVertical,
              dMouth < 0.45, // Strict position requirement: must be near mouth
              state.points[0].dy >shV //below
            ], [
              state.points[20].dy < state.points[17].dy, // Pinky tip pointing UP
              state.points[20].dy < shV // Index tip above shoulder
            ]);
          }
        }
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
            addSingle("APA GUNANYA ?", [
              !state.isThumbUp, state.isIndexUp, state.isMiddleUp, state.isRingUp, state.isPinkyUp,
              state.indexVertical, state.pinkyVertical,
              dMouth < 0.45, // Strict position requirement: must be near mouth
              state.points[0].dy >= shV,
            ], [
              state.points[8].dy < state.points[5].dy, // Index tip pointing UP
              state.points[20].dy < state.points[17].dy, // Pinky tip pointing UP
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

          addSingle("OH! BEGITU RUPANYA", [
            state.isThumbUp, state.isIndexUp, state.isMiddleUp, state.isRingUp, state.isPinkyUp,
            state.thumbVertical,
            state.indexHorizontal,
            dChest < 0.45, // Relaxed distance
          ], [
            state.points[4].dy < state.points[2].dy, // Thumb pointing UP
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
            addSingle("DIAM", [
              state.isIndexUp,
              !state.isThumbUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
              state.indexVertical,
              dMouth < 0.40, // Strict position requirement: must be near mouth
            ], [
              pointingUp,
              state.points[8].dy < shV,
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
          addSingle("SAYA", [
            state.isIndexUp, !state.isThumbUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
            state.indexHorizontal,
            state.points[8].dx > state.points[5].dx, // Must point towards X=1 (Left)
            state.points[8].dy > shV, //must below shoulder
          ], [
            dChest < 0.45, // Relaxed distance

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

          addSingle("FIKIR", [
            state.isIndexUp,
            !state.isThumbUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
            state.indexHorizontal,
            state.points[8].dx > state.points[5].dx, // Must point towards X=1 (Left)
            state.points[8].dy < shV // Must be above shoulder level
          ], [
            dEye < 0.40, // Relaxed distance

          ]);
        }
      }

      // 21. ANDA
      if (posePoints != null && imageSize != null) {
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];
        if (lSh != null && rSh != null) {
          final shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
          addSingle("ANDA", [
            state.isIndexUp, !state.isThumbUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
            state.indexHorizontal,
            state.points[8].dx < state.points[5].dx,
            state.points[8].dy > shV //must below shoulder
          ], [

          ]);
        }
      }

      // AWAK
      if (posePoints != null && imageSize != null) {
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];
        if (lSh != null && rSh != null) {
          final shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
          addSingle("AWAK", [
            state.isIndexUp, !state.isThumbUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
            state.indexHorizontal,
            state.points[8].dx < state.points[5].dx,
            state.points[8].dy > shV //must below shoulder
          ], [

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
        addSingle("SANA", [
          state.isIndexUp, !state.isThumbUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
          (state.indexHorizontal),
          state.points[8].dx < state.points[5].dx,
          aboveShoulder
        ], [
          aboveShoulder
        ]);
      }

      // MAAF (Fist near chest, thumb horizontal)
      if (posePoints != null && imageSize != null) {
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];
        if (lSh != null && rSh != null) {
          final pLSh = p2s(lSh);
          final pRSh = p2s(rSh);
          final sMid = Offset((pLSh.dx + pRSh.dx) / 2, (pLSh.dy + pRSh.dy) / 2);
          final chest = Offset(sMid.dx, sMid.dy + 0.20);
          double dChest = (state.points[0] - chest).distance;

          addSingle("MAAF", [
            !state.isThumbUp, !state.isIndexUp, !state.isMiddleUp, !state.isRingUp, !state.isPinkyUp,
            state.indexHorizontal, state.thumbHorizontal,
            dChest < 0.45,
          ], [

          ]);
        }
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

          List<bool> strictKhabar = [];
          List<bool> scoreKhabar = [];
          for (var s in hStates) {
            // Strict Finger Status: Thumbs up only
            strictKhabar.add(s.isThumbUp && !s.isIndexUp && !s.isMiddleUp && !s.isRingUp && !s.isPinkyUp);
            // Strict Orientation: Thumb Vertical
            strictKhabar.add(s.thumbVertical);
            
            scoreKhabar.add(s.points[4].dy < s.points[2].dy);
            scoreKhabar.add(s.indexHorizontal);
            scoreKhabar.add(s.points[0].dy > shV - 0.05);
            scoreKhabar.add((s.points[0] - chest).distance < 0.45);
          }
          addTwo("Apa Khabar", strictKhabar, scoreKhabar);
        }
      }

      // 14. BOLEH (Two Fists at shoulders)
      if (posePoints != null && imageSize != null) {
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];
        if (lSh != null && rSh != null) {
          final pLSh = p2s(lSh);
          final pRSh = p2s(rSh);

          List<bool> strictBoleh = [];
          List<bool> scoreBoleh = [];
          for (var s in hStates) {
            // Strict Finger Status: All closed
            strictBoleh.add(!s.isThumbUp && !s.isIndexUp && !s.isMiddleUp && !s.isRingUp && !s.isPinkyUp);
            // Strict Orientation: Vertical
            strictBoleh.add(s.isVertical);
            scoreBoleh.add(s.moveDir == "UP");
          }
          // Position: Each hand at one shoulder
          bool h0L = (hStates[0].points[0] - pLSh).distance < 0.25;
          bool h0R = (hStates[0].points[0] - pRSh).distance < 0.25;
          bool h1L = (hStates[1].points[0] - pLSh).distance < 0.25;
          bool h1R = (hStates[1].points[0] - pRSh).distance < 0.25;

          scoreBoleh.add((h0L && h1R) || (h0R && h1L));
          addTwo("BOLEH", strictBoleh, scoreBoleh);
        }
      }

      // 15. TIDAK ADA (Two Open Palms, Below Shoulder)
          {
        List<bool> strictAda = [];
        List<bool> scoreAda = [];
        double shV = 0.5;
        if (posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
          }
        }

        for (var s in hStates) {
          // Strict Finger Status: All open
          strictAda.add(s.isThumbUp && s.isIndexUp && s.isMiddleUp && s.isRingUp && s.isPinkyUp);
          // Strict Orientation: Index vertical, Thumb horizontal
          strictAda.add(s.indexVertical && s.thumbHorizontal);
          
          scoreAda.add(s.points[8].dy < s.points[5].dy);
          scoreAda.add(s.points[0].dy > shV);
        }
        addTwo("TIDAK ADA", strictAda, scoreAda);
      }

      // 16. LESEN (Two Hands, Index+Thumb Up, Index Vertical, Thumb Horizontal, Near Chest)
      if (posePoints != null && imageSize != null) {
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];
        if (lSh != null && rSh != null) {
          final pLSh = p2s(lSh);
          final pRSh = p2s(rSh);
          final sMid = Offset((pLSh.dx + pRSh.dx) / 2, (pLSh.dy + pRSh.dy) / 2);
          final chest = Offset(sMid.dx, sMid.dy + 0.20);

          List<bool> strictLesen = [];
          List<bool> scoreLesen = [];
          for (var s in hStates) {
            strictLesen.add(s.isIndexUp && s.isThumbUp && !s.isMiddleUp && !s.isRingUp && !s.isPinkyUp);
            strictLesen.add(s.indexVertical && s.thumbHorizontal);
            scoreLesen.add(s.points[8].dy < s.points[5].dy); // Index tip pointing UP
            scoreLesen.add((s.points[0] - chest).distance < 0.40);
          }
          // Hands should be relatively close to each other, specifically thumbs touching
          double thumbDist = (hStates[0].points[4] - hStates[1].points[4]).distance;
          strictLesen.add(thumbDist < 0.15); // Strict "touching" distance

          addTwo("LESEN", strictLesen, scoreLesen);
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

        List<bool> strictBenang = [];
        List<bool> scoreBenang = [];
        for (var s in hStates) {
          strictBenang.add(s.isPinkyUp && !s.isThumbUp && !s.isIndexUp && !s.isMiddleUp && !s.isRingUp);
          strictBenang.add(s.pinkyHorizontal);
          scoreBenang.add(s.points[0].dy > shV);
        }
        double d = (hStates[0].points[20] - hStates[1].points[20]).distance;
        scoreBenang.add(d < 0.35);

        addTwo("BENANG", strictBenang, scoreBenang);
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

        List<bool> strictNama = [];
        List<bool> scoreNama = [];
        for (var s in hStates) {
          strictNama.add(s.isIndexUp && s.isMiddleUp && !s.isRingUp && !s.isPinkyUp);
          strictNama.add(s.indexHorizontal);
          scoreNama.add(s.points[0].dy > shV);
        }
        final center0 = Offset((hStates[0].points[8].dx + hStates[0].points[12].dx)/2, (hStates[0].points[8].dy + hStates[0].points[12].dy)/2);
        final center1 = Offset((hStates[1].points[8].dx + hStates[1].points[12].dx)/2, (hStates[1].points[8].dy + hStates[1].points[12].dy)/2);
        strictNama.add((center0 - center1).distance < 0.15); // Strict "stacked" distance
        addTwo("NAMA", strictNama, scoreNama);
      }

      // 23. TOLONG (Help)
      {
        final s0 = hStates[0];
        final s1 = hStates[1];
        
        // Identify top and bottom hand based on wrist Y
        final top = s0.points[0].dy < s1.points[0].dy ? s0 : s1;
        final bottom = s0.points[0].dy < s1.points[0].dy ? s1 : s0;

        // Top hand: BAGUS (thumb up)
        // Bottom hand: PALM (flat)
        int topUpCount = (top.isIndexUp?1:0) + (top.isMiddleUp?1:0) + (top.isRingUp?1:0) + (top.isPinkyUp?1:0);
        int bottomUpCount = (bottom.isIndexUp?1:0) + (bottom.isMiddleUp?1:0) + (bottom.isRingUp?1:0) + (bottom.isPinkyUp?1:0);

        addTwo("TOLONG", [
          top.points[0].dy < bottom.points[0].dy - 0.02, // Vertical separation
          top.isThumbUp,
          bottomUpCount >= 2, // Palm hand needs at least 2 fingers open
        ], [
          topUpCount <= 1,
          bottom.isHorizontal,
          bottom.thumbHorizontal,
          (top.points[0].dx - bottom.points[0].dx).abs() < 0.45, // Relaxed alignment
          top.thumbVertical,
        ]);
      }

      // 23.5 BERHENTI (Two Hands Palm version)
      {
        final s0 = hStates[0];
        final s1 = hStates[1];
        
        final top = s0.points[0].dy < s1.points[0].dy ? s0 : s1;
        final bottom = s0.points[0].dy < s1.points[0].dy ? s1 : s0;

        int topUpCount = (top.isIndexUp?1:0) + (top.isMiddleUp?1:0) + (top.isRingUp?1:0) + (top.isPinkyUp?1:0);
        int bottomUpCount = (bottom.isIndexUp?1:0) + (bottom.isMiddleUp?1:0) + (bottom.isRingUp?1:0) + (bottom.isPinkyUp?1:0);

        addTwo("BERHENTI ", [
          top.points[0].dy < bottom.points[0].dy - 0.02, // Vertical separation
          topUpCount >= 3, // Top hand flat palm
          bottomUpCount >= 3, // Bottom hand flat palm
        ], [
          top.isHorizontal,
          bottom.isHorizontal,
          bottom.indexHorizontal,
          (top.points[0].dx - bottom.points[0].dx).abs() < 0.45, // Relaxed alignment
        ]);
      }

      // 24. BETUL (Two Hands, Index Up only, Horizontal, Near Chest, Below Shoulder)
      if (posePoints != null && imageSize != null) {
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];
        if (lSh != null && rSh != null) {
          final pLSh = p2s(lSh);
          final pRSh = p2s(rSh);
          final sMid = Offset((pLSh.dx + pRSh.dx) / 2, (pLSh.dy + pRSh.dy) / 2);
          final chest = Offset(sMid.dx, sMid.dy + 0.20);
          final shV = (pLSh.dy + pRSh.dy) / 2;

          List<bool> strictBetul = [];
          List<bool> scoreBetul = [];
          for (var s in hStates) {
            strictBetul.add(s.isIndexUp && !s.isThumbUp && !s.isMiddleUp && !s.isRingUp && !s.isPinkyUp);
            strictBetul.add(s.indexHorizontal);
            scoreBetul.add(s.points[0].dy > shV); // Wrist below shoulder
            scoreBetul.add((s.points[0] - chest).distance < 0.45);
          }
          // Hands must be stacked (one above the other)
          double dyDiff = (hStates[0].points[0].dy - hStates[1].points[0].dy).abs();
          double dxDiff = (hStates[0].points[0].dx - hStates[1].points[0].dx).abs();
          strictBetul.add(dyDiff > 0.05); // Vertical separation
          scoreBetul.add(dxDiff < 0.20);  // Horizontal alignment
          
          // Both index fingers pointing in the same direction
          bool h0Right = hStates[0].points[8].dx > hStates[0].points[5].dx;
          bool h1Right = hStates[1].points[8].dx > hStates[1].points[5].dx;
          strictBetul.add(h0Right == h1Right);

          addTwo("BETUL", strictBetul, scoreBetul);
        }
      }
    }

    List<GestureResult> finalCandidates = [];
    if (hStates.length >= 2 && twoCandidates.isNotEmpty) {
      finalCandidates = twoCandidates;
    } else {
      finalCandidates = [...twoCandidates, ...singleCandidates];
    }

    // Sort by matchScore so the highest match is always first
    finalCandidates.sort((a, b) => b.matchScore.compareTo(a.matchScore));

    // De-duplicate results: if multiple hands perform the same sign, show it only once.
    final seen = <String>{};
    return finalCandidates.where((c) => seen.add(c.word)).toList();
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