import 'package:hive/hive.dart';
import 'flashcard.dart';

part 'flashcard_set.g.dart';

/// A collection of flashcards with metadata and progress tracking
@HiveType(typeId: 1)
class FlashcardSet extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  List<Flashcard> cards;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  @HiveField(6)
  String? folderId;

  @HiveField(7)
  String? termLanguage;

  @HiveField(8)
  String? definitionLanguage;

  @HiveField(9)
  int cardsKnown;

  @HiveField(10)
  int cardsLearning;

  @HiveField(11)
  DateTime? lastStudied;

  FlashcardSet({
    required this.id,
    required this.title,
    this.description,
    required this.cards,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.termLanguage,
    this.definitionLanguage,
    this.cardsKnown = 0,
    this.cardsLearning = 0,
    this.lastStudied,
  });

  /// Number of terms in the set
  int get termCount => cards.length;

  /// Calculate overall progress percentage
  double get progressPercentage {
    if (cards.isEmpty) return 0;
    return (cardsKnown / cards.length) * 100;
  }

  /// Get counts for progress bar segments
  Map<String, int> get progressSegments {
    final notStudied = cards.length - cardsKnown - cardsLearning;
    return {
      'known': cardsKnown,
      'learning': cardsLearning,
      'new': notStudied.clamp(0, cards.length),
    };
  }

  /// Update progress based on current card states
  void updateProgress() {
    cardsKnown = cards.where((c) => c.isMastered).length;
    cardsLearning = cards.where((c) => !c.isMastered && (c.timesCorrect + c.timesIncorrect) > 0).length;
  }

  /// Create a copy with updated fields
  FlashcardSet copyWith({
    String? id,
    String? title,
    String? description,
    List<Flashcard>? cards,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? folderId,
    String? termLanguage,
    String? definitionLanguage,
    int? cardsKnown,
    int? cardsLearning,
    DateTime? lastStudied,
  }) {
    return FlashcardSet(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      cards: cards ?? this.cards,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderId: folderId ?? this.folderId,
      termLanguage: termLanguage ?? this.termLanguage,
      definitionLanguage: definitionLanguage ?? this.definitionLanguage,
      cardsKnown: cardsKnown ?? this.cardsKnown,
      cardsLearning: cardsLearning ?? this.cardsLearning,
      lastStudied: lastStudied ?? this.lastStudied,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'cards': cards.map((c) => c.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'folderId': folderId,
      'termLanguage': termLanguage,
      'definitionLanguage': definitionLanguage,
      'cardsKnown': cardsKnown,
      'cardsLearning': cardsLearning,
      'lastStudied': lastStudied?.toIso8601String(),
    };
  }

  /// Create from JSON map
  factory FlashcardSet.fromJson(Map<String, dynamic> json) {
    return FlashcardSet(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      cards: (json['cards'] as List<dynamic>)
          .map((c) => Flashcard.fromJson(c as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      folderId: json['folderId'] as String?,
      termLanguage: json['termLanguage'] as String?,
      definitionLanguage: json['definitionLanguage'] as String?,
      cardsKnown: json['cardsKnown'] as int? ?? 0,
      cardsLearning: json['cardsLearning'] as int? ?? 0,
      lastStudied: json['lastStudied'] != null
          ? DateTime.parse(json['lastStudied'] as String)
          : null,
    );
  }
}
