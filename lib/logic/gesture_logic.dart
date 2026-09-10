import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

class GestureResult {
  final String word;
  final double confidence;
  GestureResult(this.word, this.confidence);
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
  static List<GestureResult> analyzeGestures({required List<Hand> hands, Map<PoseLandmarkType, PoseLandmark>? posePoints, required Size? imageSize}) {
    if (hands.isEmpty) return [];
    final hStates = hands.map((h) => HandState.fromHand(h)).toList();
    List<GestureResult> candidates = [];

    // Mapping: ML Kit landmarks are already rotated/oriented by the detector.
    // Normalized X (horizontal) = p.x / image_short_side
    // Normalized Y (vertical) = p.y / image_long_side
    Offset p2s(PoseLandmark p) => Offset(
          p.x / math.min(imageSize!.width, imageSize.height),
          p.y / math.max(imageSize.width, imageSize.height),
        );

    // Single Hand Signs
    for (var state in hStates) {
      // 1. Open Palm Gesture (Hai)
      if (state.isIndexUp && state.isMiddleUp && state.isRingUp && state.isPinkyUp) {
        bool isNearMouth = false;
        if (posePoints != null && imageSize != null) {
          final lMouth = posePoints[PoseLandmarkType.leftMouth];
          final rMouth = posePoints[PoseLandmarkType.rightMouth];
          final nose = posePoints[PoseLandmarkType.nose];
          
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
            if (dMouth < 0.25) isNearMouth = true;
          }
        }

        if (state.isVertical && state.moveDir == "UP" && !isNearMouth) {
          candidates.add(GestureResult("Hai", 0.95));
        }
      }
      
      // 2. AMAN (Index + Middle Up)
      if (state.isIndexUp && state.isMiddleUp && !state.isRingUp && !state.isPinkyUp) {
        if (state.isVertical && state.moveDir == "UP") {
          candidates.add(GestureResult("AMAN", 0.95));
        }
      }

      // 3. BAGUS (Thumb Vertical Up)
      if (state.isThumbUp && !state.isIndexUp && !state.isMiddleUp && !state.isRingUp && !state.isPinkyUp) {
        if (state.points[4].dy < state.points[2].dy && state.thumbVertical) {
          candidates.add(GestureResult("BAGUS", 0.98));
        }
      }

      // 4. MINUM (Thumb near mouth)
      if (state.isThumbUp && !state.isIndexUp && !state.isMiddleUp && !state.isRingUp && !state.isPinkyUp && posePoints != null && imageSize != null) {
        final lMouth = posePoints[PoseLandmarkType.leftMouth];
        final rMouth = posePoints[PoseLandmarkType.rightMouth];
        final lSh = posePoints[PoseLandmarkType.leftShoulder];
        final rSh = posePoints[PoseLandmarkType.rightShoulder];

        if (lMouth != null && rMouth != null && lSh != null && rSh != null) {
          final pMouth = Offset((p2s(lMouth).dx + p2s(rMouth).dx)/2, (p2s(lMouth).dy + p2s(rMouth).dy)/2);
          final shV = (p2s(lSh).dy + p2s(rSh).dy) / 2;
          double d = (state.points[4] - pMouth).distance;
          // Must be near mouth AND strictly above shoulder level to avoid chest false positives
          if (d < 0.18 && state.points[4].dy < shV) {
            candidates.add(GestureResult("MINUM", 0.96));
          }
        }
      }

      // 7. Berhenti (Closed Fist)
      if (!state.isThumbUp && !state.isIndexUp && !state.isMiddleUp && !state.isRingUp && !state.isPinkyUp) {
        candidates.add(GestureResult("Berhenti", 0.95));
      }

      // 8. BELI / BELANJA (Strict Thumb Vertical + Index Horizontal)
      if (state.isThumbUp && state.isIndexUp && !state.isMiddleUp && !state.isRingUp && !state.isPinkyUp) {
        if (state.thumbVertical && state.indexHorizontal) {
          candidates.add(GestureResult("BELI", 0.95));
          candidates.add(GestureResult("BELANJA", 0.95));
        }
      }

      // 12. TIDAK BOLEH (Pinky only)
      if (state.isPinkyUp && !state.isThumbUp && !state.isIndexUp && !state.isMiddleUp && !state.isRingUp) {
        double pExt = (state.points[20] - state.points[17]).distance;
        bool pointingDown = state.points[20].dy > state.points[17].dy;
        // Horizontal, Down, or pointing towards camera (short 2D projection)
        if (state.pinkyHorizontal || pointingDown || pExt < 0.07) {
          candidates.add(GestureResult("TIDAK BOLEH", 0.96));
        }
      }

      // 19. APA GUNANYA (4 fingers near mouth, thumb folded)
      if (state.isIndexUp && state.isMiddleUp && state.isRingUp && state.isPinkyUp && !state.isThumbUp) {
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
              if (dMouth < 0.25 && state.isVertical && pointingUp && state.points[8].dy < shV) {
                candidates.add(GestureResult("APA GUNANYA ?", 0.98));
              }
            }
          }
        }
      }

      // 20. OH! BEGITU RUPANYA (Open Palm near chest, Index Horizontal)
      if (state.isThumbUp && state.isIndexUp && state.isMiddleUp && state.isRingUp && state.isPinkyUp) {
        if (state.indexHorizontal && posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            final pLSh = p2s(lSh);
            final pRSh = p2s(rSh);
            final sMid = Offset((pLSh.dx + pRSh.dx) / 2, (pLSh.dy + pRSh.dy) / 2);
            final chest = Offset(sMid.dx, sMid.dy + 0.20);
            double dChest = (state.points[9] - chest).distance;
            if (dChest < 0.35) {
              candidates.add(GestureResult("OH! BEGITU RUPANYA", 0.96));
            }
          }
        }
      }

      // Index Finger Only Gestures (SANA, FIKIR, SAYA, DIAM)
      // Note: We allow minor thumb extension for robustness when near face/body landmarks
      if (state.isIndexUp && !state.isMiddleUp && !state.isRingUp && !state.isPinkyUp) {
        double sanaConf = 0.90;
        
        if (posePoints != null && imageSize != null) {
          final lMouth = posePoints[PoseLandmarkType.leftMouth];
          final rMouth = posePoints[PoseLandmarkType.rightMouth];
          final nose = posePoints[PoseLandmarkType.nose];
          final lEye = posePoints[PoseLandmarkType.leftEye];
          final rEye = posePoints[PoseLandmarkType.rightEye];
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];

          // We need shoulders and eyes for a reliable relative coordinate frame
          if (lEye != null && rEye != null && lSh != null && rSh != null) {
            final pLEye = p2s(lEye);
            final pREye = p2s(rEye);
            final pLSh = p2s(lSh);
            final pRSh = p2s(rSh);
            final sMid = Offset((pLSh.dx + pRSh.dx) / 2, (pLSh.dy + pRSh.dy) / 2);
            final shV = sMid.dy;

            // Determine mouth center, fallback to nose if mouth landmarks are obscured by hand
            Offset pMouth;
            if (lMouth != null && rMouth != null) {
              pMouth = Offset((p2s(lMouth).dx + p2s(rMouth).dx)/2, (p2s(lMouth).dy + p2s(rMouth).dy)/2);
            } else if (nose != null) {
              final pNose = p2s(nose);
              pMouth = Offset(pNose.dx, pNose.dy + 0.07); // Estimate mouth position below nose
            } else {
              pMouth = Offset((pLEye.dx + pREye.dx)/2, (pLEye.dy + pREye.dy)/2 + 0.12);
            }

            // 9. DIAM (Index near mouth + Vertical)
            double dMouth = (state.points[8] - pMouth).distance;
            bool pointingUp = state.points[8].dy < state.points[5].dy;
            // DIAM must be near mouth, pointing up, and strictly ABOVE shoulders to avoid chest false positive
            if (state.indexVertical && dMouth < 0.25 && pointingUp && state.points[8].dy < shV) {
              candidates.add(GestureResult("DIAM", 0.98));
              sanaConf = 0.1;
            }

            // 11. FIKIR (Index Horizontal near eye + Above Shoulder)
            if (sanaConf > 0.2 && state.indexHorizontal) {
              double dEye = math.min((state.points[8] - pLEye).distance, (state.points[8] - pREye).distance);
              // Must be closer to eyes than mouth to distinguish from mouth-level signs
              if (dEye < 0.20 && state.points[8].dy < shV && dEye < dMouth) {
                candidates.add(GestureResult("FIKIR", 0.97));
                sanaConf = 0.1;
              }
            }

            // 10. SAYA (Index Horizontal near chest + Below Shoulder)
            if (sanaConf > 0.2 && state.indexHorizontal) {
              final chest = Offset(sMid.dx, sMid.dy + 0.15);
              double dChest = (state.points[8] - chest).distance;
              if (dChest < 0.30 && state.points[8].dy > shV) {
                candidates.add(GestureResult("SAYA", 0.96));
                sanaConf = 0.1;
              }
            }

            // 21. ANDA (Index pointing below shoulder)
            if (sanaConf > 0.2 && state.points[8].dy > shV) {
              candidates.add(GestureResult("ANDA", 0.95));
              sanaConf = 0.1;
            }
          }
        }
        
        // Final SANA (if not triggered as something else and thumb is tucked)
        if (!state.isThumbUp) {
          candidates.add(GestureResult("SANA", sanaConf));
        }
      }
    }

    // 13. Apa Khabar (Two Thumbs Up near chest)
    if (hStates.length == 2) {
      bool allBagus = hStates.every((s) => s.isThumbUp && !s.isIndexUp && !s.isMiddleUp && !s.isRingUp && !s.isPinkyUp && s.points[4].dy < s.points[2].dy);
      
      if (allBagus) {
        if (posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            final pLSh = p2s(lSh);
            final pRSh = p2s(rSh);
            final sMid = Offset((pLSh.dx + pRSh.dx) / 2, (pLSh.dy + pRSh.dy) / 2);
            final chest = Offset(sMid.dx, sMid.dy + 0.20);
            double shV = (pLSh.dy + pRSh.dy) / 2;

            bool bothNear = true;
            for (var state in hStates) {
              // Wrist near chest and below shoulder level
              double d = (state.points[0] - chest).distance;
              if (d > 0.45 || state.points[0].dy < shV) bothNear = false;
            }
            if (bothNear) candidates.add(GestureResult("Apa Khabar", 0.99));
          }
        } else {
          candidates.add(GestureResult("Apa Khabar", 0.99));
        }
      }

      // 14. BOLEH (Two Fists near shoulders)
      bool allFists = hStates.every((s) => !s.isThumbUp && !s.isIndexUp && !s.isMiddleUp && !s.isRingUp && !s.isPinkyUp);
      if (allFists) {
        if (posePoints != null && imageSize != null) {
          final lSh = posePoints[PoseLandmarkType.leftShoulder];
          final rSh = posePoints[PoseLandmarkType.rightShoulder];
          if (lSh != null && rSh != null) {
            final pLSh = p2s(lSh);
            final pRSh = p2s(rSh);

            bool h1L = (hStates[0].points[0] - pLSh).distance < 0.35;
            bool h1R = (hStates[0].points[0] - pRSh).distance < 0.35;
            bool h2L = (hStates[1].points[0] - pLSh).distance < 0.35;
            bool h2R = (hStates[1].points[0] - pRSh).distance < 0.35;

            if ((h1L && h2R) || (h1R && h2L)) {
              candidates.add(GestureResult("BOLEH", 0.99));
            }
          }
        } else {
          candidates.add(GestureResult("BOLEH", 0.99));
        }
      }

      // 15. TIDAK ADA (Two Open Palms)
      bool allHai = true;
      for (var state in hStates) {
        bool isHai = state.isIndexUp && state.isMiddleUp && state.isRingUp && state.isPinkyUp && 
                     state.isVertical && state.moveDir == "UP";
        if (!isHai) allHai = false;
      }
      if (allHai) {
        candidates.add(GestureResult("TIDAK ADA", 0.99));
      }

      // 16. IMEJ (One Hai + One Pinky Only)
      HandState? hHai;
      HandState? hPinky;
      for (var s in hStates) {
        bool isH = s.isIndexUp && s.isMiddleUp && s.isRingUp && s.isPinkyUp;
        // Pinky up, others down. Ignore thumb for robustness.
        bool isP = s.isPinkyUp && !s.isIndexUp && !s.isMiddleUp && !s.isRingUp;
        bool pointingUp = s.points[20].dy < s.points[17].dy;

        if (isH) hHai = s;
        if (isP && pointingUp) hPinky = s;
      }
      if (hHai != null && hPinky != null) {
        // Distance between pinky tip and the other hand's palm center
        double d = (hPinky.points[20] - hHai.points[9]).distance;
        if (d < 0.60) {
          candidates.add(GestureResult("IMEJ", 0.99));
        }
      }

      // 17. BENANG (Two Hands, Pinky Only, Horizontal)
      bool allBenang = true;
      for (var s in hStates) {
        bool isP = s.isPinkyUp && !s.isIndexUp && !s.isMiddleUp && !s.isRingUp;
        if (!(isP && s.pinkyHorizontal)) allBenang = false;
      }
      if (allBenang) {
        candidates.add(GestureResult("BENANG", 0.99));
      }

      // 18. NAMA (Two Hands, Index+Middle Up, Horizontal, Close Together)
      bool allNama = true;
      for (var s in hStates) {
        bool isIM = s.isIndexUp && s.isMiddleUp && !s.isRingUp && !s.isPinkyUp;
        if (!(isIM && s.indexHorizontal)) allNama = false;
      }
      if (allNama) {
        final center0 = Offset((hStates[0].points[8].dx + hStates[0].points[12].dx)/2, (hStates[0].points[8].dy + hStates[0].points[12].dy)/2);
        final center1 = Offset((hStates[1].points[8].dx + hStates[1].points[12].dx)/2, (hStates[1].points[12].dy + hStates[1].points[12].dy)/2);
        double d = (center0 - center1).distance;
        if (d < 0.40) {
          candidates.add(GestureResult("NAMA", 0.99));
        }
      }
    }

    // Sort by confidence so the highest match is always first
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    
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
              p.x / math.min(size.width, size.height),
              p.y / math.max(size.width, size.height),
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
