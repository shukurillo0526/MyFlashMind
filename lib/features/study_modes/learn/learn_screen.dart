import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/flashcard.dart';
import '../../../data/models/flashcard_set.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/supabase_service.dart';

/// Learn mode with adaptive spaced repetition
/// - Multiple choice questions
/// - Written answer questions
/// - Flashcard recall
class LearnScreen extends StatefulWidget {
  final String setId;

  const LearnScreen({super.key, required this.setId});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  FlashcardSet? _set;
  List<Flashcard> _cards = [];
  int _currentIndex = 0;
  bool _isComplete = false;
  
  // Question state
  _QuestionType _questionType = _QuestionType.multipleChoice;
  List<String> _choices = [];
  String? _selectedAnswer;
  bool _showResult = false;
  String _writtenAnswer = '';
  final TextEditingController _answerController = TextEditingController();

  // Stats
  int _correctCount = 0;
  int _incorrectCount = 0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _loadSet();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _loadSet() {
    final set = context.read<StorageService>().getSet(widget.setId);
    if (set != null) {
      setState(() {
        _set = set;
        // Prioritize cards with lower accuracy
        _cards = List.from(set.cards)
          ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
      });
      _generateQuestion();
    }
  }

  void _generateQuestion() {
    if (_currentIndex >= _cards.length) {
      setState(() => _isComplete = true);
      return;
    }

    final card = _cards[_currentIndex];
    
    // Randomly choose question type
    final types = _QuestionType.values;
    _questionType = types[_random.nextInt(types.length)];
    
    // Generate multiple choice options
    if (_questionType == _QuestionType.multipleChoice) {
      final correctAnswer = card.definition;
      final otherCards = _set!.cards.where((c) => c.id != card.id).toList()
        ..shuffle();
      
      _choices = [correctAnswer];
      for (int i = 0; i < 3 && i < otherCards.length; i++) {
        _choices.add(otherCards[i].definition);
      }
      _choices.shuffle();
    }

    setState(() {
      _selectedAnswer = null;
      _showResult = false;
      _writtenAnswer = '';
      _answerController.clear();
    });
  }

  void _checkAnswer(String answer) {
    final card = _cards[_currentIndex];
    final isCorrect = _isAnswerCorrect(answer, card.definition);

    setState(() {
      _selectedAnswer = answer;
      _showResult = true;
      
      if (isCorrect) {
        _correctCount++;
        card.timesCorrect++;
      } else {
        _incorrectCount++;
        card.timesIncorrect++;
      }
      card.lastStudied = DateTime.now();
    });
  }

  bool _isAnswerCorrect(String answer, String correct) {
    // Relaxed grading - case insensitive, trim whitespace
    final a = answer.toLowerCase().trim();
    final c = correct.toLowerCase().trim();
    
    if (a == c) return true;
    
    // Allow minor typos (1-2 characters difference for longer words)
    if (c.length > 4) {
      int diff = 0;
      for (int i = 0; i < min(a.length, c.length); i++) {
        if (a[i] != c[i]) diff++;
      }
      diff += (a.length - c.length).abs();
      if (diff <= 2) return true;
    }
    
    return false;
  }

  void _nextQuestion() {
    setState(() {
      _currentIndex++;
    });
    _generateQuestion();
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
          onPressed: () {
            _saveProgress();
            Navigator.pop(context);
          },
        ),
        title: Text('${_currentIndex + 1} / ${_cards.length}'),
      ),
      body: _isComplete ? _buildCompleteView() : _buildQuestionView(),
    );
  }

  Widget _buildQuestionView() {
    if (_cards.isEmpty) {
      return const Center(child: Text('No cards'));
    }

    final card = _cards[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _cards.length,
              backgroundColor: AppColors.surface,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 24),

          // Term (question)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  card.term,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _questionType == _QuestionType.written
                      ? 'Type the answer'
                      : 'Select the definition',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Answer area
          Expanded(
            child: _questionType == _QuestionType.written
                ? _buildWrittenAnswer(card)
                : _buildMultipleChoice(card),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleChoice(Flashcard card) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _choices.length,
            itemBuilder: (context, index) {
              final choice = _choices[index];
              final isCorrect = choice == card.definition;
              final isSelected = choice == _selectedAnswer;

              Color? bgColor;
              Color? borderColor;
              
              if (_showResult) {
                if (isCorrect) {
                  bgColor = AppColors.success.withOpacity(0.2);
                  borderColor = AppColors.success;
                } else if (isSelected && !isCorrect) {
                  bgColor = AppColors.error.withOpacity(0.2);
                  borderColor = AppColors.error;
                }
              } else if (isSelected) {
                borderColor = AppColors.primary;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: bgColor ?? AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _showResult ? null : () => _checkAnswer(choice),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: borderColor != null
                            ? Border.all(color: borderColor, width: 2)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(choice),
                          ),
                          if (_showResult && isCorrect)
                            const Icon(Icons.check, color: AppColors.success),
                          if (_showResult && isSelected && !isCorrect)
                            const Icon(Icons.close, color: AppColors.error),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_showResult)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextQuestion,
                child: const Text('Continue'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWrittenAnswer(Flashcard card) {
    final isCorrect = _showResult && _isAnswerCorrect(_writtenAnswer, card.definition);

    return Column(
      children: [
        TextField(
          controller: _answerController,
          enabled: !_showResult,
          onChanged: (value) => _writtenAnswer = value,
          onSubmitted: (_) {
            if (!_showResult && _writtenAnswer.isNotEmpty) {
              _checkAnswer(_writtenAnswer);
            }
          },
          decoration: InputDecoration(
            hintText: 'Type your answer...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _showResult
                    ? (isCorrect ? AppColors.success : AppColors.error)
                    : AppColors.surface,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.surface),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_showResult) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCorrect
                  ? AppColors.success.withOpacity(0.2)
                  : AppColors.error.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      color: isCorrect ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCorrect ? 'Correct!' : 'Incorrect',
                      style: TextStyle(
                        color: isCorrect ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (!isCorrect) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Correct answer: ${card.definition}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextQuestion,
              child: const Text('Continue'),
            ),
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _writtenAnswer.isEmpty
                  ? null
                  : () => _checkAnswer(_writtenAnswer),
              child: const Text('Check'),
            ),
          ),

        const Spacer(),
      ],
    );
  }

  Widget _buildCompleteView() {
    _saveProgress();
    final total = _correctCount + _incorrectCount;
    final accuracy = total > 0 ? (_correctCount / total * 100).round() : 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              accuracy >= 80 ? Icons.emoji_events : Icons.school,
              size: 80,
              color: accuracy >= 80 ? AppColors.accent : AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              accuracy >= 80 ? 'Great job!' : 'Keep practicing!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'You scored $accuracy%',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatChip('$_correctCount', 'Correct', AppColors.success),
                const SizedBox(width: 16),
                _buildStatChip('$_incorrectCount', 'Incorrect', AppColors.error),
              ],
            ),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                    _correctCount = 0;
                    _incorrectCount = 0;
                    _isComplete = false;
                  });
                  _generateQuestion();
                },
                child: const Text('Try again'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                ),
                child: const Text('Done'),
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
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

enum _QuestionType {
  multipleChoice,
  written,
}
