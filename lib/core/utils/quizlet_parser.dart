import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import '../../data/models/flashcard.dart';
import '../../data/models/flashcard_set.dart';

/// Utility class for parsing Quizlet share links and text
class QuizletParser {
  QuizletParser._();

  /// Import flashcards from a Quizlet URL
  /// 
  /// Note: This works with public sets only. 
  /// Uses web scraping which may break if Quizlet changes their HTML structure.
  static Future<FlashcardSet?> importFromUrl(String url) async {
    try {
      // Validate URL format
      if (!url.contains('quizlet.com')) {
        return null;
      }

      // Extract set ID from URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      // Typical format: quizlet.com/123456789/set-title-flash-cards
      String? setId;
      String title = 'Imported Set';
      
      for (int i = 0; i < pathSegments.length; i++) {
        if (RegExp(r'^\d+$').hasMatch(pathSegments[i])) {
          setId = pathSegments[i];
          if (i + 1 < pathSegments.length) {
            title = pathSegments[i + 1]
                .replaceAll('-flash-cards', '')
                .replaceAll('-', ' ')
                .split(' ')
                .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
                .join(' ');
          }
          break;
        }
      }

      if (setId == null) {
        return null;
      }

      // Fetch the page
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      // Parse HTML
      final document = html_parser.parse(response.body);
      
      // Look for flashcard data in the page
      // Quizlet typically stores data in JSON format in script tags
      final scripts = document.querySelectorAll('script');
      
      List<Flashcard> cards = [];
      
      // Try to find terms in the HTML structure
      // Look for common patterns in Quizlet's HTML
      final termElements = document.querySelectorAll('[class*="TermText"]');
      
      for (int i = 0; i < termElements.length; i += 2) {
        if (i + 1 < termElements.length) {
          final term = termElements[i].text.trim();
          final definition = termElements[i + 1].text.trim();
          
          if (term.isNotEmpty && definition.isNotEmpty) {
            cards.add(Flashcard(
              id: const Uuid().v4(),
              term: term,
              definition: definition,
            ));
          }
        }
      }

      // Alternative: Look for SetPage data
      if (cards.isEmpty) {
        for (final script in scripts) {
          final content = script.text;
          if (content.contains('window.Quizlet') || content.contains('termIdToTermsMap')) {
            // Try to extract term pairs from JSON-like content
            final termRegex = RegExp(r'"word"\s*:\s*"([^"]+)".*?"definition"\s*:\s*"([^"]+)"');
            final matches = termRegex.allMatches(content);
            
            for (final match in matches) {
              final term = _unescapeString(match.group(1) ?? '');
              final definition = _unescapeString(match.group(2) ?? '');
              
              if (term.isNotEmpty && definition.isNotEmpty) {
                cards.add(Flashcard(
                  id: const Uuid().v4(),
                  term: term,
                  definition: definition,
                ));
              }
            }
          }
        }
      }

      if (cards.isEmpty) {
        return null;
      }

      final now = DateTime.now();
      return FlashcardSet(
        id: const Uuid().v4(),
        title: title,
        description: 'Imported from Quizlet',
        cards: cards,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      debugPrint('Error importing from Quizlet: $e');
      return null;
    }
  }

  /// Parse flashcards from pasted text
  /// Supports formats:
  /// - Alternating lines: term on one line, definition on next line
  /// - term - definition (hyphen separated)
  /// - term \t definition (tab separated)
  /// - term : definition (colon separated)
  static FlashcardSet? parseFromText(String text, {String? title}) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    
    if (lines.isEmpty) return null;

    final cards = <Flashcard>[];
    
    // First, try to detect if it's alternating lines format
    // Check if lines don't contain separators like -, :, or tab
    bool hasNoSeparators = true;
    for (final line in lines) {
      if (line.contains('\t') || line.contains(' - ') || line.contains(': ')) {
        hasNoSeparators = false;
        break;
      }
    }
    
    // If no separators and even number of lines, treat as alternating format
    if (hasNoSeparators && lines.length >= 2) {
      for (int i = 0; i < lines.length - 1; i += 2) {
        final term = lines[i].trim();
        final definition = lines[i + 1].trim();
        
        if (term.isNotEmpty && definition.isNotEmpty) {
          cards.add(Flashcard(
            id: const Uuid().v4(),
            term: term,
            definition: definition,
          ));
        }
      }
    } else {
      // Try separator-based parsing
      for (final line in lines) {
        String? term;
        String? definition;
        
        // Try different separators
        if (line.contains('\t')) {
          final parts = line.split('\t');
          if (parts.length >= 2) {
            term = parts[0].trim();
            definition = parts.sublist(1).join(' ').trim();
          }
        } else if (line.contains(' - ')) {
          final idx = line.indexOf(' - ');
          term = line.substring(0, idx).trim();
          definition = line.substring(idx + 3).trim();
        } else if (line.contains(': ')) {
          final idx = line.indexOf(': ');
          term = line.substring(0, idx).trim();
          definition = line.substring(idx + 2).trim();
        } else if (line.contains(':')) {
          final idx = line.indexOf(':');
          term = line.substring(0, idx).trim();
          definition = line.substring(idx + 1).trim();
        }
        
        if (term != null && term.isNotEmpty && definition != null && definition.isNotEmpty) {
          cards.add(Flashcard(
            id: const Uuid().v4(),
            term: term,
            definition: definition,
          ));
        }
      }
    }

    if (cards.isEmpty) return null;

    final now = DateTime.now();
    return FlashcardSet(
      id: const Uuid().v4(),
      title: title ?? 'Imported Set (${now.toString().substring(0, 10)})',
      description: 'Imported from pasted text',
      cards: cards,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Unescape common string escape sequences
  static String _unescapeString(String s) {
    return s
        .replaceAll(r'\"', '"')
        .replaceAll(r"\'", "'")
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\\', r'\');
  }
}
