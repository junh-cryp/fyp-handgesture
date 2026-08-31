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

// DESCRIPTION: Modes for the translation screen
enum TranslateMode { translate, record }

class TranslateScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const TranslateScreen({
    super.key,
    required this.cameras,
  });

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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

  // DESCRIPTION: RECORD MODE - State variables
  TranslateMode _currentMode = TranslateMode.translate;
  bool _isRecording = false;
  bool _isShowingSummary = false;
  List<String> _recordedWords = [];

  // DESCRIPTION: TRANSLATE MODE - Gesture History & Sentence Logic
  String _currentGesture = "";
  Timer? _gestureTimer;
  final List<String> _history = [];
  final List<String> _sentence = [];
  bool _showSuccessTick = false;
  double _currentAccuracy = 0.0;

  @override
  void initState() {
    super.initState();
    _initTts();
    _initializeSystem();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("ms-MY");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _initializeSystem() async {
    try {
      if (!mounted) return;
      setState(() => _status = _ts.translate("loading_sys"));
      
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
    
    // DESCRIPTION: RECORD MODE - Only process camera if recording is active
    if (_currentMode == TranslateMode.record && !_isRecording) return;

    _handPlugin?.processFrame(image, _controller!.description.sensorOrientation);

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

  // DESCRIPTION: TRANSLATE & ACCURACY - Processing detection results
  void _updateStatus() {
    final result = GestureLogic.analyzeGestures(
      hands: _allHands,
      posePoints: _latestPoseResult?.landmarks ?? {},
      imageSize: _latestPoseResult?.imageSize,
    );

    final String gestureText = result.word;
    final double accuracy = result.confidence;

    if (!mounted) return;

    setState(() {
      if (gestureText.isNotEmpty) {
        if (gestureText != _currentGesture) {
          _currentGesture = gestureText;
          _currentAccuracy = accuracy;
          _gestureTimer?.cancel();
          _gestureTimer = Timer(const Duration(milliseconds: 1200), () {
            if (mounted && _currentGesture.isNotEmpty) {
              final detectedWord = _currentGesture;
              
              if (_currentMode == TranslateMode.translate) {
                // DESCRIPTION: TRANSLATE MODE - Instant speech and history update
                _tts.speak(detectedWord);
                
                final words = detectedWord.split(", ");
                for (var word in words) {
                  final trimmed = word.trim();
                  if (trimmed.isNotEmpty) {
                    _history.insert(0, trimmed);
                  }
                }
              } else if (_currentMode == TranslateMode.record && _isRecording) {
                // DESCRIPTION: RECORD MODE - Silent collection of words
                _recordedWords.add(detectedWord);
              }

              setState(() {
                _status = detectedWord;
                _showSuccessTick = true;
                _isShowingResult = true;
              });

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

      if (!_isShowingResult) {
        if (_allHands.isEmpty) {
          _status = "";
          _currentAccuracy = 0.0;
        } else {
          _status = _allHands.length == 1 
              ? _ts.translate("hand_detected") 
              : "${_allHands.length} ${_ts.translate("hands_detected")}";
        }
      }
    });
  }

  Future<void> _speakSentence() async {
    if (_sentence.isEmpty) return;
    String text = _sentence.join(" ");
    await _tts.speak(text);
  }

  // DESCRIPTION: RECORD MODE - Control functions
  void _startRecording() {
    setState(() {
      _isRecording = true;
      _isShowingSummary = false;
      _recordedWords = [];
      _status = "";
    });
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
      _isShowingSummary = true;
    });
  }

  void _finishRecordSession() {
    setState(() {
      _isShowingSummary = false;
      _recordedWords = [];
    });
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
      return _buildLoadingScreen();
    }

    final Size previewSize = _controller!.value.previewSize!;
    final Size displaySize = Size(previewSize.height, previewSize.width);

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      endDrawer: _buildRecordDrawer(),
      body: Stack(
        children: [
          // DESCRIPTION: TRANSLATE & RECORD - Camera View
          if (_currentMode == TranslateMode.translate || _isRecording)
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

          // DESCRIPTION: RECORD MODE - Start Screen
          if (_currentMode == TranslateMode.record && !_isRecording && !_isShowingSummary)
            _buildRecordStartInterface(),

          // DESCRIPTION: RECORD MODE - Summary and Editing Screen
          if (_currentMode == TranslateMode.record && _isShowingSummary)
            _buildRecordSummary(),

          // DESCRIPTION: TRANSLATE & ACCURACY - Detection Popup
          if ((_currentMode == TranslateMode.translate || _isRecording) && _status.isNotEmpty)
            _buildDetectionPopup(),

          // DESCRIPTION: RECORD MODE - In-session controls
          if (_currentMode == TranslateMode.record && _isRecording)
            _buildRecordControls(),

          // DESCRIPTION: TRANSLATE MODE - Bottom sentence preview
          if (_currentMode == TranslateMode.translate && _sentence.isNotEmpty)
            _buildSentenceBar(),

          // DESCRIPTION: TRANSLATE & RECORD - Success animation
          if (_showSuccessTick)
            _buildSuccessTick(),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
                BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 10)),
              ]),
              child: const CircularProgressIndicator(strokeWidth: 4, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1))),
            ),
            const SizedBox(height: 40),
            Text(_status, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B), letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(_ts.translate("loading_wait"), style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        children: [
          const Text('BimTalk Live', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Container(
            height: 32,
            width: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _currentMode = TranslateMode.translate;
                      _isRecording = false;
                      _isShowingSummary = false;
                      _history.clear(); // Clear history when switching to Translate
                      _sentence.clear(); // Clear sentence builder
                    }),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _currentMode == TranslateMode.translate ? const Color(0xFF6366F1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Translate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _currentMode = TranslateMode.record;
                    }),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _currentMode == TranslateMode.record ? const Color(0xFF6366F1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Record', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black.withOpacity(0.3),
      elevation: 0,
      centerTitle: true,
      toolbarHeight: 90,
      shape: Border(
        bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history, color: Colors.white),
          onPressed: _showHistoryDialog,
        ),
      ],
    );
  }

  Widget _buildRecordStartInterface() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mic_none_rounded, size: 80, color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _startRecording,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 10,
            ),
            child: const Text('Start Recording', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          const Text('Translate multiple signs and speak them all at once.', style: TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildRecordControls() {
    return Positioned(
      bottom: 50,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // View List Button
          FloatingActionButton.extended(
            heroTag: "view_list",
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            backgroundColor: Colors.white.withOpacity(0.3),
            icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
            label: Text('${_recordedWords.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          
          // Done Button
          ElevatedButton(
            onPressed: _stopRecording,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Done', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),

          const SizedBox(width: 56), // Placeholder for symmetry if needed
        ],
      ),
    );
  }

  Widget _buildRecordSummary() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Recording Summary",
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B)),
          ),
          const SizedBox(height: 8),
          Text(
            "Review and edit your captured sentence.",
            style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 16),
          ),
          const SizedBox(height: 30),
          
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
                ]
              ),
              child: _recordedWords.isEmpty 
                ? const Center(child: Text("No words recorded."))
                : ReorderableListView.builder(
                    itemCount: _recordedWords.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _recordedWords.removeAt(oldIndex);
                        _recordedWords.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) => Column(
                      key: ValueKey('recorded_$index'),
                      children: [
                        if (index == 0)
                          _buildInsertDivider(0),
                        ListTile(
                          title: Text(_recordedWords[index], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Color(0xFF6366F1)),
                                onPressed: () => _editRecordedWord(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFF43F5E)),
                                onPressed: () => setState(() => _recordedWords.removeAt(index)),
                              ),
                            ],
                          ),
                        ),
                        _buildInsertDivider(index + 1),
                      ],
                    ),
                  ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _tts.speak(_recordedWords.join(" ")),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text("Speak Sentence", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _finishRecordSession,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text("Finish", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1B4B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => _addWordToSummary(),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text("Add Missing Word"),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRecordDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF6366F1)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mic_none_rounded, color: Colors.white, size: 40),
                  const SizedBox(height: 10),
                  const Text("Current Detections", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("${_recordedWords.length} words collected", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _recordedWords.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) => ListTile(
                title: Text(_recordedWords[index], style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => setState(() => _recordedWords.removeAt(index)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editRecordedWord(int index) {
    TextEditingController controller = TextEditingController(text: _recordedWords[index]);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Word"),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: "Enter correct word")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() => _recordedWords[index] = controller.text);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _addWordToSummary({int? atIndex}) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(atIndex == null ? "Add Word" : "Insert Word"),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: "Enter word to add")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  if (atIndex == null) {
                    _recordedWords.add(controller.text);
                  } else {
                    _recordedWords.insert(atIndex, controller.text);
                  }
                });
              }
              Navigator.pop(context);
            },
            child: Text(atIndex == null ? "Add" : "Insert"),
          ),
        ],
      ),
    );
  }

  Widget _buildInsertDivider(int index) {
    return GestureDetector(
      onTap: () => _addWordToSummary(atIndex: index),
      child: Container(
        height: 20,
        width: double.infinity,
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 30,
            height: 2,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.2),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }

  // DESCRIPTION: ACCURACY - UI element to show the match percentage
  Widget _buildDetectionPopup() {
    return Align(
      alignment: const Alignment(0, -0.65),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF6366F1), width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _status,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B), letterSpacing: 1.5),
                ),
                if (_isShowingResult && _currentAccuracy > 0) ...[
                  const SizedBox(height: 4),
                  // DESCRIPTION: ACCURACY - Dynamic color based on match quality
                  Text(
                    "${(_currentAccuracy * 100).toStringAsFixed(1)}% Match",
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.bold, 
                      color: _currentAccuracy > 0.8 ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSentenceBar() {
    return Positioned(
      left: 24, right: 24, bottom: 40,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
            decoration: BoxDecoration(color: const Color(0xFF1E1B4B).withOpacity(0.8), borderRadius: BorderRadius.circular(30)),
            child: Row(
              children: [
                Expanded(child: Text(_sentence.join(" "), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.volume_up, color: Colors.white), onPressed: _speakSentence),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 20), onPressed: () => setState(() => _sentence.clear())),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessTick() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.9), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 60),
            ),
          );
        },
      ),
    );
  }

  // DESCRIPTION: TRANSLATE MODE - History and Sentence building dialog
  void _showHistoryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 8, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Sentence Builder", 
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B), letterSpacing: -0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_sentence.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() => _sentence.clear());
                          setModalState(() {});
                        },
                        child: const Text("Clear", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close), 
                      onPressed: () => Navigator.pop(context)
                    ),
                  ],
                ),
              ),

              // DESCRIPTION: TRANSLATE MODE - Interactive reorderable sentence chips
              if (_sentence.isNotEmpty)
                Container(
                  height: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ReorderableListView(
                          scrollDirection: Axis.horizontal,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) newIndex -= 1;
                              final item = _sentence.removeAt(oldIndex);
                              _sentence.insert(newIndex, item);
                            });
                            setModalState(() {});
                          },
                          children: List.generate(_sentence.length, (index) => 
                            Container(
                              key: ValueKey('sentence_$index'),
                              margin: const EdgeInsets.only(right: 8),
                              child: Chip(
                                label: Text(_sentence[index], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                backgroundColor: const Color(0xFF6366F1),
                                deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
                                onDeleted: () {
                                  setState(() => _sentence.removeAt(index));
                                  setModalState(() {});
                                },
                              ),
                            )
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text("Drag to reorder words", style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              
              if (_sentence.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: ElevatedButton.icon(
                    onPressed: _speakSentence,
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text("Speak Built Sentence"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1B4B),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),

              const Divider(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Detected Signs", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.blueGrey)),
                    if (_history.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _history.clear());
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.redAccent),
                        label: const Text("Clear All", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _history.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(_history[index], style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.add_circle_outline, color: Color(0xFF6366F1)),
                    onTap: () {
                      setState(() => _sentence.add(_history[index]));
                      setModalState(() {});
                    },
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
