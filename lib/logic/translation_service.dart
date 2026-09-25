import 'package:flutter/foundation.dart';

enum AppLanguage { bm, en }

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  final ValueNotifier<AppLanguage> currentLanguage = ValueNotifier(AppLanguage.bm);

  void toggleLanguage() {
    currentLanguage.value = currentLanguage.value == AppLanguage.bm ? AppLanguage.en : AppLanguage.bm;
  }

  String translate(String key) {
    bool isBm = currentLanguage.value == AppLanguage.bm;
    return isBm ? _bm[key] ?? key : _en[key] ?? key;
  }

  static const Map<String, String> _bm = {
    "app_subtitle": "Terjemahan bahasa isyarat BIM masa-nyata",
    "translate_title": "Terjemah",
    "translate_desc": "Gunakan kamera anda untuk mengesan dan menterjemah isyarat tangan BIM ke teks dalam masa nyata.",
    "speak_desc": "Tukar teks kepada ucapan. Taip teks anda sendiri atau gunakan frasa yang diterjemah untuk berkomunikasi.",
    "dictionary_desc": "Layari dan pelajari semua isyarat BIM yang disokong dengan penerangan dan panduan visual.",
    "record_title": "Rekod",
    "record_desc": "Rakam ayat penuh melalui bahasa isyarat dan dengarkannya kemudian.",
    "avatar_title": "Avatar 3D",
    "avatar_desc": "Lihat Timmy melakukan isyarat BIM untuk membantu anda belajar dengan lebih baik.",
    "ok": "OK",
    "practice": "Latihan",
    "how_to": "Cara Melakukan:",
    "dictionary_title": "KAMUS ISYARAT",
    "dictionary_header": "Daftar Isyarat Tangan",
    "dictionary_sub": "Pilih isyarat untuk melihat cara melakukan dan penerangannya.",
    "search_gestures": "Cari isyarat...",
    "no_words_found": "Tiada kata ditemui",
    "loading_sys": "Menyediakan sistem...",
    "loading_ai": "Memuatkan AI Tangan...",
    "loading_cam": "Memulakan Kamera...",
    "loading_stream": "Mengaktifkan strim...",
    "loading_wait": "Sila tunggu sebentar, AI sedang disediakan",
    "error_init": "Gagal memulakan",
    "retry": "Cuba Lagi",
    "history": "Sejarah",
    "sentence_builder": "Pembina Ayat",
    "tap_to_build": "Ketik isyarat yang dikesan di bawah untuk membina ayat anda",
    "clear": "PADAM",
    "clear_history": "Padam Sejarah",
    "no_signs": "Tiada isyarat dikesan lagi",
    "speak_sentence": "Sebut Ayat",
    "copied": "Disalin ke papan klip",
    "clear_selection": "Nyahpilih Semua",
    "detected_signs": "Isyarat Dikesan",
    "speak_hint": "Taip mesej anda di sini...",
    "speak_title": "Cakap",
    "speak_button": "Cakap",
    "export_share": "Eksport & Kongsi",
    "share_as": "Kongsi Mesej Sebagai",
    "text": "Teks",
    "voice": "Suara (Audio)",
    "char_count": "aksara",
    "synthesizing": "Menyintesis Audio...",
    "hand_detected": "1 tangan dikesan",
    "hands_detected": "tangan dikesan",
  };

  static const Map<String, String> _en = {
    "app_subtitle": "Real-time BIM sign language translation",
    "translate_title": "Translate",
    "translate_desc": "Use your camera to detect and translate BIM hand gestures to text in real-time.",
    "speak_desc": "Convert text to speech. Type your own text or use translated phrases to communicate.",
    "dictionary_desc": "Browse and learn all supported BIM signs with descriptions and visual guides.",
    "record_title": "Record",
    "record_desc": "Capture full sentences through sign language and listen to them later.",
    "avatar_title": "3D Avatar",
    "avatar_desc": "Watch Timmy perform BIM signs to help you learn better.",
    "ok": "OK",
    "practice": "Practice",
    "how_to": "How to perform:",
    "dictionary_title": "SIGN DICTIONARY",
    "dictionary_header": "Hand Sign List",
    "dictionary_sub": "Select a sign to see how to perform it and its description.",
    "search_gestures": "Search gestures...",
    "no_words_found": "No words found",
    "loading_sys": "Setting up system...",
    "loading_ai": "Loading Hand AI...",
    "loading_cam": "Starting Camera...",
    "loading_stream": "Activating stream...",
    "loading_wait": "Please wait a moment, AI is being prepared",
    "error_init": "Initialization Failed",
    "retry": "Retry",
    "history": "History",
    "sentence_builder": "Sentence Builder",
    "tap_to_build": "Tap detected signs below to build your sentence",
    "clear": "CLEAR",
    "clear_history": "Clear History",
    "no_signs": "No signs detected yet",
    "speak_sentence": "Speak Sentence",
    "copied": "Copied to clipboard",
    "clear_selection": "Deselect All",
    "detected_signs": "Detected Signs",
    "speak_hint": "Type your message here...",
    "speak_title": "Speak",
    "speak_button": "Speak",
    "export_share": "Export & Share",
    "share_as": "Share Message As",
    "text": "Text",
    "voice": "Voice (Audio)",
    "char_count": "characters",
    "synthesizing": "Synthesizing Audio...",
    "hand_detected": "1 hand detected",
    "hands_detected": "hands detected",
  };
}
