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
  final ts = TranslationService();
  
  // Only gestures that can be translated
  final List<String> _supportedGestures = [
    "SAYA", "APA KHABAR", "FIKIR", "NAMA", "HAI", "BAGUS", "AMAN", 
    "BERHENTI", "BOLEH", "TIDAK BOLEH", "TIDAK ADA", "BENANG", 
    "MINUM", "BELI", "SANA", "DIAM", "LESEN", "ANDA","BELANJA",
    "APA GUNANYA ?", "OH! BEGITU RUPANYA", "AWAK"

  ];

  List<Map<String, dynamic>> _filteredGestures = [];

  @override
  void initState() {
    super.initState();
    _filteredGestures = GestureData.gestures.where((g) => 
      _supportedGestures.contains(g['name'].toString().toUpperCase())
    ).toList();
    _searchController.addListener(_filterGestures);
  }

  void _filterGestures() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredGestures = GestureData.gestures.where((gesture) {
        final nameBm = gesture['name'].toString().toLowerCase();
        final nameEn = (gesture['name_en'] ?? '').toString().toLowerCase();
        final isSupported = _supportedGestures.contains(gesture['name'].toString().toUpperCase());
        return isSupported && (nameBm.contains(query) || nameEn.contains(query));
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
          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B), letterSpacing: -0.5),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              ts.translate("dictionary_header"),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 5, 20, 0),
            child: Text(
              ts.translate("dictionary_sub"),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          _buildSearchBar(),
          Expanded(
            child: _filteredGestures.isEmpty
                ? _buildEmptyState()
                : _buildGesturesGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: ts.translate("search_gestures"),
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
    );
  }

  Widget _buildGesturesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: _filteredGestures.length,
      itemBuilder: (context, index) {
        final gesture = _filteredGestures[index];
        return _buildGestureTile(gesture);
      },
    );
  }

  Widget _buildGestureTile(Map<String, dynamic> gesture) {
    final bool isBm = ts.currentLanguage.value == AppLanguage.bm;
    final String displayName = isBm ? gesture['name'] : (gesture['name_en'] ?? gesture['name']);

    return GestureDetector(
      onTap: () => _showGestureDetail(context, gesture),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            displayName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
        ),
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
            ts.translate("no_words_found"),
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _showGestureDetail(BuildContext context, Map<String, dynamic> gesture) {
    final List<String> images = List<String>.from(gesture['images']);
    final bool isBm = ts.currentLanguage.value == AppLanguage.bm;
    final String description = isBm ? gesture['description_bm'] : gesture['description_en'];
    final String displayName = isBm ? gesture['name'] : (gesture['name_en'] ?? gesture['name']);

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
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 280,
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20)),
                    child: images.length > 1 ? _buildImageSlider(images) : _buildImageFrame(images.first),
                  ),
                  const SizedBox(height: 25),
                  Text(ts.translate("how_to"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                  const SizedBox(height: 10),
                  Text(description, style: const TextStyle(fontSize: 17, color: Color(0xFF334155), height: 1.5)),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1B4B),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text(ts.translate("ok"), style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSlider(List<String> images) {
    return PageView.builder(
      itemCount: images.length,
      itemBuilder: (context, index) => _buildImageFrame(images[index]),
    );
  }

  Widget _buildImageFrame(String imagePath) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Image.asset(
        imagePath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
      ),
    );
  }
}
