import 'package:flutter/material.dart';
import '../data/gesture_data.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  Map<String, String>? selectedGesture;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gesture Dictionary")),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Select a gesture to see the reference picture",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: GestureData.gestures.length,
              itemBuilder: (context, index) {
                final gesture = GestureData.gestures[index];
                return ListTile(
                  title: Text(gesture['name']!),
                  leading: const Icon(Icons.back_hand),
                  onTap: () {
                    setState(() {
                      selectedGesture = gesture;
                    });
                  },
                  selected: selectedGesture == gesture,
                  selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                );
              },
            ),
          ),
          if (selectedGesture != null)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          selectedGesture!['name']!,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.asset(
                                selectedGesture!['image']!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Text(
                                      "Image not found.\nPlease add it to assets.",
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          selectedGesture!['description']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
