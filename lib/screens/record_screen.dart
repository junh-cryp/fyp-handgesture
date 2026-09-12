import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../logic/vision_vm.dart';
import '../widgets/painters.dart';
import '../widgets/selection_card.dart';
import '../logic/translation_service.dart';
import '../data/gesture_data.dart';

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

  void _showSentenceEditor() {
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Current Sentence", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(height: 30),
              Expanded(
                child: _recordedWords.isEmpty
                    ? Center(child: Text("No words added yet", style: TextStyle(color: Colors.grey.shade400, fontSize: 16)))
                    : ListView.builder(
                        itemCount: _recordedWords.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _recordedWords.length) {
                            return _buildInsertPlaceholder(index, setModalState);
                          }
                          return Column(
                            children: [
                              _buildInsertPlaceholder(index, setModalState),
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFF6366F1),
                                      radius: 12,
                                      child: Text("${index + 1}", style: const TextStyle(fontSize: 10, color: Colors.white)),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Text(
                                        _recordedWords[index],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E1B4B)),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.volume_up, color: Color(0xFF6366F1)),
                                      onPressed: () => _tts.speak(_recordedWords[index]),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () {
                                        setState(() => _recordedWords.removeAt(index));
                                        setModalState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _recordedWords.isEmpty
                          ? null
                          : () => _tts.speak(_recordedWords.join(" ")),
                      icon: const Icon(Icons.volume_up),
                      label: const Text("Speak Sentence"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _recordedWords.clear());
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text("Clear All"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _recordedWords.clear());
                    Navigator.pop(context); // Close the bottom sheet
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("END", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1B4B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsertPlaceholder(int index, StateSetter setModalState) {
    return InkWell(
      onTap: () {
        _showManualWordInsertDialog(context, index, setModalState);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 16, color: Colors.grey.shade400),
            const SizedBox(width: 6),
            Text(
              "Insert word here",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualWordInsertDialog(BuildContext context, int index, StateSetter setModalState) {
    String manualWord = "";
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(index == _recordedWords.length ? "Add Word to End" : "Insert Word at Position ${index + 1}"),
        content: TextField(
          autofocus: true,
          onChanged: (v) => manualWord = v,
          decoration: const InputDecoration(hintText: "Enter word..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (manualWord.trim().isNotEmpty) {
                setState(() {
                  _recordedWords.insert(index, manualWord.trim());
                });
                setModalState(() {});
              }
              Navigator.pop(c);
            },
            child: const Text("Insert"),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    double percent = score * 100;
    if (percent > 75) return Colors.green;
    if (percent > 40) return Colors.amber.shade700;
    if (percent < 40) return Colors.red;
    return Colors.blueGrey;
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });
    _showSentenceEditor();
  }

  void _showAddWordDialog() {
    String newWord = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Manual Word"),
        content: TextField(
          autofocus: true,
          onChanged: (value) => newWord = value,
          decoration: const InputDecoration(hintText: "Enter word here..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (newWord.trim().isNotEmpty) {
                setState(() => _recordedWords.add(newWord.trim()));
              }
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
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
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_isRecording)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Colors.white, size: 30),
                  onPressed: _showSentenceEditor,
                ),
                if (_recordedWords.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${_recordedWords.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
        ],
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

          if (!_isRecording) _buildStartUI(),

          if (_isRecording && _vm.isAwaitingSelection) _buildCandidateGrid(),

          if (_isRecording) ...[
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
          Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF1E1B4B), borderRadius: BorderRadius.circular(20)), child: const Text("Confirm Sign", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(height: 15),
          Container(
            height: 220,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.0, crossAxisSpacing: 15, mainAxisSpacing: 15),
              itemCount: _vm.candidates.length,
              itemBuilder: (c, i) {
                final cand = _vm.candidates[i];
                return SelectionCard(
                  word: cand.word,
                  matchScore: cand.matchScore,
                  onTap: () => _onWordConfirmed(cand.word),
                  scoreColor: _getScoreColor(cand.matchScore),
                  imagePath: GestureData.getImagePath(cand.word),
                );
              },
            ),
          ),
          IconButton(icon: const Icon(Icons.cancel, color: Colors.white, size: 40), onPressed: () => _vm.resetDetection()),
        ],
      ),
    );
  }

  Widget _buildStartUI() => Stack(
        children: [
          Positioned(
            top: 120,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Text(
                "Start New Recording",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF1E1B4B),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _recordedWords.clear();
                      _isRecording = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(60),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 90,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
  Widget _buildSuccessTick() => Center(child: Container(padding: const EdgeInsets.all(30), decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 80)));
}
