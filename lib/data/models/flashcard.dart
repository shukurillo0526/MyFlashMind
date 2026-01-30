import 'package:hive/hive.dart';

part 'flashcard.g.dart';

/// A single flashcard with term and definition
@HiveType(typeId: 0)
class Flashcard extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String term;

  @HiveField(2)
  String definition;

  @HiveField(3)
  String? termLanguage;

  @HiveField(4)
  String? definitionLanguage;

  @HiveField(5)
  String? imageUrl;

  @HiveField(6)
  int timesCorrect;

  @HiveField(7)
  int timesIncorrect;

  @HiveField(8)
  DateTime? lastStudied;

  @HiveField(9)
  bool isStarred;

  // SM-2 Spaced Repetition Fields
  @HiveField(10)
  double easinessFactor;

  @HiveField(11)
  int interval; // in days

  @HiveField(12)
  int repetitions;

  @HiveField(13)
  DateTime? nextReviewDate;

  Flashcard({
    required this.id,
    required this.term,
    required this.definition,
    this.termLanguage,
    this.definitionLanguage,
    this.imageUrl,
    this.timesCorrect = 0,
    this.timesIncorrect = 0,
    this.lastStudied,
    this.isStarred = false,
    this.easinessFactor = 2.5,
    this.interval = 1,
    this.repetitions = 0,
    this.nextReviewDate,
  });

  /// Calculate accuracy percentage
  double get accuracy {
    final total = timesCorrect + timesIncorrect;
    if (total == 0) return 0;
    return (timesCorrect / total) * 100;
  }

  /// Check if card is mastered (>= 80% accuracy with at least 3 attempts)
  bool get isMastered {
    final total = timesCorrect + timesIncorrect;
    return total >= 3 && accuracy >= 80;
  }

  /// Check if card is due for review (SM-2)
  bool get isDue {
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate!) || 
           DateTime.now().day == nextReviewDate!.day;
  }

  Flashcard copyWith({
    String? id,
    String? term,
    String? definition,
    String? termLanguage,
    String? definitionLanguage,
    String? imageUrl,
    int? timesCorrect,
    int? timesIncorrect,
    DateTime? lastStudied,
    bool? isStarred,
    double? easinessFactor,
    int? interval,
    int? repetitions,
    DateTime? nextReviewDate,
  }) {
    return Flashcard(
      id: id ?? this.id,
      term: term ?? this.term,
      definition: definition ?? this.definition,
      termLanguage: termLanguage ?? this.termLanguage,
      definitionLanguage: definitionLanguage ?? this.definitionLanguage,
      imageUrl: imageUrl ?? this.imageUrl,
      timesCorrect: timesCorrect ?? this.timesCorrect,
      timesIncorrect: timesIncorrect ?? this.timesIncorrect,
      lastStudied: lastStudied ?? this.lastStudied,
      isStarred: isStarred ?? this.isStarred,
      easinessFactor: easinessFactor ?? this.easinessFactor,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'term': term,
      'definition': definition,
      'termLanguage': termLanguage,
      'definitionLanguage': definitionLanguage,
      'imageUrl': imageUrl,
      'timesCorrect': timesCorrect,
      'timesIncorrect': timesIncorrect,
      'lastStudied': lastStudied?.toIso8601String(),
      'isStarred': isStarred,
      'easinessFactor': easinessFactor,
      'interval': interval,
      'repetitions': repetitions,
      'nextReviewDate': nextReviewDate?.toIso8601String(),
    };
  }

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] as String,
      term: json['term'] as String,
      definition: json['definition'] as String,
      termLanguage: json['termLanguage'] as String?,
      definitionLanguage: json['definitionLanguage'] as String?,
      imageUrl: json['imageUrl'] as String?,
      timesCorrect: json['timesCorrect'] as int? ?? 0,
      timesIncorrect: json['timesIncorrect'] as int? ?? 0,
      lastStudied: json['lastStudied'] != null
          ? DateTime.parse(json['lastStudied'] as String)
          : null,
      isStarred: json['isStarred'] as bool? ?? false,
      easinessFactor: (json['easinessFactor'] as num?)?.toDouble() ?? 2.5,
      interval: json['interval'] as int? ?? 1,
      repetitions: json['repetitions'] as int? ?? 0,
      nextReviewDate: json['nextReviewDate'] != null
          ? DateTime.parse(json['nextReviewDate'] as String)
          : null,
    );
  }
}
