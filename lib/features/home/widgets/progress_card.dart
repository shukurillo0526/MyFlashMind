import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/flashcard_set.dart';

/// Progress card showing flashcard set with multi-segment progress bar
class ProgressCard extends StatelessWidget {
  final FlashcardSet flashcardSet;
  final VoidCallback? onTap;

  const ProgressCard({
    super.key,
    required this.flashcardSet,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final segments = flashcardSet.progressSegments;
    final total = flashcardSet.termCount;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    flashcardSet.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Spacer(),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    // Known (green)
                    if (segments['known']! > 0)
                      Flexible(
                        flex: segments['known']!,
                        child: Container(color: AppColors.progressKnow),
                      ),
                    // Learning (yellow)
                    if (segments['learning']! > 0)
                      Flexible(
                        flex: segments['learning']!,
                        child: Container(color: AppColors.progressLearning),
                      ),
                    // New (orange)
                    if (segments['new']! > 0)
                      Flexible(
                        flex: segments['new']!,
                        child: Container(color: AppColors.progressNew),
                      ),
                    // Empty state
                    if (total == 0)
                      Expanded(
                        child: Container(color: AppColors.surface),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Progress text
            Text(
              '${flashcardSet.cardsKnown}/$total cards sorted',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
