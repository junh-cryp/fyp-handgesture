import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../logic/vision_vm.dart';
import '../widgets/painters.dart';
import '../logic/translation_service.dart';

class RecordScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const RecordScreen({super.key, required this.cameras});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  late VisionViewModel _vm;
  final FlutterTts _tts = FlutterTts();
  final TranslationService _ts = TranslationService();
  
  bool _isRecording = false;
  bool _isShowingSummary = false;
  final List<String> _recordedWords = [];
  bool _showSuccessTick = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _vm = VisionViewModel(onDetectionReady: (_) => setState(() {}));
    _vm.initialize(widget.cameras);
    _vm.addListener(() => setState(() {}));
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("ms-MY");
    await _tts.setSpeechRate(0.5);
  }

  void _onWordConfirmed(String word) {
    setState(() {
      if (_isRecording) {
        _recordedWords.add(word);
        _showSuccessTick = true;
      }
    });
    _vm.resetDetection();
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showSuccessTick = false);
    });
  }

  void _stopRecording() {
    if (_recordedWords.isNotEmpty) _tts.speak(_recordedWords.join(" "));
    setState(() {
      _isRecording = false;
      _isShowingSummary = true;
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_vm.isReady) return _buildLoadingScreen();

    final previewSize = _vm.controller!.value.previewSize!;
    final displaySize = Size(previewSize.height, previewSize.width);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('BimTalk Record', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: Colors.black.withOpacity(0.3),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          // 1. CAMERA STACK - ALWAYS ACTIVE
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: displaySize.width, height: displaySize.height,
                child: Stack(
                  children: [
                    CameraPreview(_vm.controller!),
                    if (_vm.latestPoseResult != null && _vm.latestPoseResult!.hasPose)
                      RepaintBoundary(
                        child: CustomPaint(
                          size: displaySize,
                          painter: PosePainter(
                            landmarks: _vm.latestPoseResult!.landmarks,
                            imageSize: _vm.latestPoseResult!.imageSize,
                            rotation: _vm.latestPoseResult!.rotation,
                            lensDirection: _vm.controller!.description.lensDirection,
                          ),
                        ),
                      ),
                    if (_vm.allHands.isNotEmpty)
                      RepaintBoundary(
                        child: CustomPaint(
                          size: displaySize,
                          painter: HandPainter(
                            hands: _vm.allHands,
                            previewSize: previewSize,
                            lensDirection: _vm.controller!.description.lensDirection,
                            sensorOrientation: _vm.controller!.description.sensorOrientation,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          if (!_isRecording && !_isShowingSummary) _buildStartUI(),
          if (_isShowingSummary) _buildSummaryUI(),

          if (_isRecording && _vm.isAwaitingSelection) _buildCandidateGrid(),

          if (_isRecording) ...[
            _buildRecordHUD(),
            Positioned(bottom: 30, right: 30, child: FloatingActionButton.large(onPressed: _stopRecording, backgroundColor: Colors.red, child: const Icon(Icons.stop))),
          ],

          if (_showSuccessTick) _buildSuccessTick(),
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
            Text(_ts.translate(_vm.status.isEmpty ? "loading_sys" : _vm.status), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E1B4B), letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(_ts.translate("loading_wait"), style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateGrid() {
    return Positioned(
      bottom: 120, left: 0, right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(20)), child: const Text("Confirm Sign", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(height: 15),
          Container(
            height: 200,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.2, crossAxisSpacing: 15, mainAxisSpacing: 15),
              itemCount: _vm.candidates.length,
              itemBuilder: (c, i) => ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.9), foregroundColor: const Color(0xFF1E1B4B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onPressed: () => _onWordConfirmed(_vm.candidates[i].word),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_vm.candidates[i].word, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      "Match: ${(_vm.candidates[i].matchScore * 100).toStringAsFixed(0)}%",
                      style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.cancel, color: Colors.white, size: 40), onPressed: () => _vm.resetDetection()),
        ],
      ),
    );
  }

  Widget _buildRecordHUD() {
    return Positioned(bottom: 120, left: 20, right: 100, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(15)), child: Text(_recordedWords.isEmpty ? "Recording active..." : _recordedWords.join(" "), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))));
  }

  Widget _buildStartUI() => Center(child: ElevatedButton.icon(onPressed: () => setState(() => _isRecording = true), icon: const Icon(Icons.mic, size: 40, color: Colors.white), label: const Text("Start New Recording", style: TextStyle(fontSize: 20, color: Colors.white)), style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(25), backgroundColor: const Color(0xFF6366F1))));
  Widget _buildSummaryUI() => Container(color: Colors.white, width: double.infinity, height: double.infinity, padding: const EdgeInsets.all(30), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("Recorded Sentence", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), const SizedBox(height: 20), Text(_recordedWords.join(" "), style: const TextStyle(fontSize: 22, color: Colors.blueGrey)), const SizedBox(height: 40), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ElevatedButton.icon(onPressed: () => _tts.speak(_recordedWords.join(" ")), icon: const Icon(Icons.volume_up), label: const Text("Replay")), ElevatedButton(onPressed: () => setState(() => _isShowingSummary = false), child: const Text("Close"))])]));
  Widget _buildSuccessTick() => Center(child: Container(padding: const EdgeInsets.all(30), decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 80)));
}
