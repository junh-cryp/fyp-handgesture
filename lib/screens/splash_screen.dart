import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  final Future<void> Function() onInitializationComplete;
  final VoidCallback onFinish;

  const SplashScreen({
    super.key,
    required this.onInitializationComplete,
    required this.onFinish,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _initialize();
  }

  Future<void> _initialize() async {
    final stopwatch = Stopwatch()..start();
    
    // Start initialization logic (camera, permissions, etc.)
    await widget.onInitializationComplete();
    
    // Ensure splash shows for exactly 3 seconds
    final int remainingMs = 3000 - stopwatch.elapsedMilliseconds;
    if (remainingMs > 0) {
      await Future.delayed(Duration(milliseconds: remainingMs));
    }
    
    if (mounted) {
      widget.onFinish();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep professional background
      body: Stack(
        children: [
          // Background Gradient Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // 1. 3D Perspective Rotation
                // Create a "tilting" effect that looks 3D
                final double rotateX = math.sin(_controller.value * 2 * math.pi) * 0.2;
                final double rotateY = math.cos(_controller.value * 2 * math.pi) * 0.3;
                
                // 2. Floating/Bobbing
                final double dy = math.sin(_controller.value * 2 * math.pi) * 15;
                
                // 3. OK Sign "Pulse" logic
                // We'll simulate the "OK" gesture feel with a scale pulse
                final double scale = 1.0 + (math.sin(_controller.value * 4 * math.pi).abs() * 0.08);

                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Perspective
                    ..translate(0.0, dy, 0.0)
                    ..rotateX(rotateX)
                    ..rotateY(rotateY),
                  alignment: Alignment.center,
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 50,
                      spreadRadius: 5,
                    )
                  ],
                ),
                padding: const EdgeInsets.all(30),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          
          // Loading Text / Status
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  "BimTalk",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: const LinearProgressIndicator(
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      minHeight: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Initializing AI Systems...",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
