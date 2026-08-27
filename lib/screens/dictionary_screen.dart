import 'package:flutter/material.dart';
import '../data/gesture_data.dart';
import '../logic/translation_service.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredGestures = GestureData.gestures;
  final ts = TranslationService();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterGestures);
  }

  void _filterGestures() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredGestures = GestureData.gestures.where((gesture) {
        final name = gesture['name'].toString().toLowerCase();
        final descBm = gesture['description_bm'].toString().toLowerCase();
        final descEn = gesture['description_en'].toString().toLowerCase();
        return name.contains(query) || descBm.contains(query) || descEn.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          ts.translate("dictionary_title"),
          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6366F1), letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.language, color: Color(0xFF6366F1)),
            onPressed: () {
              setState(() {
                ts.toggleLanguage();
              });
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: ts.currentLanguage.value == AppLanguage.bm ? "Cari isyarat..." : "Search gestures...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
            child: Text(
              ts.translate("dictionary_header"),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1B4B),
              ),
            ),
          ),
          Expanded(
            child: _filteredGestures.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.8,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                    ),
                    itemCount: _filteredGestures.length,
                    itemBuilder: (context, index) {
                      final gesture = _filteredGestures[index];
                      return _buildGestureCard(context, gesture);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            ts.currentLanguage.value == AppLanguage.bm ? "Tiada isyarat ditemui" : "No gestures found",
            style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildGestureCard(BuildContext context, Map<String, dynamic> gesture) {
    final List<String> images = List<String>.from(gesture['images']);
    final String firstImage = images.isNotEmpty ? images.first : "";

    return GestureDetector(
      onTap: () => _showGestureDetail(context, gesture),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: firstImage.isNotEmpty
                    ? Hero(
                        tag: 'gesture_${gesture['name']}',
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            firstImage,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.image_not_supported, color: Colors.grey),
                          ),
                        ),
                      )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Text(
                gesture['name']!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6366F1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGestureDetail(BuildContext context, Map<String, dynamic> gesture) {
    final List<String> images = List<String>.from(gesture['images']);
    final bool isBm = ts.currentLanguage.value == AppLanguage.bm;
    final String description = isBm ? gesture['description_bm'] : gesture['description_en'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          gesture['name']!,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1B4B),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 280,
                    child: images.length > 1
                        ? _buildImageSlider(images, gesture['name'])
                        : _buildImageFrame(images.first, gesture['name']),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 20, color: Color(0xFF6366F1)),
                            const SizedBox(width: 8),
                            Text(
                              ts.translate("how_to"),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6366F1),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 17,
                            color: Color(0xFF334155),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1B4B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
                      ),
                      child: Text(ts.translate("ok")),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSlider(List<String> images, String name) {
    return PageView.builder(
      itemCount: images.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: _buildImageFrame(images[index], name, isHero: index == 0),
        );
      },
    );
  }

  Widget _buildImageFrame(String imagePath, String name, {bool isHero = true}) {
    Widget image = Padding(
      padding: const EdgeInsets.all(20),
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
    ),);

    if (isHero) {
      image = Hero(tag: 'gesture_$name', child: image);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFEEF2FF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: image,
      ),
    );
  }
}
