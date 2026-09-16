import 'dart:io';
import 'dart:async';
import 'dart:convert';
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
  final List<String> _favoriteSentences = [];

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadFavorites();
    _textController.addListener(() {
      setState(() {
        _charCount = _textController.text.length;
      });
    });
  }

  Future<void> _loadFavorites() async {
    try {
      final Directory docsDir = await getApplicationDocumentsDirectory();
      final File file = File('${docsDir.path}/favorites.json');
      if (await file.exists()) {
        final String contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        setState(() {
          _favoriteSentences.clear();
          _favoriteSentences.addAll(jsonList.map((e) => e.toString()));
        });
      }
    } catch (e) {
      debugPrint("Error loading favorites: $e");
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final Directory docsDir = await getApplicationDocumentsDirectory();
      final File file = File('${docsDir.path}/favorites.json');
      await file.writeAsString(jsonEncode(_favoriteSentences));
    } catch (e) {
      debugPrint("Error saving favorites: $e");
    }
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

  void _addFavoriteSentence() {
    final String text = _textController.text.trim();
    if (text.isNotEmpty) {
      if (!_favoriteSentences.contains(text)) {
        setState(() {
          _favoriteSentences.add(text);
        });
        _saveFavorites();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_ts.currentLanguage.value == AppLanguage.bm
                ? "Ditambah ke frasa kegemaran"
                : "Added to favorite phrases"),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_ts.currentLanguage.value == AppLanguage.bm
                ? "Frasa sudah ada dalam kegemaran"
                : "Phrase already in favorites"),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildCircularButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            backgroundColor: color,
            foregroundColor: iconColor,
            elevation: 2,
            minimumSize: const Size(60, 60),
          ),
          child: Icon(icon, size: 26, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E1B4B),
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
          body: SingleChildScrollView(
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
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildCircularButton(
                                    icon: Icons.volume_up_rounded,
                                    label: _ts.translate("speak_button"),
                                    color: const Color(0xFF1E1B4B),
                                    iconColor: Colors.white,
                                    onPressed: _speak,
                                  ),
                                ),
                                Expanded(
                                  child: _buildCircularButton(
                                    icon: Icons.add_rounded,
                                    label: _ts.currentLanguage.value == AppLanguage.bm ? "Tambah" : "Add",
                                    color: const Color(0xFF10B981),
                                    iconColor: Colors.white,
                                    onPressed: _addFavoriteSentence,
                                  ),
                                ),
                                Expanded(
                                  child: _buildCircularButton(
                                    icon: Icons.ios_share_rounded,
                                    label: _ts.translate("export_share"),
                                    color: const Color(0xFF6366F1),
                                    iconColor: Colors.white,
                                    onPressed: _showShareOptions,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _ts.currentLanguage.value == AppLanguage.bm ? "Frasa Kegemaran" : "Favorite Phrases",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1B4B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_favoriteSentences.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.star_outline_rounded, color: Colors.grey.shade300, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                _ts.currentLanguage.value == AppLanguage.bm
                                    ? "Tiada frasa kegemaran lagi.\nTaip sesuatu di atas dan ketik 'Tambah'."
                                    : "No favorite phrases yet.\nType something above and tap 'Add'.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _favoriteSentences.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final sentence = _favoriteSentences[index];
                            return Card(
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Color(0xFFF1F5F9)),
                              ),
                              child: ListTile(
                                onTap: () {
                                  setState(() {
                                    _textController.text = sentence;
                                    _textController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: sentence.length),
                                    );
                                  });
                                },
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFEEF2FF),
                                  child: Icon(Icons.star_rounded, color: Color(0xFF6366F1), size: 20),
                                ),
                                title: Text(
                                  sentence,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF334155),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _favoriteSentences.removeAt(index);
                                    });
                                    _saveFavorites();
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                    ],
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
