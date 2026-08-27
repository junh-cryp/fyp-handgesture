import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

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
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                _status,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B4B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _ts.translate("loading_wait"),
                style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 14, fontWeight: FontWeight.w500),
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('BimTalk Live', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6366F1), letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.auto_awesome_motion_rounded, size: 22, color: Colors.white),
                    if (_history.isNotEmpty)
                      Positioned(
                        right: 0, top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Color(0xFFF43F5E), shape: BoxShape.circle),
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
            ),
          ),
        ],
      ),
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

          // Detection Feedback Popup (High Class Glassmorphism)
          if (_status.isNotEmpty)
            Align(
              alignment: const Alignment(0, -0.65),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFEEF2FF),
                        letterSpacing: 1,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Floating Sentence Bar (Improved for Classy Look)
          if (_sentence.isNotEmpty)
            Positioned(
              left: 24,
              right: 24,
              bottom: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B4B).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _sentence.join(" "),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
                            onPressed: _speakSentence,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                          onPressed: () => setState(() => _sentence.clear()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Success Tick Overlay
          if (_showSuccessTick)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 60),
                    ),
                  );
                },
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _ts.translate("sentence_builder"), 
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B), letterSpacing: -0.5),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey), 
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Current Sentence Display
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _sentence.isEmpty ? _ts.translate("tap_to_build") : _sentence.join(" "),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _sentence.isEmpty ? Colors.white.withOpacity(0.6) : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SentenceActionBtn(
                          onPressed: _sentence.isEmpty ? null : () => _speakSentence(),
                          icon: Icons.volume_up_rounded,
                          label: "SPEAK",
                          isPrimary: false,
                        ),
                        const SizedBox(width: 16),
                        _SentenceActionBtn(
                          onPressed: _sentence.isEmpty ? null : () {
                            setState(() => _sentence.clear());
                            setModalState(() {});
                          },
                          icon: Icons.delete_outline_rounded,
                          label: _ts.translate("clear"),
                          isPrimary: false,
                          isDanger: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Divider(height: 1),
              ),

              // History List
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _ts.translate("detected_signs"), 
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.blueGrey.shade300, letterSpacing: 1),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() => _history.clear());
                                setModalState(() {});
                              },
                              child: Text(
                                _ts.translate("clear_history"),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF43F5E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _history.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade200),
                                    const SizedBox(height: 16),
                                    Text(_ts.translate("no_signs"), style: TextStyle(color: Colors.blueGrey.shade200, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 20),
                                itemCount: _history.length,
                                itemBuilder: (context, index) {
                                  final word = _history[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFF1F5F9)),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                      title: Text(
                                        word, 
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF334155)),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.add_rounded, color: Color(0xFF6366F1)),
                                      ),
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

class _SentenceActionBtn extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;
  final bool isDanger;

  const _SentenceActionBtn({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isPrimary = true,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDanger ? Colors.white.withOpacity(0.2) : Colors.white,
        foregroundColor: isDanger ? Colors.white : const Color(0xFF6366F1),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: isDanger ? const BorderSide(color: Colors.white30) : BorderSide.none,
        ),
      ),
    );
  }
}
