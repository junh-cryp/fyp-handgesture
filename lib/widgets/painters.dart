import 'dart:math' as math;
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

/*
 * MediaPipe hand skeleton painter.
 */
class HandPainter extends CustomPainter {
  final List<Hand> hands;
  final Size previewSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;

  HandPainter({
    required this.hands,
    required this.previewSize,
    required this.lensDirection,
    required this.sensorOrientation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (previewSize.width <= 0 || previewSize.height <= 0) {
      return;
    }

    final double scale = size.width / previewSize.height;

    if (scale <= 0) {
      return;
    }

    final Paint pointPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;

    final Paint linePaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = 4 / scale
      ..strokeCap = StrokeCap.round;

    canvas.save();

    final Offset centre = Offset(
      size.width / 2,
      size.height / 2,
    );

    canvas.translate(
      centre.dx,
      centre.dy,
    );

    canvas.rotate(
      sensorOrientation * math.pi / 180,
    );

    if (lensDirection == CameraLensDirection.front) {
      canvas.scale(-1, 1);
      canvas.rotate(math.pi);
    }

    canvas.scale(scale);

    final double logicalWidth = previewSize.width;
    final double logicalHeight = previewSize.height;

    for (final Hand hand in hands) {
      final points = hand.landmarks;

      if (points.length < 21) {
        continue;
      }

      Offset landmarkOffset(int index) {
        final landmark = points[index];

        return Offset(
          (landmark.x - 0.5) * logicalWidth,
          (landmark.y - 0.5) * logicalHeight,
        );
      }

      for (final List<int> connection in HandLandmarkConnections.connections) {
        final int startIndex = connection[0];
        final int endIndex = connection[1];

        if (startIndex >= points.length || endIndex >= points.length) {
          continue;
        }

        canvas.drawLine(
          landmarkOffset(startIndex),
          landmarkOffset(endIndex),
          linePaint,
        );
      }

      for (int index = 0; index < points.length; index++) {
        canvas.drawCircle(
          landmarkOffset(index),
          6 / scale,
          pointPaint,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HandPainter oldDelegate) => true;
}

class HandLandmarkConnections {
  static const List<List<int>> connections = [
    [0, 1], [1, 2], [2, 3], [3, 4], // Thumb
    [0, 5], [5, 6], [6, 7], [7, 8], // Index
    [5, 9], [9, 10], [10, 11], [11, 12], // Middle
    [9, 13], [13, 14], [14, 15], [15, 16], // Ring
    [13, 17], [17, 18], [18, 19], [19, 20], // Little
    [0, 17], // Palm
  ];
}

/*
 * ML Kit body skeleton painter.
 */
class PosePainter extends CustomPainter {
  final Map<PoseLandmarkType, PoseLandmark> landmarks;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;

  PosePainter({
    required this.landmarks,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.redAccent.withOpacity(0.4)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final Paint pointPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    final Paint glowPaint = Paint()
      ..color = Colors.red.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final Paint chestPointPaint = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.fill;

    final Paint chestGlowPaint = Paint()
      ..color = Colors.orange.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    Offset? getOffset(PoseLandmarkType type) {
      final PoseLandmark? landmark = landmarks[type];
      if (landmark == null || landmark.likelihood < 0.35) return null;

      return Offset(
        _translateX(landmark.x, size, imageSize),
        _translateY(landmark.y, size, imageSize),
      );
    }

    void drawJoint(Offset pos, {double radius = 6, bool isChest = false}) {
      canvas.drawCircle(pos, radius * 2.2, isChest ? chestGlowPaint : glowPaint);
      canvas.drawCircle(pos, radius, isChest ? chestPointPaint : pointPaint);
    }

    void drawConnection(PoseLandmarkType a, PoseLandmarkType b) {
      final p1 = getOffset(a);
      final p2 = getOffset(b);
      if (p1 != null && p2 != null) canvas.drawLine(p1, p2, linePaint);
    }

    // Connections
    drawConnection(PoseLandmarkType.leftEar, PoseLandmarkType.leftEye);
    drawConnection(PoseLandmarkType.leftEye, PoseLandmarkType.nose);
    drawConnection(PoseLandmarkType.nose, PoseLandmarkType.rightEye);
    drawConnection(PoseLandmarkType.rightEye, PoseLandmarkType.rightEar);
    drawConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawConnection(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    drawConnection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawConnection(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    drawConnection(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawConnection(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawConnection(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    // Points
    final nose = getOffset(PoseLandmarkType.nose);
    if (nose != null) drawJoint(nose, radius: 8);

    for (final type in [
      PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip, PoseLandmarkType.rightHip
    ]) {
      final pos = getOffset(type);
      if (pos != null) drawJoint(pos);
    }

    // Chest Estimation (Fallback to shoulder-only if hips are missing)
    final lSh = getOffset(PoseLandmarkType.leftShoulder);
    final rSh = getOffset(PoseLandmarkType.rightShoulder);

    if (lSh != null && rSh != null) {
      final sMid = Offset((lSh.dx + rSh.dx) / 2, (lSh.dy + rSh.dy) / 2);
      final lHip = getOffset(PoseLandmarkType.leftHip);
      final rHip = getOffset(PoseLandmarkType.rightHip);

      Offset chest;
      if (lHip != null && rHip != null) {
        final hMid = Offset((lHip.dx + rHip.dx) / 2, (lHip.dy + rHip.dy) / 2);
        chest = Offset(
          sMid.dx + (hMid.dx - sMid.dx) * 0.27,
          sMid.dy + (hMid.dy - sMid.dy) * 0.27,
        );
      } else {
        // Fallback: estimate chest position below shoulders based on shoulder width
        // This helps when the user is sitting and hips are out of frame
        final sw = (lSh - rSh).distance;
        chest = Offset(sMid.dx, sMid.dy + (sw * 0.35));
      }
      drawJoint(chest, radius: 10, isChest: true);
    }
  }

  double _translateX(double x, Size canvasSize, Size sourceSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x * canvasSize.width / sourceSize.height;
      case InputImageRotation.rotation270deg:
        return canvasSize.width - (x * canvasSize.width / sourceSize.height);
      default:
        if (lensDirection == CameraLensDirection.front) {
          return canvasSize.width - (x * canvasSize.width / sourceSize.width);
        }
        return x * canvasSize.width / sourceSize.width;
    }
  }

  double _translateY(double y, Size canvasSize, Size sourceSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * canvasSize.height / sourceSize.width;
      default:
        return y * canvasSize.height / sourceSize.height;
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) => true;
}
