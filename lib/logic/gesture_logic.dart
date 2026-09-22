import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

class GestureResult {
  final String word;
  final double matchScore;
  final String? imageUrl;
  GestureResult(this.word, this.matchScore, {this.imageUrl});
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

class GestureLogic {
  static List<GestureResult> analyzeGestures({required List<Hand> hands, Map<PoseLandmarkType, PoseLandmark>? posePoints, required Size? imageSize}) {
    // This is now fully computed on the FastAPI Python backend server instance.
    return [];
  }

  static List<GestureDebugInfo> getDebugInfo(List<Hand> hands, Map<PoseLandmarkType, PoseLandmark>? pose, Size? size) {
    if (hands.isEmpty) return [];
    return hands.map((hand) {
      return GestureDebugInfo(
        fingerStatus: "Streaming coordinates...",
        orientation: "Processing...",
        tipPos: "Active",
        direction: "Live Engine",
        extra: "",
      );
    }).toList();
  }
}
