import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/animations.dart';
import '../../data/models/flashcard_set.dart';
import '../../data/services/storage_service.dart';

/// Statistics dashboard showing learning progress and streaks
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _totalCards = 0;
  int _masteredCards = 0;
  int _learningCards = 0;
  int _totalSets = 0;
  int _studyStreak = 0;
  List<FlashcardSet> _recentSets = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    final storage = context.read<StorageService>();
    final sets = storage.getAllSets();
    
    int total = 0;
    int mastered = 0;
    int learning = 0;
    
    for (final set in sets) {
      for (final card in set.cards) {
        total++;
        if (card.isMastered) {
          mastered++;
        } else if (card.timesCorrect > 0 || card.timesIncorrect > 0) {
          learning++;
        }
      }
    }
    
    // Calculate streak (simplified - consecutive days with study activity)
    int streak = _calculateStreak(sets);
    
    setState(() {
      _totalCards = total;
      _masteredCards = mastered;
      _learningCards = learning;
      _totalSets = sets.length;
      _studyStreak = streak;
      _recentSets = sets.take(5).toList();
    });
  }

  int _calculateStreak(List<FlashcardSet> sets) {
    // Get all study dates
    final studyDates = <DateTime>{};
    for (final set in sets) {
      if (set.lastStudied != null) {
        studyDates.add(DateTime(
          set.lastStudied!.year,
          set.lastStudied!.month,
          set.lastStudied!.day,
        ));
      }
    }
    
    if (studyDates.isEmpty) return 0;
    
    // Count consecutive days from today
    int streak = 0;
    DateTime checkDate = DateTime.now();
    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);
    
    while (studyDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final newCards = _totalCards - _masteredCards - _learningCards;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streak banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_fire_department, 
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_studyStreak day streak',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _studyStreak > 0 ? 'Keep it up!' : 'Start studying today!',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Overview stats
            Text('Overview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard('Total Sets', '$_totalSets', Icons.folder)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Total Cards', '$_totalCards', Icons.style)),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Progress breakdown
            Text('Card Progress', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _buildProgressSection(newCards),
            
            const SizedBox(height: 24),
            
            // Recent activity
            if (_recentSets.isNotEmpty) ...[
              Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ..._recentSets.asMap().entries.map((e) => FadeSlideAnimation(
                index: e.key,
                child: _buildRecentSetTile(e.value),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildProgressSection(int newCards) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildProgressRow('Mastered', _masteredCards, AppColors.success),
          const SizedBox(height: 12),
          _buildProgressRow('Learning', _learningCards, AppColors.warning),
          const SizedBox(height: 12),
          _buildProgressRow('New', newCards, AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, int count, Color color) {
    final percent = _totalCards > 0 ? (count / _totalCards) : 0.0;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label),
                  Text('$count (${(percent * 100).toInt()}%)'),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent,
                  backgroundColor: AppColors.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSetTile(FlashcardSet set) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.style, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(set.title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${set.cards.length} cards • ${set.masteryPercentage}% mastered',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
