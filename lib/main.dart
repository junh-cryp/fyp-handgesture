import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/translate_screen.dart';
import 'screens/speak_screen.dart';
import 'screens/dictionary_screen.dart';
import 'logic/translation_service.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.camera.request();
  _cameras = await availableCameras();
  runApp(const HandGestureApp());
}

class HandGestureApp extends StatelessWidget {
  const HandGestureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hand Gesture FYP',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          surface: const Color(0xFFF3F4FF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F4FF),
      ),
      home: const MainMenu(),
    );
  }
}

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final ts = TranslationService();

    return ValueListenableBuilder<AppLanguage>(
      valueListenable: ts.currentLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: ChoiceChip(
                  label: Text(lang == AppLanguage.bm ? "BM" : "EN"),
                  selected: true,
                  onSelected: (_) => ts.toggleLanguage(),
                  selectedColor: const Color(0xFF6366F1),
                  labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          extendBodyBehindAppBar: true,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Logo
                  Container(
                    width: 180,
                    height: 180,
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 15,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Titles
                  const Text(
                    "BimTalk",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1B4B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ts.translate("app_subtitle"),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Menu Items
                  _MenuCard(
                    title: "Translate",
                    icon: Image.asset(
                      'assets/translate.png',
                      fit: BoxFit.contain,
                    ),
                    bgColor: const Color(0xFFEEF2FF),
                    onTap: () {
                      _showInstructionDialog(
                        context, 
                        "Translate", 
                        ts.translate("translate_desc"),
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => TranslateScreen(cameras: _cameras)),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _MenuCard(
                    title: "Speak",
                    icon: Image.asset(
                      'assets/speak.png',
                      fit: BoxFit.contain,
                    ),
                    bgColor: const Color(0xFFECFDF5),
                    onTap: () {
                      _showInstructionDialog(
                        context, 
                        "Speak", 
                        ts.translate("speak_desc"),
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SpeakScreen()),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _MenuCard(
                    title: "Dictionary",
                    icon: Image.asset(
                      'assets/dictionary.png',
                      fit: BoxFit.contain,
                    ),
                    bgColor: const Color(0xFFFDF2F8),
                    onTap: () {
                      _showInstructionDialog(
                        context, 
                        "Dictionary", 
                        ts.translate("dictionary_desc"),
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DictionaryScreen()),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showInstructionDialog(BuildContext context, String title, String description, VoidCallback onConfirm) {
    final ts = TranslationService();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
              ),
              const SizedBox(height: 16),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onConfirm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(ts.translate("ok"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final Widget icon;
  final Color bgColor;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: icon,
            ),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1B4B),
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
