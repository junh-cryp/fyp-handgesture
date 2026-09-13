import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'gesture_logic.dart';
import 'pose_service.dart';
import 'ml_inference_service.dart';
import 'ml_data_service.dart';

class VisionViewModel extends ChangeNotifier {
  CameraController? controller;
  HandLandmarkerPlugin? _handPlugin;
  StreamSubscription<List<Hand>>? _handSubscription;
  final PoseService _poseService = PoseService();
  final MLInferenceService _inferenceService = MLInferenceService();
  final MLDataService _dataService = MLDataService();

  bool isReady = false;
  bool isDisposed = false;
  bool _isPoseDetecting = false;
  String status = "";

  List<Hand> allHands = [];
  PoseFrameResult? latestPoseResult;
  List<GestureResult> candidates = [];
  List<GestureDebugInfo> debugInfo = [];

  String currentGesture = "";
  String mlPrediction = "";
  Timer? _gestureTimer;
  bool isAwaitingSelection = false;

  final Function(List<GestureResult>) onDetectionReady;

  VisionViewModel({required this.onDetectionReady});

  Future<void> initialize(List<CameraDescription> cameras) async {
    try {
      status = "loading_sys";
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 600));

      if (cameras.isEmpty) return;

      final selectedCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      status = "loading_ai";
      notifyListeners();
      _handPlugin = HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.6,
        delegate: HandLandmarkerDelegate.gpu,
      );
      _handSubscription = _handPlugin!.landmarkStream.listen(_handleHandResults);

      status = "loading_cam";
      notifyListeners();
      controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );

      await controller!.initialize();
      if (isDisposed) return;

      status = "loading_stream";
      notifyListeners();
      await controller!.startImageStream(_processCameraFrame);
      
      await _inferenceService.loadModel();
      
      isReady = true;
      status = "";
      notifyListeners();
    } catch (e) {
      debugPrint("VisionVM Init Error: $e");
      status = "error_init";
      notifyListeners();
    }
  }

  void _processCameraFrame(CameraImage image) {
    if (isDisposed || !isReady || controller == null) return;

    _handPlugin?.processFrame(image, controller!.description.sensorOrientation);

    if (!_isPoseDetecting) {
      _isPoseDetecting = true;
      _poseService.processImage(image, controller!.description, controller!.value.deviceOrientation).then((result) {
        if (result != null && !isDisposed) {
          latestPoseResult = result;
          // IMPORTANT: Always run analysis to keep points moving
          _runAnalysis();
        }
        _isPoseDetecting = false;
      });
    }
  }

  void _handleHandResults(List<Hand> hands) {
    if (isDisposed) return;
    allHands = hands;
    _runAnalysis();
  }

  void _runAnalysis() {
    // 0. Update Debug Info
    debugInfo = GestureLogic.getDebugInfo(
      allHands, 
      latestPoseResult?.landmarks, 
      latestPoseResult?.imageSize,
    );

    // 1. ML Inference (New)
    if (allHands.isNotEmpty) {
      final vector = _dataService.normalizeLandmarks(allHands.first);
      if (vector.isNotEmpty) {
        mlPrediction = _inferenceService.predict(vector);
      }
    } else {
      mlPrediction = "";
    }

    // 2. Logic for gesture candidates
    final results = GestureLogic.analyzeGestures(
      hands: allHands,
      posePoints: latestPoseResult?.landmarks ?? {},
      imageSize: latestPoseResult?.imageSize,
    );

    // 3. Add confident ML results to candidates
    if (mlPrediction.isNotEmpty && !mlPrediction.startsWith("Unknown") && !mlPrediction.contains("not loaded")) {
      try {
        final parts = mlPrediction.split(" (");
        final word = parts[0];
        final score = double.parse(parts[1].replaceAll("%)", "")) / 100.0;
        if (!results.any((r) => r.word == word)) {
          results.insert(0, GestureResult(word, score));
        }
      } catch (_) {}
    }

    // Only update candidates if we aren't currently waiting for a selection
    if (!isAwaitingSelection) {
      candidates = results;
      if (results.isNotEmpty) {
        final topResult = results.first;
        if (topResult.word != currentGesture) {
          currentGesture = topResult.word;
          _gestureTimer?.cancel();
          _gestureTimer = Timer(const Duration(milliseconds: 1200), () {
            if (!isDisposed && currentGesture.isNotEmpty) {
              isAwaitingSelection = true;
              onDetectionReady(candidates);
              notifyListeners();
            }
          });
        }
      } else {
        currentGesture = "";
        _gestureTimer?.cancel();
      }
    }

    // 2. ALWAYS notify UI so skeletal points move every frame
    notifyListeners();
  }

  void resetDetection() {
    isAwaitingSelection = false;
    currentGesture = "";
    candidates = [];
    notifyListeners();
  }

  @override
  void dispose() {
    isDisposed = true;
    _gestureTimer?.cancel();
    _handSubscription?.cancel();
    controller?.dispose();
    _handPlugin?.dispose();
    _poseService.dispose();
    _inferenceService.dispose();
    super.dispose();
  }
}
