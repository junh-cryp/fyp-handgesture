import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../logic/translation_service.dart';

class SpeakScreen extends StatefulWidget {
  const SpeakScreen({super.key});

  @override
  State<SpeakScreen> createState() => _SpeakScreenState();
}

class _SpeakScreenState extends State<SpeakScreen> {
  final TextEditingController _textController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  final TranslationService _ts = TranslationService();
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _initTts();
    _textController.addListener(() {
      setState(() {
        _charCount = _textController.text.length;
      });
    });
  }

  void _initTts() async {
    try {
      await _flutterTts.setLanguage("ms-MY");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint("TTS Initialization Error: $e");
    }
  }

  Future<void> _speak() async {
    if (_textController.text.isNotEmpty) {
      await _flutterTts.speak(_textController.text);
    }
  }

  void _shareText() async {
    if (_textController.text.isNotEmpty) {
      await Share.share(_textController.text);
    }
  }

  Future<void> _shareVoice() async {
    if (_textController.text.trim().isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF10B981)),
                const SizedBox(height: 16),
                Text(_ts.translate("synthesizing"), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final String text = _textController.text;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      await _flutterTts.stop();
      await _flutterTts.setLanguage("ms-MY");
      await _flutterTts.setSpeechRate(0.5);

      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = "speech_$timestamp.wav";
      final String fullPath = "${tempDir.path}/$fileName";
      
      final Completer<bool> completer = Completer<bool>();
      _flutterTts.setCompletionHandler(() {
        if (!completer.isCompleted) completer.complete(true);
      });
      _flutterTts.setErrorHandler((msg) {
        if (!completer.isCompleted) completer.complete(false);
      });

      await _flutterTts.synthesizeToFile(text, fullPath, true);

      await completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
        return false;
      });

      final String docsDir = (await getApplicationDocumentsDirectory()).path;
      final List<String> searchPaths = [
        fullPath,
        "${tempDir.path}/$fileName",
        if (Platform.isAndroid) ...[
          "/storage/emulated/0/Android/data/inti.edu.handgesture/files/$fileName",
          "/sdcard/Android/data/inti.edu.handgesture/files/$fileName",
        ],
        "$docsDir/$fileName",
      ];
      
      File? finalAudioFile;
      for (int i = 0; i < 10; i++) {
        for (String path in searchPaths) {
          final File file = File(path);
          if (await file.exists()) {
            if (await file.length() > 500) {
              finalAudioFile = file;
              break;
            }
          }
        }
        if (finalAudioFile != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }

      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);

      if (finalAudioFile != null) {
        await Share.shareXFiles(
          [XFile(finalAudioFile.path, mimeType: 'audio/wav')],
          subject: 'Voice Message',
        );
      } else {
        throw Exception("Synthesis failed to produce a valid file.");
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Audio Export Error"),
          content: SingleChildScrollView(child: Text(e.toString())),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
          ],
        ),
      );
    }
  }

  void _showShareOptions() {
    if (_textController.text.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _ts.translate("share_as"),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _shareText();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4FF),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.text_fields, color: Color(0xFF6366F1), size: 32),
                            const SizedBox(height: 8),
                            Text(_ts.translate("text"), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _shareVoice();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.audiotrack, color: Color(0xFF10B981), size: 32),
                            const SizedBox(height: 8),
                            Text(_ts.translate("voice"), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: _ts.currentLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF3F4FF),
          appBar: AppBar(
            title: Text(_ts.translate("speak_title")),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: const Color(0xFF1E1B4B),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Text Input Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _textController,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText: _ts.translate("speak_hint"),
                            border: InputBorder.none,
                            hintStyle: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        const Divider(),
                        Text(
                          "$_charCount ${_ts.translate("char_count")}",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Speak Button
                  ElevatedButton.icon(
                    onPressed: _speak,
                    icon: const Icon(Icons.volume_up, size: 20),
                    label: Text(_ts.translate("speak_button")),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Export & Share Button
                  OutlinedButton.icon(
                    onPressed: _showShareOptions,
                    icon: const Icon(Icons.share_outlined, size: 20),
                    label: Text(_ts.translate("export_share")),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
