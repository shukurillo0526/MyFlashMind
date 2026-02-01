import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/flashcard.dart';
import '../../../data/models/flashcard_set.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/supabase_service.dart';
import '../../../data/services/tts_service.dart';

/// Grading modes for answer checking
enum _GradingMode { relaxed, moderate, strict }

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
  bool _currentAnswerWithTerm = false; // Track current question direction

  // Stats
  int _correctCount = 0;
  int _incorrectCount = 0;
  final Random _random = Random();

  // Settings - General
  bool _shuffle = true;
  bool _textToSpeech = false;
  
  // Settings - Prompt with (what shows as the question)
  bool _promptWithKorean = true;  // Term
  bool _promptWithEnglish = true; // Definition
  
  // Settings - Answer with (what you need to provide)
  bool _answerWithKorean = true;  // Term
  bool _answerWithEnglish = true; // Definition
  
  // Settings - Question types
  bool _flashcardMode = false;
  bool _multipleChoice = true;
  bool _written = true;
  
  // Settings - Grading
  _GradingMode _gradingMode = _GradingMode.relaxed;
  bool _retypeCorrectAnswers = false;

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
    
    // Determine question direction based on settings
    // If both prompt options are enabled, randomly choose
    // If only one is enabled, use that direction
    if (_promptWithKorean && _promptWithEnglish) {
      _currentAnswerWithTerm = _random.nextBool();
    } else if (_promptWithKorean) {
      // Prompt is Korean (term), so answer with English (definition)
      _currentAnswerWithTerm = false;
    } else {
      // Prompt is English (definition), so answer with Korean (term)
      _currentAnswerWithTerm = true;
    }
    
    // Randomly choose question type from enabled types
    final availableTypes = <_QuestionType>[];
    if (_multipleChoice) availableTypes.add(_QuestionType.multipleChoice);
    if (_written) availableTypes.add(_QuestionType.written);
    if (_flashcardMode) availableTypes.add(_QuestionType.flashcard);
    
    if (availableTypes.isEmpty) {
      availableTypes.add(_QuestionType.multipleChoice);
    }
    
    _questionType = availableTypes[_random.nextInt(availableTypes.length)];
    
    // Get correct answer based on direction
    final correctAnswer = _currentAnswerWithTerm ? card.term : card.definition;
    
    // Generate multiple choice options
    if (_questionType == _QuestionType.multipleChoice) {
      final otherCards = _set!.cards.where((c) => c.id != card.id).toList()
        ..shuffle();
      
      _choices = [correctAnswer];
      for (int i = 0; i < 3 && i < otherCards.length; i++) {
        // Use same field for wrong answers
        _choices.add(_currentAnswerWithTerm 
            ? otherCards[i].term 
            : otherCards[i].definition);
      }
      _choices.shuffle();
    }
    
    // Speak the prompt if TTS is enabled
    if (_textToSpeech) {
      final prompt = _currentAnswerWithTerm ? card.definition : card.term;
      context.read<TtsService>().speak(prompt);
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
    // Get correct answer based on current direction
    final correctAnswer = _currentAnswerWithTerm ? card.term : card.definition;
    final isCorrect = _isAnswerCorrect(answer, correctAnswer);

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
    final a = answer.toLowerCase().trim();
    final c = correct.toLowerCase().trim();
    
    // Exact match always correct
    if (a == c) return true;
    
    // Apply grading mode tolerance
    switch (_gradingMode) {
      case _GradingMode.strict:
        // Strict: exact match only (after case normalization)
        return false;
        
      case _GradingMode.moderate:
        // Moderate: allow 1 character difference for words > 3 chars
        if (c.length > 3) {
          int diff = _calculateLevenshteinDistance(a, c);
          return diff <= 1;
        }
        return false;
        
      case _GradingMode.relaxed:
        // Relaxed: allow 2 character differences for words > 4 chars
        if (c.length > 4) {
          int diff = _calculateLevenshteinDistance(a, c);
          return diff <= 2;
        }
        return false;
    }
  }
  
  /// Calculate Levenshtein distance between two strings
  int _calculateLevenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    
    List<int> prev = List.generate(b.length + 1, (i) => i);
    List<int> curr = List.filled(b.length + 1, 0);
    
    for (int i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        int cost = a[i] == b[j] ? 0 : 1;
        curr[j + 1] = [
          curr[j] + 1,
          prev[j + 1] + 1,
          prev[j] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
      prev = List.from(curr);
    }
    return curr[b.length];
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

  void _overrideAsCorrect() {
    if (_currentIndex >= _cards.length) return;
    final card = _cards[_currentIndex];
    
    setState(() {
      // Undo incorrect count
      _incorrectCount--;
      card.timesIncorrect--;
      
      // Add correct count
      _correctCount++;
      card.timesCorrect++;
    });
    
    _nextQuestion();
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
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
                
                // General section
                Text('General', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                )),
                const SizedBox(height: 12),
                _buildOptionRow('Shuffle terms', Icons.shuffle, _shuffle, (v) {
                  setState(() => _shuffle = v);
                }),
                _buildOptionRow('Text to speech', Icons.volume_up, _textToSpeech, (v) {
                  setState(() => _textToSpeech = v);
                  context.read<TtsService>().isEnabled = v;
                }),
                
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                
                // Prompt with section
                Text('Prompt with', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                )),
                const SizedBox(height: 8),
                Text('Select what appears as the question', 
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                _buildOptionRow('Korean (Term)', null, _promptWithKorean, (v) {
                  // Ensure at least one is selected
                  if (!v && !_promptWithEnglish) return;
                  setState(() => _promptWithKorean = v);
                }),
                _buildOptionRow('English (Definition)', null, _promptWithEnglish, (v) {
                  if (!v && !_promptWithKorean) return;
                  setState(() => _promptWithEnglish = v);
                }),
                
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                
                // Answer with section
                Text('Answer with', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                )),
                const SizedBox(height: 8),
                Text('Select what you need to provide as the answer', 
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                _buildOptionRow('Korean (Term)', null, _answerWithKorean, (v) {
                  if (!v && !_answerWithEnglish) return;
                  setState(() => _answerWithKorean = v);
                }),
                _buildOptionRow('English (Definition)', null, _answerWithEnglish, (v) {
                  if (!v && !_answerWithKorean) return;
                  setState(() => _answerWithEnglish = v);
                }),
                
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                
                // Question types
                Text('Question types', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                )),
                const SizedBox(height: 12),
                _buildOptionRow('Flashcards', Icons.style, _flashcardMode, (v) {
                  if (!v && !_multipleChoice && !_written) return;
                  setState(() => _flashcardMode = v);
                }),
                _buildOptionRow('Multiple choice', Icons.list, _multipleChoice, (v) {
                  if (!v && !_flashcardMode && !_written) return;
                  setState(() => _multipleChoice = v);
                }),
                _buildOptionRow('Written', Icons.edit, _written, (v) {
                  if (!v && !_flashcardMode && !_multipleChoice) return;
                  setState(() => _written = v);
                }),
                
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                
                // Grading options
                Text('Grading options', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                )),
                const SizedBox(height: 12),
                _buildGradingOption(
                  'Relaxed',
                  'Minor typos (2 chars) allowed for words > 4 chars',
                  _GradingMode.relaxed,
                ),
                _buildGradingOption(
                  'Moderate', 
                  'Max 1 typo allowed for words > 3 chars',
                  _GradingMode.moderate,
                ),
                _buildGradingOption(
                  'Strict',
                  'Exact match only (case insensitive)',
                  _GradingMode.strict,
                ),
                
                const SizedBox(height: 16),
                _buildOptionRow('Retype correct answers', null, _retypeCorrectAnswers, (v) {
                  setState(() => _retypeCorrectAnswers = v);
                }),
                
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                
                // Restart Learn button
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentIndex = 0;
                        _correctCount = 0;
                        _incorrectCount = 0;
                        _isComplete = false;
                      });
                      _generateQuestion();
                    },
                    child: const Text('Restart Learn', style: TextStyle(color: AppColors.error)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildGradingOption(String title, String description, _GradingMode mode) {
    final isSelected = _gradingMode == mode;
    return InkWell(
      onTap: () {
        setState(() => _gradingMode = mode);
        Navigator.pop(context);
        _showOptionsModal();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Radio<_GradingMode>(
              value: mode,
              groupValue: _gradingMode,
              onChanged: (v) {
                if (v != null) {
                  setState(() => _gradingMode = v);
                  Navigator.pop(context);
                  _showOptionsModal();
                }
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  )),
                  Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildOptionRow(String label, IconData? icon, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
          ],
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
          onPressed: () {
            _saveProgress();
            Navigator.pop(context);
          },
        ),
        title: Text('${_currentIndex + 1} / ${_cards.length}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showOptionsModal,
          ),
        ],
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
          // Override button for incorrect answers
          if (!isCorrect)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: _overrideAsCorrect,
                child: const Text(
                  'Override: I was correct',
                  style: TextStyle(color: AppColors.error),
                ),
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
  flashcard,
}
