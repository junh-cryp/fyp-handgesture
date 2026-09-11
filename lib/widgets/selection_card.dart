import 'package:flutter/material.dart';

class SelectionCard extends StatelessWidget {
  final String word;
  final double matchScore;
  final VoidCallback onTap;
  final Color scoreColor;
  final String? imagePath;

  const SelectionCard({
    super.key,
    required this.word,
    required this.matchScore,
    required this.onTap,
    required this.scoreColor,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Row(
              children: [
                if (imagePath != null)
                  Container(
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        imagePath!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 20),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          word,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Color(0xFF1E1B4B),
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scoreColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${(matchScore * 100).toStringAsFixed(0)}%",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: scoreColor,
                          ),
                        ),
                      ),
                    ],
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
