import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../logic/vision_vm.dart';
import '../widgets/painters.dart';
import '../logic/translation_service.dart';

class TranslateScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const TranslateScreen({super.key, required this.cameras});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  late VisionViewModel _vm;
  final FlutterTts _tts = FlutterTts();
  final TranslationService _ts = TranslationService();
  
  final List<String> _history = [];
  bool _showSuccessTick = false;
  String _confirmedWord = "";
  double _confirmedMatchScore = 0.0;

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

  void _onWordConfirmed(String word, double matchScore) {
    _tts.speak(word);
    setState(() {
      _history.insert(0, word);
      _confirmedWord = word;
      _confirmedMatchScore = matchScore;
      _showSuccessTick = true;
    });
    _vm.resetDetection();
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showSuccessTick = false);
    });
  }

  Color _getScoreColor(double score) {
    double percent = score * 100;
    if (percent > 75) return Colors.green;
    if (percent > 40) return Colors.amber.shade700;
    if (percent < 40) return Colors.red;
    return Colors.blueGrey;
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
        title: const Text('BimTalk Live', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.history, color: Colors.white), onPressed: _showHistoryDialog)],
      ),
      body: Stack(
        children: [
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

          if (_vm.isAwaitingSelection) _buildCandidateGrid(),

          if (_showSuccessTick) _buildConfirmedOverlay(),

          _buildDebugOverlay(),
        ],
      ),
    );
  }

  Widget _buildDebugOverlay() {
    return Positioned(
      top: 100,
      left: 10,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _vm.debugInfo.map((info) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Fingers: ${info.fingerStatus}", style: const TextStyle(color: Colors.white, fontSize: 10)),
                    Text("Orient: ${info.orientation}", style: const TextStyle(color: Colors.white, fontSize: 10)),
                    Text("Pos: ${info.tipPos}", style: const TextStyle(color: Colors.white, fontSize: 10)),
                    Text("Dir: ${info.direction}", style: const TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold)),
                    if (info.extra.isNotEmpty) Text(info.extra, style: const TextStyle(color: Colors.cyanAccent, fontSize: 10)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmedOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSuccessTick(),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _confirmedWord,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  "Recognition Score: ${(_confirmedMatchScore * 100).toStringAsFixed(1)}%",
                  style: TextStyle(
                    color: _getScoreColor(_confirmedMatchScore),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "This score shows how closely the detected landmarks\nmatch the predefined gesture rules.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
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
      bottom: 50, left: 0, right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF1E1B4B), borderRadius: BorderRadius.circular(20)),
            child: const Text("Confirm Detected Sign", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 15),
          Container(
            height: 240,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 2.0, crossAxisSpacing: 15, mainAxisSpacing: 15,
              ),
              itemCount: _vm.candidates.length,
              itemBuilder: (context, i) {
                final c = _vm.candidates[i];
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    foregroundColor: const Color(0xFF1E1B4B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 2,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => _onWordConfirmed(c.word, c.matchScore),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            c.word,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Match: ${(c.matchScore * 100).toStringAsFixed(1)}%",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getScoreColor(c.matchScore),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(icon: const Icon(Icons.cancel, color: Colors.white, size: 40), onPressed: () => _vm.resetDetection()),
        ],
      ),
    );
  }

  Widget _buildDetectionStatus() {
    return Align(
      alignment: const Alignment(0, -0.6),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
        child: Text(_vm.currentGesture, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSuccessTick() => Center(child: Container(padding: const EdgeInsets.all(30), decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 80)));

  void _showHistoryDialog() {
    showModalBottomSheet(context: context, builder: (context) => Container(padding: const EdgeInsets.all(20), child: Column(children: [const Text("Translation History", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const Divider(), Expanded(child: ListView.builder(itemCount: _history.length, itemBuilder: (context, i) => ListTile(title: Text(_history[i]), trailing: const Icon(Icons.volume_up), onTap: () => _tts.speak(_history[i]))))])));
  }
}
