import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

import '../logic/gesture_logic.dart';
import '../logic/pose_service.dart';
import '../widgets/painters.dart';

class TranslateScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const TranslateScreen({
    super.key,
    required this.cameras,
  });

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  CameraController? _controller;
  HandLandmarkerPlugin? _handPlugin;
  StreamSubscription<List<Hand>>? _handSubscription;

  final PoseService _poseService = PoseService();

  bool _isReady = false;
  bool _isPoseDetecting = false;
  bool _isDisposed = false;

  String _status = 'Initializing...';
  String? _initializationError;

  List<Hand> _allHands = <Hand>[];
  PoseFrameResult? _latestPoseResult;

  @override
  void initState() {
    super.initState();
    _initializeSystem();
  }

  Future<void> _initializeSystem() async {
    try {
      if (widget.cameras.isEmpty) {
        throw StateError('No camera found.');
      }

      final CameraDescription selectedCamera = widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => widget.cameras.first,
      );

      _handPlugin = HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.6,
        delegate: HandLandmarkerDelegate.gpu,
      );

      _handSubscription = _handPlugin!.landmarkStream.listen(_handleHandResults);

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      if (!mounted || _isDisposed) return;

      setState(() {
        _isReady = true;
        _status = 'Ready';
      });

      await _controller!.startImageStream(_processCameraFrame);
    } catch (error) {
      debugPrint('Init error: $error');
      if (!mounted || _isDisposed) return;
      setState(() {
        _initializationError = error.toString();
        _status = 'Error initializing';
      });
    }
  }

  void _processCameraFrame(CameraImage image) {
    if (_isDisposed || !_isReady || _controller == null) return;

    // 1. MediaPipe Hand Processing
    _handPlugin?.processFrame(image, _controller!.description.sensorOrientation);

    // 2. Pose Processing (Service handles NV21 conversion and inference)
    if (!_isPoseDetecting) {
      _isPoseDetecting = true;
      _poseService.processImage(
        image, 
        _controller!.description, 
        _controller!.value.deviceOrientation,
      ).then((result) {
        if (result != null && mounted && !_isDisposed) {
          setState(() {
            _latestPoseResult = result;
            _updateStatus();
          });
        }
        _isPoseDetecting = false;
      });
    }
  }

  void _handleHandResults(List<Hand> hands) {
    if (!mounted || _isDisposed) return;
    setState(() {
      _allHands = hands;
      _updateStatus();
    });
  }

  void _updateStatus() {
    final String gestureText = GestureLogic.analyzeGestures(
      hands: _allHands,
      posePoints: _latestPoseResult?.landmarks ?? {},
      imageSize: _latestPoseResult?.imageSize,
    );

    _status = 'H:${_allHands.length} B:${(_latestPoseResult?.hasPose ?? false) ? 1 : 0} | $gestureText';
  }

  @override
  void dispose() {
    _isDisposed = true;
    _handSubscription?.cancel();
    _controller?.dispose();
    _handPlugin?.dispose();
    _poseService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gesture to Text')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_initializationError == null) const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_status, style: TextStyle(color: _initializationError == null ? Colors.black : Colors.red)),
            ],
          ),
        ),
      );
    }

    final Size previewSize = _controller!.value.previewSize!;
    final Size displaySize = Size(previewSize.height, previewSize.width);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gesture to Text'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1E1B4B),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: displaySize.width,
                height: displaySize.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_controller!),

                    // Body Skeleton
                    if (_latestPoseResult != null && _latestPoseResult!.hasPose)
                      CustomPaint(
                        painter: PosePainter(
                          landmarks: _latestPoseResult!.landmarks,
                          imageSize: _latestPoseResult!.imageSize,
                          rotation: _latestPoseResult!.rotation,
                          lensDirection: _controller!.description.lensDirection,
                        ),
                      ),

                    // Hand Skeleton
                    if (_allHands.isNotEmpty)
                      CustomPaint(
                        painter: HandPainter(
                          hands: _allHands,
                          previewSize: previewSize,
                          lensDirection: _controller!.description.lensDirection,
                          sensorOrientation: _controller!.description.sensorOrientation,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Status Bar
          Positioned(
            left: 20, right: 20, bottom: 40,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
