/// Service for SM-2 Spaced Repetition Algorithm
/// 
/// Quality ratings:
/// 0 - Complete blackout, no recall
/// 1 - Incorrect, but upon seeing answer, recognized
/// 2 - Incorrect, but seemed easy to recall
/// 3 - Correct with serious difficulty
/// 4 - Correct with some hesitation
/// 5 - Perfect response, no hesitation

class SpacedRepetitionService {
  /// Calculate next review parameters based on SM-2 algorithm
  /// 
  /// [currentEF] - Current easiness factor (minimum 1.3)
  /// [currentInterval] - Current interval in days
  /// [currentRepetitions] - Number of successful repetitions
  /// [quality] - Quality of response (0-5)
  /// 
  /// Returns a record with new values
  ({double ef, int interval, int repetitions, DateTime nextReview}) calculateNextReview({
    required double currentEF,
    required int currentInterval,
    required int currentRepetitions,
    required int quality,
  }) {
    // Clamp quality to valid range
    quality = quality.clamp(0, 5);
    
    double newEF = currentEF;
    int newInterval = currentInterval;
    int newRepetitions = currentRepetitions;
    
    if (quality < 3) {
      // Failed recall - reset repetitions
      newRepetitions = 0;
      newInterval = 1;
    } else {
      // Successful recall
      if (currentRepetitions == 0) {
        newInterval = 1;
      } else if (currentRepetitions == 1) {
        newInterval = 6;
      } else {
        newInterval = (currentInterval * currentEF).round();
      }
      newRepetitions = currentRepetitions + 1;
    }
    
    // Update easiness factor
    // EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    newEF = currentEF + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    
    // Ensure EF doesn't go below 1.3
    if (newEF < 1.3) newEF = 1.3;
    
    // Calculate next review date
    final nextReview = DateTime.now().add(Duration(days: newInterval));
    
    return (
      ef: newEF,
      interval: newInterval,
      repetitions: newRepetitions,
      nextReview: nextReview,
    );
  }
  
  /// Get human-readable interval description
  String getIntervalDescription(int days) {
    if (days == 1) return 'Tomorrow';
    if (days < 7) return 'In $days days';
    if (days < 30) return 'In ${(days / 7).round()} weeks';
    if (days < 365) return 'In ${(days / 30).round()} months';
    return 'In ${(days / 365).round()} years';
  }
  
  /// Map simple button choices to quality values
  /// Again = 0, Hard = 3, Good = 4, Easy = 5
  int buttonToQuality(String button) {
    switch (button.toLowerCase()) {
      case 'again':
        return 0;
      case 'hard':
        return 3;
      case 'good':
        return 4;
      case 'easy':
        return 5;
      default:
        return 4;
    }
  }
}
