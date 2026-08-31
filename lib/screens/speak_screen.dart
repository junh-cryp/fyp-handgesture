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
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 3),
              const SizedBox(height: 20),
              Text(
                _ts.translate("synthesizing"),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Audio Export Error", style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
              Text(
                _ts.translate("share_as"),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B4B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  _ShareOption(
                    title: _ts.translate("text"),
                    icon: Icons.text_fields_rounded,
                    color: const Color(0xFF6366F1),
                    onTap: () {
                      Navigator.pop(context);
                      _shareText();
                    },
                  ),
                  const SizedBox(width: 20),
                  _ShareOption(
                    title: _ts.translate("voice"),
                    icon: Icons.graphic_eq_rounded,
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(context);
                      _shareVoice();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(
              _ts.translate("speak_title"),
              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF10B981), letterSpacing: -0.5),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _textController,
                              maxLines: 8,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Color(0xFF334155),
                                height: 1.5,
                              ),
                              decoration: InputDecoration(
                                hintText: _ts.translate("speak_hint"),
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.blueGrey.shade200),
                              ),
                            ),
                            const Divider(height: 40, color: Color(0xFFF1F5F9)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "$_charCount ${_ts.translate("char_count")}",
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade300,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_textController.text.isNotEmpty)
                                  IconButton(
                                    onPressed: () => _textController.clear(),
                                    icon: const Icon(Icons.clear_all_rounded, color: Colors.redAccent),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _speak,
                        icon: const Icon(Icons.volume_up_rounded, size: 24),
                        label: Text(
                          _ts.translate("speak_button"),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1B4B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: OutlinedButton.icon(
                        onPressed: _showShareOptions,
                        icon: const Icon(Icons.ios_share_rounded, size: 22),
                        label: Text(
                          _ts.translate("export_share"),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6366F1),
                          side: const BorderSide(color: Color(0xFFEEF2FF), width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          backgroundColor: const Color(0xFFEEF2FF).withOpacity(0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

class _ShareOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ShareOption({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.1), width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 36),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
