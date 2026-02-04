
import 'package:flutter/foundation.dart';
import '../models/flashcard.dart';

class SpacedRepetitionService {
  // Quality ratings:
  // 0: Complete blackout (Incorrect)
  // 1: Incorrect, but familiar
  // 2: Incorrect, but seeded easy
  // 3: Correct, but difficult
  // 4: Correct, average effort
  // 5: Correct, perfect recall

  // For simplified mapping:
  // Incorrect -> 0
  // Familiar -> 3
  // Mastered (Round 2 passing) -> 5

  void processResult(Flashcard card, int quality) {
    if (quality < 3) {
      // Incorrect / Reset
      card.repetitions = 0;
      card.interval = 1; // Reset to 1 day
      // Optionally keep existing EF or reset it? SM-2 keeps it.
    } else {
      // Correct
      if (card.repetitions == 0) {
        card.interval = 1;
      } else if (card.repetitions == 1) {
        card.interval = 6;
      } else {
        card.interval = (card.interval * card.easinessFactor).round();
      }
      card.repetitions++;
    }

    // Update Easiness Factor (EF)
    // EF' = EF + (0.1 - (5-q) * (0.08 + (5-q) * 0.02))
    // q = quality
    double newEf = card.easinessFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    
    // EF cannot go below 1.3
    if (newEf < 1.3) newEf = 1.3;
    
    card.easinessFactor = newEf;

    // Calculate Next Review Date
    card.nextReviewDate = DateTime.now().add(Duration(days: card.interval));
  }
}
