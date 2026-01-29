import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/flashcard.dart';
import '../../../data/models/flashcard_set.dart';
import '../../../data/services/storage_service.dart';

/// Flashcard swipe study mode
/// - Tap to flip card
/// - Swipe right = Know
/// - Swipe left = Still learning
class FlashcardsScreen extends StatefulWidget {
  final String setId;

  const FlashcardsScreen({super.key, required this.setId});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  FlashcardSet? _set;
  List<Flashcard> _cards = [];
  int _currentIndex = 0;
  bool _showingFront = true;
  bool _isComplete = false;

  // Tracking
  List<Flashcard> _knowCards = [];
  List<Flashcard> _learningCards = [];

  @override
  void initState() {
    super.initState();
    _loadSet();
  }

  void _loadSet() {
    final set = context.read<StorageService>().getSet(widget.setId);
    if (set != null) {
      setState(() {
        _set = set;
        _cards = List.from(set.cards);
      });
    }
  }

  void _flipCard() {
    setState(() {
      _showingFront = !_showingFront;
    });
  }

  void _markKnow() {
    if (_currentIndex >= _cards.length) return;
    
    final card = _cards[_currentIndex];
    _knowCards.add(card);
    _nextCard();
  }

  void _markLearning() {
    if (_currentIndex >= _cards.length) return;
    
    final card = _cards[_currentIndex];
    _learningCards.add(card);
    _nextCard();
  }

  void _nextCard() {
    setState(() {
      _showingFront = true;
      if (_currentIndex < _cards.length - 1) {
        _currentIndex++;
      } else {
        _isComplete = true;
        _saveProgress();
      }
    });
  }

  void _saveProgress() async {
    if (_set == null) return;
    
    // Update card statistics
    for (final card in _knowCards) {
      card.timesCorrect++;
      card.lastStudied = DateTime.now();
    }
    for (final card in _learningCards) {
      card.timesIncorrect++;
      card.lastStudied = DateTime.now();
    }
    
    _set!.lastStudied = DateTime.now();
    _set!.updateProgress();
    
    await context.read<StorageService>().saveSet(_set!);
  }

  void _restart({bool learnOnly = false}) {
    setState(() {
      _currentIndex = 0;
      _showingFront = true;
      _isComplete = false;
      
      if (learnOnly && _learningCards.isNotEmpty) {
        _cards = List.from(_learningCards);
      } else {
        _cards = List.from(_set!.cards);
      }
      
      _knowCards = [];
      _learningCards = [];
    });
  }

  void _shuffle() {
    setState(() {
      _cards.shuffle();
      _currentIndex = 0;
      _showingFront = true;
      _isComplete = false;
      _knowCards = [];
      _learningCards = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_set == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${_currentIndex + 1} / ${_cards.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            onPressed: _shuffle,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: _isComplete ? _buildCompleteView() : _buildCardView(),
    );
  }

  Widget _buildCardView() {
    if (_cards.isEmpty) {
      return const Center(child: Text('No cards'));
    }

    final card = _cards[_currentIndex];
    final text = _showingFront ? card.term : card.definition;

    return GestureDetector(
      onTap: _flipCard,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! > 200) {
          _markKnow();
        } else if (details.primaryVelocity! < -200) {
          _markLearning();
        }
      },
      child: Column(
        children: [
          // Progress bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentIndex + 1) / _cards.length,
                backgroundColor: AppColors.surface,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 4,
              ),
            ),
          ),

          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey('${card.id}_$_showingFront'),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            text,
                            style: Theme.of(context).textTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Text(
                          'Tap to flip',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Action hints
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Icon(Icons.arrow_back, color: AppColors.warning),
                    const SizedBox(height: 4),
                    Text(
                      'Still learning',
                      style: TextStyle(color: AppColors.warning, fontSize: 12),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.arrow_forward, color: AppColors.success),
                    const SizedBox(height: 4),
                    Text(
                      'Know',
                      style: TextStyle(color: AppColors.success, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Buttons for accessibility
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _markLearning,
                    icon: const Icon(Icons.close),
                    label: const Text('Learning'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _markKnow,
                    icon: const Icon(Icons.check),
                    label: const Text('Know'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteView() {
    final total = _knowCards.length + _learningCards.length;
    final knowPercent = total > 0 ? (_knowCards.length / total * 100).round() : 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Stats circle
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cardBackground,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$knowPercent%',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: AppColors.success,
                          ),
                    ),
                    const Text('Know', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'Nice work!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'You sorted all ${_cards.length} cards',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 16),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatChip(
                  '${_knowCards.length}',
                  'Know',
                  AppColors.success,
                ),
                const SizedBox(width: 16),
                _buildStatChip(
                  '${_learningCards.length}',
                  'Learning',
                  AppColors.warning,
                ),
              ],
            ),

            const SizedBox(height: 48),

            // Action buttons
            if (_learningCards.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _restart(learnOnly: true),
                  child: const Text('Study learning cards'),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _restart(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.surface),
                ),
                child: const Text('Restart all'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
