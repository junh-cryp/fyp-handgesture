import 'package:flutter/material.dart';
import '../data/gesture_data.dart';

class DictionaryScreen extends StatelessWidget {
  const DictionaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Kamus Isyarat",
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
            child: Text(
              "Daftar Isyarat Tangan",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1B4B),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Pilih isyarat untuk melihat cara melakukan dan penerangannya.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: GestureData.gestures.length,
              itemBuilder: (context, index) {
                final gesture = GestureData.gestures[index];
                return GestureDetector(
                  onTap: () => _showGestureDetail(context, gesture),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.back_hand_rounded,
                            color: Color(0xFF6366F1),
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          gesture['name']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1B4B),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showGestureDetail(BuildContext context, Map<String, dynamic> gesture) {
    final List<String> images = List<String>.from(gesture['images']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              gesture['name']!,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1B4B),
              ),
            ),
            const SizedBox(height: 25),
            Expanded(
              child: images.length > 1
                  ? _buildImageSlider(images)
                  : _buildImageFrame(images.first),
            ),
            const SizedBox(height: 25),
            const Text(
              "Cara Melakukan:",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              gesture['description']!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFF334155),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSlider(List<String> images) {
    return PageView.builder(
      itemCount: images.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: _buildImageFrame(images[index]),
        );
      },
    );
  }

  Widget _buildImageFrame(String imagePath) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported_outlined, size: 50, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    "Gambar belum tersedia",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
