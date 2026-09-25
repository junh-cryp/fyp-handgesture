import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:http/http.dart' as http;
import 'gesture_logic.dart';
import 'pose_service.dart';

class VisionViewModel extends ChangeNotifier {
  CameraController? controller;
  HandLandmarkerPlugin? _handPlugin;
  StreamSubscription<List<Hand>>? _handSubscription;
  final PoseService _poseService = PoseService();

  bool isReady = false;
  bool isDisposed = false;
  bool _isPoseDetecting = false;
  String status = "";

  List<Hand> allHands = [];
  PoseFrameResult? latestPoseResult;
  List<GestureResult> candidates = [];
  List<GestureDebugInfo> debugInfo = [];

  String currentGesture = "";
  Timer? _gestureTimer;
  bool isAwaitingSelection = false;

  final Function(List<GestureResult>) onDetectionReady;

  VisionViewModel({required this.onDetectionReady});

  // Map of BIM signs that share the same gesture/motion (synonyms or twin signs)
  static const Map<String, List<String>> _gestureSynonyms = {
    "ANDA": ["ANDA", "AWAK"],
    "AWAK": ["ANDA", "AWAK"],
    "BELI": ["BELI", "BELANJA"],
    "BELANJA": ["BELI", "BELANJA"],
    "SAYA": ["SAYA", "AKU"],
    "AKU": ["SAYA", "AKU"],
  };

  // Replace the placeholder below with your laptop's real IP address from ipconfig!
  final String _backendUrl = 'http://192.168.0.47:8000/analyze-gesture';

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

  void _runAnalysis() async {
    // Generate simple debug info representations locally for frames tracking
    debugInfo = GestureLogic.getDebugInfo(
      allHands,
      latestPoseResult?.landmarks,
      latestPoseResult?.imageSize,
    );
    notifyListeners();

    if (allHands.isEmpty || isAwaitingSelection) return;

    try {
      // 1. Pack landmarks coordinates into a lightweight serialized payload
      final Map<String, dynamic> payload = {
        "hands": allHands.map((h) => {
          "landmarks": h.landmarks.map((l) => {"x": l.x, "y": l.y, "z": l.z}).toList()
        }).toList(),
        "posePoints": latestPoseResult?.landmarks.map((key, value) =>
            MapEntry(key.toString().split('.').last, {"x": value.x, "y": value.y})) ?? {},
        "imageSize": {
          "width": latestPoseResult?.imageSize.width ?? 480.0,
          "height": latestPoseResult?.imageSize.height ?? 640.0
        }
      };

      // 2. Post landmarks coordinates to Python FastAPI over local network
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        // 3. Map raw results back into GestureResults objects
        final List<GestureResult> rawResults = data.map((item) => GestureResult(
            item['word'],
            item['score']?.toDouble() ?? 1.0,
            imageUrl: item['image_url']
        )).toList();

        // 4. Expand synonyms / identical gestures (e.g. ANDA/AWAK, BELI/BELANJA)
        final List<GestureResult> expandedResults = [];
        final Set<String> addedWords = {};

        for (var res in rawResults) {
          final wordUpper = res.word.toUpperCase();
          final synonyms = _gestureSynonyms[wordUpper];

          if (synonyms != null) {
            for (var syn in synonyms) {
              if (!addedWords.contains(syn.toUpperCase())) {
                addedWords.add(syn.toUpperCase());
                expandedResults.add(GestureResult(
                  syn,
                  res.matchScore,
                  imageUrl: res.imageUrl,
                ));
              }
            }
          } else {
            if (!addedWords.contains(wordUpper)) {
              addedWords.add(wordUpper);
              expandedResults.add(res);
            }
          }
        }

        if (expandedResults.isNotEmpty) {
          candidates = expandedResults;
          final topResult = expandedResults.first;
          if (topResult.word != currentGesture) {
            currentGesture = topResult.word;
            _gestureTimer?.cancel();
            _gestureTimer = Timer(const Duration(milliseconds: 1200), () {
              if (!isDisposed && currentGesture.isNotEmpty) {
                isAwaitingSelection = true;
                onDetectionReady(expandedResults);
                notifyListeners();
              }
            });
          }
        } else {
          currentGesture = "";
          _gestureTimer?.cancel();
        }
      }
    } catch (e) {
      debugPrint("Error connecting to FastAPI backend instance: $e");
    }
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
    if (controller != null && controller!.value.isStreamingImages) {
      try {
        controller!.stopImageStream();
      } catch (e) {
        debugPrint("Error stopping image stream on dispose: $e");
      }
    }
    controller?.dispose();
    _handPlugin?.dispose();
    _poseService.dispose();
    super.dispose();
  }
}