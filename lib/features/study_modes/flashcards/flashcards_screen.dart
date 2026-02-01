import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/flashcard.dart';
import '../../../data/models/flashcard_set.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/supabase_service.dart';
import '../../../data/services/spaced_repetition_service.dart';
import '../../../data/services/tts_service.dart';

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
  double _dragOffset = 0; // Track horizontal drag for visual feedback

  // Tracking
  List<Flashcard> _knowCards = [];
  List<Flashcard> _learningCards = [];

  // Settings
  bool _shuffleCards = false;
  bool _trackProgress = true;
  bool _studyStarredOnly = false;
  bool _showFrontFirst = true;  // true = Term (Korean), false = Definition
  bool _textToSpeech = false;

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
        _applySettings();
      });
    }
  }

  void _applySettings() {
    if (_set == null) return;
    
    var cards = List<Flashcard>.from(_set!.cards);
    
    // Apply starred filter
    if (_studyStarredOnly) {
      cards = cards.where((c) => c.isStarred).toList();
    }
    
    // If no cards after filter, show all
    if (cards.isEmpty) {
      cards = List<Flashcard>.from(_set!.cards);
    }
    
    // Apply shuffle
    if (_shuffleCards) {
      cards.shuffle();
    }
    
    _cards = cards;
    _currentIndex = 0;
    _showingFront = true;
    _isComplete = false;
    _knowCards = [];
    _learningCards = [];
  }

  void _flipCard() {
    setState(() {
      _showingFront = !_showingFront;
    });
    
    // Speak the content using TTS if enabled
    if (_textToSpeech && _currentIndex < _cards.length) {
      final card = _cards[_currentIndex];
      final text = _showingFront 
          ? (_showFrontFirst ? card.term : card.definition)
          : (_showFrontFirst ? card.definition : card.term);
      context.read<TtsService>().speak(text);
    }
  }

  void _markKnow() {
    _rateCard(4); // Good
  }

  void _markLearning() {
    _rateCard(0); // Again
  }

  /// Rate the current card with SM-2 quality (0-5)
  void _rateCard(int quality) {
    if (_currentIndex >= _cards.length) return;
    
    final card = _cards[_currentIndex];
    final sr = SpacedRepetitionService();
    
    // Calculate new review parameters
    final result = sr.calculateNextReview(
      currentEF: card.easinessFactor,
      currentInterval: card.interval,
      currentRepetitions: card.repetitions,
      quality: quality,
    );
    
    // Update card with new values
    card.easinessFactor = result.ef;
    card.interval = result.interval;
    card.repetitions = result.repetitions;
    card.nextReviewDate = result.nextReview;
    card.lastStudied = DateTime.now();
    
    // Track for summary
    if (quality >= 3) {
      card.timesCorrect++;
      _knowCards.add(card);
    } else {
      card.timesIncorrect++;
      _learningCards.add(card);
    }
    
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
    
    _set!.lastStudied = DateTime.now();
    _set!.updateProgress();
    
    // Save locally
    await context.read<StorageService>().saveSet(_set!);
    // Sync to cloud
    await context.read<SupabaseService>().saveSet(_set!);
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

  void _showOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Options',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // General section header
                Text('General', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                )),
                const SizedBox(height: 12),
                
                // Shuffle cards
                _buildOptionRow(
                  'Shuffle cards',
                  _shuffleCards,
                  (v) {
                    setState(() => _shuffleCards = v);
                    _applySettings();
                  },
                ),
                const SizedBox(height: 16),
                
                // Text to speech
                _buildOptionRow(
                  'Text to speech',
                  _textToSpeech,
                  (v) {
                    setState(() => _textToSpeech = v);
                    context.read<TtsService>().isEnabled = v;
                  },
                ),
                const SizedBox(height: 16),
                
                // Sort into piles (Track progress)
                _buildOptionRow(
                  'Sort into piles',
                  _trackProgress,
                  (v) => setState(() => _trackProgress = v),
                  description: 'Sort your flashcards to keep track of what you know and what you\'re still learning.',
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                
                // Card orientation section
                Text('Card orientation', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                )),
                const SizedBox(height: 8),
                Text('Front', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                // Segmented button for Korean/English
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Korean')),
                    ButtonSegment(value: false, label: Text('English')),
                  ],
                  selected: {_showFrontFirst},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() => _showFrontFirst = newSelection.first);
                    Navigator.pop(context);
                    _showOptionsModal();
                  },
                ),
                const SizedBox(height: 24),
                
                // Study only starred terms
                _buildOptionRow(
                  'Study only starred terms',
                  _studyStarredOnly,
                  (v) {
                    setState(() => _studyStarredOnly = v);
                    _applySettings();
                  },
                ),
                const SizedBox(height: 24),
                const Divider(),
                
                // Keyboard shortcuts section
                ExpansionTile(
                  title: const Text('Keyboard shortcuts'),
                  children: [
                    _buildShortcutRow('Know', '→'),
                    _buildShortcutRow('Still learning', '←'),
                    _buildShortcutRow('Flip', 'Space'),
                    _buildShortcutRow('Star', 'S'),
                    _buildShortcutRow('Shuffle', 'H'),
                    _buildShortcutRow('Audio', 'A'),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                
                // Restart Flashcards
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _restart();
                    },
                    child: const Text('Restart Flashcards', style: TextStyle(color: AppColors.error)),
                  ),
                ),
                
                // Restart Flashcards
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _restart();
                  },
                  child: const Text('Restart Flashcards', style: TextStyle(color: AppColors.error)),
                ),
                
                // Privacy Policy
                TextButton(
                  onPressed: () {},
                  child: const Text('Privacy Policy', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionRow(String label, bool value, Function(bool) onChanged, {String? description}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Switch(
              value: value,
              onChanged: (v) {
                onChanged(v);
                Navigator.pop(context);
                _showOptionsModal();
              },
            ),
          ],
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(right: 60),
            child: Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _buildShortcutRow(String label, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.textSecondary),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(key, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
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
            onPressed: _showOptionsModal,
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

    return GestureDetector(
      onTap: _flipCard,
      onHorizontalDragUpdate: (details) {
        setState(() => _dragOffset += details.delta.dx);
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset > 100) {
          _rateCard(4); // Good - swipe right
        } else if (_dragOffset < -100) {
          _rateCard(0); // Again - swipe left
        }
        setState(() => _dragOffset = 0);
      },
      onHorizontalDragCancel: () {
        setState(() => _dragOffset = 0);
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

          // Card with 3D flip and swipe indicator
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                children: [
                  // Swipe indicator overlays
                  if (_dragOffset != 0)
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: (_dragOffset.abs() / 150).clamp(0, 0.6),
                        duration: const Duration(milliseconds: 50),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _dragOffset > 0 
                                ? AppColors.success.withOpacity(0.2)
                                : AppColors.error.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Icon(
                              _dragOffset > 0 ? Icons.check_circle : Icons.refresh,
                              size: 64,
                              color: _dragOffset > 0 ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Card content with drag offset
                  Transform.translate(
                    offset: Offset(_dragOffset * 0.3, 0),
                    child: Transform.rotate(
                      angle: _dragOffset * 0.001,
                      child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: _showingFront ? 1.0 : 0.0,
                  end: _showingFront ? 0.0 : 1.0,
                ),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  final angle = value * math.pi;
                  final isFrontVisible = value < 0.5;
                  final displayText = isFrontVisible ? card.term : card.definition;
                  
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _showingFront
                              ? [AppColors.cardBackground, AppColors.surface]
                              : [AppColors.primary.withOpacity(0.15), AppColors.cardBackground],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Side indicator - wrapped in counter-rotation transform
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(value >= 0.5 ? math.pi : 0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isFrontVisible 
                                        ? AppColors.primary.withOpacity(0.2)
                                        : AppColors.secondary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isFrontVisible ? 'TERM' : 'DEFINITION',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isFrontVisible ? AppColors.primary : AppColors.secondary,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(value >= 0.5 ? math.pi : 0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isFrontVisible && card.imageUrl != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            card.imageUrl!,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.broken_image, size: 48, color: AppColors.textSecondary),
                                          ),
                                        ),
                                      ),
                                    Text(
                                      displayText,
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Tap to flip hint - wrapped in counter-rotation transform
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(value >= 0.5 ? math.pi : 0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.touch_app, size: 16, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tap to flip',
                                    style: Theme.of(context).textTheme.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
                    ),
                  ),
                ],
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

          // SM-2 Rating Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Row(
              children: [
                _buildRatingButton(
                  label: 'Again',
                  color: AppColors.error,
                  quality: 0,
                  interval: '<1m',
                ),
                const SizedBox(width: 8),
                _buildRatingButton(
                  label: 'Hard',
                  color: AppColors.warning,
                  quality: 3,
                  interval: '',
                ),
                const SizedBox(width: 8),
                _buildRatingButton(
                  label: 'Good',
                  color: AppColors.success,
                  quality: 4,
                  interval: '',
                ),
                const SizedBox(width: 8),
                _buildRatingButton(
                  label: 'Easy',
                  color: AppColors.primary,
                  quality: 5,
                  interval: '',
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

  Widget _buildRatingButton({
    required String label,
    required Color color,
    required int quality,
    required String interval,
  }) {
    return Expanded(
      child: ElevatedButton(
        onPressed: () => _rateCard(quality),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: color.withOpacity(0.5)),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }
}
