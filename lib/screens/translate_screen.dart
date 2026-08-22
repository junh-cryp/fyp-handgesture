import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

import 'package:flutter_tts/flutter_tts.dart';

import '../logic/gesture_logic.dart';
import '../logic/pose_service.dart';
import '../widgets/painters.dart';
import '../logic/translation_service.dart';

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
  final FlutterTts _tts = FlutterTts();
  final TranslationService _ts = TranslationService();

  bool _isReady = false;
  bool _isPoseDetecting = false;
  bool _isDisposed = false;
  bool _isShowingResult = false;

  String _status = '';
  String? _initializationError;

  List<Hand> _allHands = <Hand>[];
  PoseFrameResult? _latestPoseResult;

  // Gesture History & Sentence Logic
  String _currentGesture = "";
  Timer? _gestureTimer;
  final List<String> _history = [];
  final List<String> _sentence = [];
  bool _showSuccessTick = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initializeSystem();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("ms-MY"); // Set to Malay (Malaysia)
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _initializeSystem() async {
    try {
      if (!mounted) return;
      setState(() => _status = _ts.translate("loading_sys"));
      
      // Delay to ensure UI transition finishes
      await Future.delayed(const Duration(milliseconds: 600));

      if (widget.cameras.isEmpty) {
        throw StateError('No camera found.');
      }

      final CameraDescription selectedCamera = widget.cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => widget.cameras.first,
      );

      if (!mounted) return;
      setState(() => _status = _ts.translate("loading_ai"));
      
      _handPlugin = HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.6,
        delegate: HandLandmarkerDelegate.gpu,
      );

      _handSubscription = _handPlugin!.landmarkStream.listen(_handleHandResults);

      if (!mounted) return;
      setState(() => _status = _ts.translate("loading_cam"));

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      if (!mounted || _isDisposed) return;

      setState(() => _status = _ts.translate("loading_stream"));
      await _controller!.startImageStream(_processCameraFrame);

      setState(() {
        _isReady = true;
        _status = '';
      });
    } catch (error) {
      debugPrint('Init error: $error');
      if (!mounted || _isDisposed) return;
      setState(() {
        _initializationError = error.toString();
        _status = _ts.translate("error_init");
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
          _latestPoseResult = result;
          _updateStatus();
        }
        _isPoseDetecting = false;
      });
    }
  }

  void _handleHandResults(List<Hand> hands) {
    if (!mounted || _isDisposed) return;
    _allHands = hands;
    _updateStatus();
  }

  void _updateStatus() {
    final String gestureText = GestureLogic.analyzeGestures(
      hands: _allHands,
      posePoints: _latestPoseResult?.landmarks ?? {},
      imageSize: _latestPoseResult?.imageSize,
    );

    if (!mounted) return;

    setState(() {
      if (gestureText.isNotEmpty) {
        if (gestureText != _currentGesture) {
          _currentGesture = gestureText;
          _gestureTimer?.cancel();
          // stabilization for "locking in" to history
          _gestureTimer = Timer(const Duration(milliseconds: 1200), () {
            if (mounted && _currentGesture.isNotEmpty) {
              final detectedWord = _currentGesture;
              
              // Speak the detected word
              _tts.speak(detectedWord);

              setState(() {
                _status = detectedWord;
                _showSuccessTick = true;
                _isShowingResult = true;
                
                // Add to history
                final words = detectedWord.split(", ");
                for (var word in words) {
                  final trimmed = word.trim();
                  if (trimmed.isNotEmpty) {
                    _history.insert(0, trimmed);
                  }
                }
              });

              // Hide tick after 1.5s
              Timer(const Duration(milliseconds: 1500), () {
                if (mounted) {
                  setState(() {
                    _showSuccessTick = false;
                    _isShowingResult = false;
                  });
                }
              });
            }
          });
        }
      } else {
        _currentGesture = "";
        _gestureTimer?.cancel();
      }

      // Update display status based on detection state
      if (!_isShowingResult) {
        if (_allHands.isEmpty) {
          _status = "";
        } else {
          if (_allHands.length == 1) {
            _status = _ts.translate("hand_detected");
          } else {
            _status = "${_allHands.length} ${_ts.translate("hands_detected")}";
          }
        }
      }
    });
  }

  Future<void> _speakSentence() async {
    if (_sentence.isEmpty) return;
    String text = _sentence.join(" ");
    await _tts.speak(text);
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
        backgroundColor: const Color(0xFFF3F4FF),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.15),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                _status,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _ts.translate("loading_wait"),
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              if (_initializationError != null) ...[
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    "Error: $_initializationError",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _initializeSystem(),
                  icon: const Icon(Icons.refresh),
                  label: Text(_ts.translate("retry")),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final Size previewSize = _controller!.value.previewSize!;
    final Size displaySize = Size(previewSize.height, previewSize.width);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Translate'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1E1B4B),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.history, size: 28),
                if (_history.isNotEmpty)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '${_history.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showHistoryDialog,
          ),
          const SizedBox(width: 8),
        ],
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
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: PosePainter(
                            landmarks: _latestPoseResult!.landmarks,
                            imageSize: _latestPoseResult!.imageSize,
                            rotation: _latestPoseResult!.rotation,
                            lensDirection: _controller!.description.lensDirection,
                          ),
                        ),
                      ),

                    // Hand Skeleton
                    if (_allHands.isNotEmpty)
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: HandPainter(
                            hands: _allHands,
                            previewSize: previewSize,
                            lensDirection: _controller!.description.lensDirection,
                            sensorOrientation: _controller!.description.sensorOrientation,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Detection Feedback Popup (Improved with Glassmorphism)
          if (_status.isNotEmpty)
            Align(
              alignment: const Alignment(0, -0.6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.7),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Floating Speak Bar (Visible when sentence has content - Improved)
          if (_sentence.isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              bottom: 30,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              _sentence.join(" "),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1B4B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.volume_up, color: Color(0xFF6366F1)),
                            onPressed: _speakSentence,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () => setState(() => _sentence.clear()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Green Tick Animation Overlay
          if (_showSuccessTick)
            Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _showSuccessTick ? 1.0 : 0.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showHistoryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_ts.translate("sentence_builder"), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B))),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),

              // Current Sentence Display (within History)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Column(
                  children: [
                    Text(
                      _sentence.isEmpty ? _ts.translate("tap_to_build") : _sentence.join(" "),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _sentence.isEmpty ? Colors.grey : const Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _sentence.isEmpty ? null : () => _speakSentence(),
                          icon: const Icon(Icons.volume_up),
                          label: const Text("SPEAK"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _sentence.isEmpty ? null : () {
                            setState(() => _sentence.clear());
                            setModalState(() {});
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: Text(_ts.translate("clear")),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(),

              // History List
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_ts.translate("detected_signs"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                          TextButton(
                            onPressed: () {
                              setState(() => _history.clear());
                              setModalState(() {});
                            },
                            child: Text(_ts.translate("clear_history")),
                          ),
                        ],
                      ),
                      Expanded(
                        child: _history.isEmpty
                            ? Center(child: Text(_ts.translate("no_signs"), style: const TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: _history.length,
                                itemBuilder: (context, index) {
                                  final word = _history[index];
                                  return Card(
                                    elevation: 0,
                                    color: const Color(0xFFF9FAFB),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                                    ),
                                    child: ListTile(
                                      title: Text(word, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                                      trailing: const Icon(Icons.add_circle, color: Color(0xFF6366F1)),
                                      onTap: () {
                                        setState(() => _sentence.add(word));
                                        setModalState(() {});
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
