import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class SpeakScreen extends StatefulWidget {
  const SpeakScreen({super.key});

  @override
  State<SpeakScreen> createState() => _SpeakScreenState();
}

class _SpeakScreenState extends State<SpeakScreen> {
  final TextEditingController _textController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
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
    // We don't force the engine here to avoid initialization locks
    await _flutterTts.setLanguage("ms-MY");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
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
    if (_textController.text.isEmpty) return;

    try {
      // 1. Force stop and switch to Google Engine (most reliable for file synthesis)
      await _flutterTts.stop();
      if (Platform.isAndroid) {
        await _flutterTts.setEngine("com.google.android.tts");
      }
      await _flutterTts.setLanguage("ms-MY");
      await Future.delayed(const Duration(milliseconds: 300));

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Creating Voice Message..."),
                ],
              ),
            ),
          ),
        ),
      );

      // 2. Setup Paths - CRITICAL FIX FOR ANDROID
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // On Android, provide name WITHOUT extension (it adds .wav automatically)
      // On iOS, provide name WITH .caf extension
      final String fileNameForPlugin = Platform.isAndroid ? "msg_$timestamp" : "msg_$timestamp.caf";
      final String actualFileNameOnDisk = Platform.isAndroid ? "msg_$timestamp.wav" : "msg_$timestamp.caf";
      
      String directoryPath;
      if (Platform.isAndroid) {
        final dir = await getExternalStorageDirectory();
        directoryPath = dir!.path;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        directoryPath = dir.path;
      }
      
      final String filePath = "$directoryPath/$actualFileNameOnDisk";
      final file = File(filePath);

      // 3. Synthesis
      final result = await _flutterTts.synthesizeToFile(_textController.text, fileNameForPlugin);
      
      if (result != 1) {
        throw Exception("TTS engine rejected the request. Try shorter text.");
      }

      // 4. Polling for the file
      bool fileReady = false;
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await file.exists()) {
          int size = await file.length();
          if (size > 100) { // Check for valid file size
            fileReady = true;
            break;
          }
        }
      }

      if (Navigator.canPop(context)) Navigator.pop(context); // Hide loading

      if (fileReady) {
        await Share.shareXFiles(
          [XFile(filePath, mimeType: Platform.isAndroid ? 'audio/wav' : 'audio/x-caf')],
          subject: 'Malay Voice Message',
        );
      } else {
        // Diagnostic info if it still fails
        String info = "Engine: Google\nPath: $filePath\nExists: ${await file.exists()}";
        throw Exception("Timeout. Please ensure 'Speech Services by Google' is your default TTS engine in Phone Settings.\n\n$info");
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Share Error"),
          content: Text(e.toString().replaceAll("Exception:", "")),
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
              const Text(
                "Share Message As",
                style: TextStyle(
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
                        child: const Column(
                          children: [
                            Icon(Icons.text_fields, color: Color(0xFF6366F1), size: 32),
                            SizedBox(height: 8),
                            Text("Text", style: TextStyle(fontWeight: FontWeight.bold)),
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
                        child: const Column(
                          children: [
                            Icon(Icons.audiotrack, color: Color(0xFF10B981), size: 32),
                            SizedBox(height: 8),
                            Text("Voice (Audio)", style: TextStyle(fontWeight: FontWeight.bold)),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4FF),
      appBar: AppBar(
        title: const Text("Speak"),
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
                      decoration: const InputDecoration(
                        hintText: "Type your message here or paste translated text...",
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const Divider(),
                    Text(
                      "$_charCount characters",
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
                label: const Text("Speak"),
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
                label: const Text("Export & Share"),
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
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
