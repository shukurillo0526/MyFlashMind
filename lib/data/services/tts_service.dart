import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

/// Service for Text-to-Speech functionality
/// Supports Korean and English with automatic language detection
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _enabled = false;

  /// Whether TTS is currently enabled
  bool get isEnabled => _enabled;

  /// Enable or disable TTS
  set isEnabled(bool value) => _enabled = value;

  /// Initialize the TTS engine
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      _initialized = true;
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  /// Speak the given text
  /// Automatically detects language (Korean or English)
  Future<void> speak(String text, {String? language}) async {
    if (!_enabled) return;
    if (!_initialized) await init();

    try {
      final lang = language ?? _detectLanguage(text);
      await _tts.setLanguage(lang);
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  /// Speak Korean text
  Future<void> speakKorean(String text) async {
    await speak(text, language: 'ko-KR');
  }

  /// Speak English text
  Future<void> speakEnglish(String text) async {
    await speak(text, language: 'en-US');
  }

  /// Detect language based on character content
  /// Returns 'ko-KR' for Korean, 'en-US' for English
  String _detectLanguage(String text) {
    // Check for Korean characters (Hangul syllables range)
    final hasKorean = text.runes.any((c) => c >= 0xAC00 && c <= 0xD7A3);
    // Also check for Hangul Jamo
    final hasJamo = text.runes.any((c) => 
      (c >= 0x1100 && c <= 0x11FF) || // Hangul Jamo
      (c >= 0x3130 && c <= 0x318F)    // Hangul Compatibility Jamo
    );
    
    return (hasKorean || hasJamo) ? 'ko-KR' : 'en-US';
  }

  /// Stop any ongoing speech
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }

  /// Dispose of TTS resources
  Future<void> dispose() async {
    await stop();
  }
}
