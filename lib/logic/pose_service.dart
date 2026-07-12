import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:io';

class PoseFrameResult {
  final Map<PoseLandmarkType, PoseLandmark> landmarks;
  final Size imageSize;
  final InputImageRotation rotation;
  final bool hasPose;
  PoseFrameResult(this.landmarks, this.imageSize, this.rotation, {this.hasPose = true});
}

class PoseService {
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    ),
  );

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Future<PoseFrameResult?> processImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) async {
    try {
      final rotation = _calculateRotation(camera, deviceOrientation);
      if (rotation == null) return null;

      final inputImage = InputImage.fromBytes(
        bytes: _convertYuv420ToNv21(image),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final List<Pose> poses = await _poseDetector.processImage(inputImage);
      final Size size = Size(image.width.toDouble(), image.height.toDouble());
      
      if (poses.isEmpty) return PoseFrameResult({}, size, rotation, hasPose: false);

      return PoseFrameResult(
        Map<PoseLandmarkType, PoseLandmark>.from(poses.first.landmarks),
        size,
        rotation,
      );
    } catch (e) {
      debugPrint('Pose Service Error: $e');
      return null;
    }
  }

  InputImageRotation? _calculateRotation(CameraDescription camera, DeviceOrientation orientation) {
    int sensorOrientation = camera.sensorOrientation;
    int? rotationCompensation = _orientations[orientation];
    if (rotationCompensation == null) return null;

    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
    }
    return InputImageRotationValue.fromRawValue(rotationCompensation);
  }

  Uint8List _convertYuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final nv21 = Uint8List(width * height + (width * height ~/ 2));
    int idY = 0;
    for (int row = 0; row < height; row++) {
      final start = row * yPlane.bytesPerRow;
      for (int col = 0; col < width; col++) {
        nv21[idY++] = yPlane.bytes[start + col];
      }
    }

    int idUV = width * height;
    final int uvWidth = width ~/ 2;
    final int uvHeight = height ~/ 2;
    for (int row = 0; row < uvHeight; row++) {
      final uStart = row * uPlane.bytesPerRow;
      final vStart = row * vPlane.bytesPerRow;
      for (int col = 0; col < uvWidth; col++) {
        nv21[idUV++] = vPlane.bytes[vStart + col * (vPlane.bytesPerPixel ?? 1)];
        nv21[idUV++] = uPlane.bytes[uStart + col * (uPlane.bytesPerPixel ?? 1)];
      }
    }
    return nv21;
  }

  void dispose() => _poseDetector.close();
}
