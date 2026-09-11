import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/translate_screen.dart';
import 'screens/speak_screen.dart';
import 'screens/record_screen.dart';
import 'screens/dictionary_screen.dart';
import 'screens/avatar_test_screen.dart' hide Expanded;
import 'screens/splash_screen.dart';
import 'logic/translation_service.dart';

List<CameraDescription> _cameras = [];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HandGestureApp());
}

class HandGestureApp extends StatefulWidget {
  const HandGestureApp({super.key});

  @override
  State<HandGestureApp> createState() => _HandGestureAppState();
}

class _HandGestureAppState extends State<HandGestureApp> {
  bool _isInitialized = false;

  Future<void> _initAppLogic() async {
    await Permission.camera.request();
    _cameras = await availableCameras();
  }

  void _onSplashFinished() {
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BimTalk',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          primary: const Color(0xFF6366F1),
          surface: Colors.white,
        ),
      ),
      home: _isInitialized 
          ? const MainMenu() 
          : SplashScreen(
              onInitializationComplete: _initAppLogic,
              onFinish: _onSplashFinished,
            ),
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
          backgroundColor: const Color(0xFFF5F5DC), // Professional Light Beige
          body: Stack(
            children: [
              // Subtle background texture or depth
              Positioned(
                top: -80,
                left: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              
              SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      floating: true,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      actions: [
                        Padding(
                          padding: const EdgeInsets.only(right: 20.0),
                          child: TextButton.icon(
                            onPressed: () => ts.toggleLanguage(),
                            icon: const Icon(Icons.language, size: 20, color: Color(0xFF6366F1)),
                            label: Text(
                              lang == AppLanguage.bm ? "BM" : "EN",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1B4B),
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            Center(
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(25.0),
                                  child: Image.asset(
                                    'assets/logo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            const Text(
                              "BimTalk",
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E1B4B),
                                letterSpacing: -1.5,
                              ),
                            ),
                            Text(
                              ts.translate("app_subtitle"),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.blueGrey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 40),
                            
                            _ModernMenuCard(
                              title: ts.translate("translate_title"),
                              icon: 'assets/translate.png',
                              themeColor: const Color(0xFF6366F1),
                              onTap: () => _showInstructionDialog(
                                context, 
                                ts.translate("translate_title"), 
                                ts.translate("translate_desc"),
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => TranslateScreen(cameras: _cameras)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                            _ModernMenuCard(
                              title: ts.translate("speak_title"),
                              icon: 'assets/speak.png',
                              themeColor: const Color(0xFF10B981),
                              onTap: () => _showInstructionDialog(
                                context, 
                                ts.translate("speak_title"),
                                ts.translate("speak_desc"),
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SpeakScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                            _ModernMenuCard(
                              title: "Record ",
                              icon: 'assets/record.png',
                              themeColor: const Color(0xFF6366F1),
                              onTap: () => _showInstructionDialog(
                                context, 
                                "Record ",
                                "Capture full sentences through sign language and listen to them later.",
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => RecordScreen(cameras: _cameras)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                            _ModernMenuCard(
                              title: ts.translate("dictionary_title"),
                              icon: 'assets/dictionary.png',
                              themeColor: const Color(0xFFF43F5E),
                              onTap: () => _showInstructionDialog(
                                context, 
                                ts.translate("dictionary_title"), 
                                ts.translate("dictionary_desc"),
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const DictionaryScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(height: 25),
                            _ModernMenuCard(
                              title: ts.translate("avatar_title"),
                              icon: 'assets/avatar.png', // Reusing logo for now, or use a custom one
                              themeColor: const Color(0xFF8B5CF6),
                              onTap: () => _showInstructionDialog(
                                context,
                                ts.translate("avatar_title"),
                                ts.translate("avatar_desc"),
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AvatarTestScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(height: 50),
                          ],
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

  void _showInstructionDialog(BuildContext context, String title, String description, VoidCallback onConfirm) {
    final ts = TranslationService();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B)),
              ),
              content: Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.blueGrey.shade700, height: 1.5),
              ),
              actions: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1B4B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      ts.translate("ok"),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModernMenuCard extends StatelessWidget {
  final String title;
  final String icon;
  final Color themeColor;
  final VoidCallback onTap;

  const _ModernMenuCard({
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        // 3D Shadow Stack
        boxShadow: [
          // 1. The "Base" floor shadow (very soft)
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
          // 2. The "Physical Edge" (creates the 3D thickness look)
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 0,
            offset: const Offset(0, 6),
          ),
          // 3. The "Light highlight" on the very top edge
          const BoxShadow(
            color: Colors.white,
            blurRadius: 2,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 0.5),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(
                children: [
                  // 3D Styled Icon Container
                  Container(
                    width: 70,
                    height: 70,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Image.asset(icon, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E1B4B),
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  // Chevron Button
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Icon(Icons.arrow_forward_ios_rounded, color: themeColor, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
