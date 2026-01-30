import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/flashcard_set.dart';

/// Service for importing and exporting flashcard sets
class ImportExportService {
  
  /// Export a set to JSON string
  String exportSetToJson(FlashcardSet set) {
    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'set': set.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
  
  /// Export multiple sets to JSON string
  String exportSetsToJson(List<FlashcardSet> sets) {
    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'sets': sets.map((s) => s.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }
  
  /// Import a set from JSON string
  /// Returns null if parsing fails
  FlashcardSet? importSetFromJson(String jsonString) {
    try {
      final data = json.decode(jsonString) as Map<String, dynamic>;
      
      // Handle single set export
      if (data.containsKey('set')) {
        return FlashcardSet.fromJson(data['set'] as Map<String, dynamic>);
      }
      
      // Handle raw set JSON
      if (data.containsKey('id') && data.containsKey('title')) {
        return FlashcardSet.fromJson(data);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Import multiple sets from JSON string
  List<FlashcardSet>? importSetsFromJson(String jsonString) {
    try {
      final data = json.decode(jsonString) as Map<String, dynamic>;
      
      if (data.containsKey('sets')) {
        final setsJson = data['sets'] as List<dynamic>;
        return setsJson
            .map((s) => FlashcardSet.fromJson(s as Map<String, dynamic>))
            .toList();
      }
      
      // Try single set
      final single = importSetFromJson(jsonString);
      if (single != null) return [single];
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Copy JSON to clipboard
  Future<void> copyToClipboard(String json) async {
    await Clipboard.setData(ClipboardData(text: json));
  }
  
  /// Get JSON from clipboard
  Future<String?> getFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
  
  /// Parse CSV format (simple: term,definition per line)
  List<Map<String, String>>? parseCSV(String csv) {
    try {
      final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final cards = <Map<String, String>>[];
      
      for (final line in lines) {
        // Try tab-separated first (Quizlet export)
        var parts = line.split('\t');
        if (parts.length < 2) {
          // Try comma-separated
          parts = line.split(',');
        }
        
        if (parts.length >= 2) {
          cards.add({
            'term': parts[0].trim(),
            'definition': parts[1].trim(),
          });
        }
      }
      
      return cards.isEmpty ? null : cards;
    } catch (e) {
      return null;
    }
  }
}
