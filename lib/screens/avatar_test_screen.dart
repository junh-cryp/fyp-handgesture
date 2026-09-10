import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class AvatarTestScreen extends StatefulWidget {
  const AvatarTestScreen({super.key});

  @override
  State<AvatarTestScreen> createState() => _AvatarTestScreenState();
}

class _AvatarTestScreenState extends State<AvatarTestScreen> {
  String _currentModelPath = 'assets/timmy_final.glb';
  String? _currentAnimation = "IDLE"; 
  double _speed = 1.0;

  final List<Map<String, String>> _availableSigns = [
    {"label": "IDLE (Base)", "animation": "IDLE", "path": "assets/timmy_final.glb"},
    {"label": "BAGUS", "animation": "BAGUS", "path": "assets/timmy_bagus.glb"},
    {"label": "AMAN", "animation": "AMAN", "path": "assets/timmy_aman.glb"},
    {"label": "HAI", "animation": "HAI", "path": "assets/timmy_hai.glb"},
  ];

  void _switchModel(String path, String animationName) {
    setState(() {
      _currentModelPath = path;
      _currentAnimation = animationName;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Loading Lesson: $animationName"),
        duration: const Duration(milliseconds: 1000),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF6366F1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("BIM 3D Lessons", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B))),
        backgroundColor: Colors.white.withOpacity(0.8),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 1. FULL SCREEN 3D VIEW
          Positioned.fill(
            child: ModelViewer(
              key: ValueKey("$_currentModelPath-$_speed-$_currentAnimation"), 
              src: _currentModelPath,
              backgroundColor: const Color(0xFFF8FAFC),
              autoRotate: false,
              cameraControls: true,
              animationName: _currentAnimation,
              autoPlay: true, 
              exposure: 1.5,
              environmentImage: 'neutral',
              relatedJs: """
                var model = document.querySelector('model-viewer');
                model.addEventListener('load', () => {
                  model.timeScale = $_speed;
                });
              """,
            ),
          ),

          // 2. SPEED CONTROLS (Floating HUD)
          Positioned(
            top: 120,
            right: 20,
            child: Column(
              children: [
                _buildSpeedChip(0.5),
                const SizedBox(height: 8),
                _buildSpeedChip(1.0),
                const SizedBox(height: 8),
                _buildSpeedChip(2.0),
              ],
            ),
          ),

          // 3. PULL-UP LESSON BAR (BOTTOM)
          DraggableScrollableSheet(
            initialChildSize: 0.18,
            minChildSize: 0.1,
            maxChildSize: 0.7,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    // Pull Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 18),
                        width: 60,
                        height: 6,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const Text(
                      "Sign Language Lessons",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B)),
                    ),
                    const SizedBox(height: 25),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _availableSigns.length,
                      itemBuilder: (context, index) {
                        final sign = _availableSigns[index];
                        final isSelected = _currentModelPath == sign['path'] && _currentAnimation == sign['animation'];
                        return ElevatedButton(
                          onPressed: () => _switchModel(sign['path']!, sign['animation']!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected ? const Color(0xFF6366F1) : const Color(0xFFF1F5F9),
                            foregroundColor: isSelected ? Colors.white : const Color(0xFF1E1B4B),
                            elevation: isSelected ? 4 : 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              sign['label']!,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedChip(double speedValue) {
    bool isSelected = _speed == speedValue;
    return GestureDetector(
      onTap: () => setState(() => _speed = speedValue),
      child: Container(
        width: 55,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Text(
          "${speedValue}x",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF1E1B4B),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
