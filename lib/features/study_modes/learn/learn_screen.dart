import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/flashcard.dart';
import '../../../data/models/flashcard_set.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/supabase_service.dart';
import '../../../data/services/tts_service.dart';
import '../../../data/services/spaced_repetition_service.dart';

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
  // Round-Based State
  Map<String, int> _cardMastery = {}; // 0: New, 1: Familiar, 2: Mastered
  Map<String, bool> _cardDirections = {}; // Persistent direction per card for the session
  
  List<Flashcard> _roundCards = []; // Cards available for this round
  List<Flashcard> _batchQueue = []; // Active queue for current batch (max 7)
  Flashcard? _currentCard;
  
  int _currentBatchIndex = 0; // For progress bar in batch (optional)
  int _currentRoundTarget = 1; // 1: Familiar, 2: Mastered
  bool _isRoundComplete = false;
  bool _isSessionComplete = false;
  
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

  // Settings - General
  bool _shuffle = true;
  bool _textToSpeech = false;
  
  // Settings - Answer with
  _AnswerMode _answerMode = _AnswerMode.both;
  
  // Settings - Question types
  bool _flashcardMode = false;
  bool _multipleChoice = true;
  bool _written = true;
  
  // Flashcard specific state
  bool _flashcardRevealed = false;
  
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
        // Initialize Mastery to 0 (New) for all cards
        // In a real app, we would load existing mastery from detailed progress
        for (var c in _set!.cards) {
          _cardMastery[c.id] = 0; 
        }
        _initializeCardDirections();
        _startRound(1); // Round 1 Goal: Reach Familair
      });
    }
  }
  
  void _initializeCardDirections() {
    if (_set == null) return;
    _cardDirections.clear();
    
    // Balanced Shuffle for 'Both'
    if (_answerMode == _AnswerMode.both && _set!.cards.length > 1) {
      int count = _set!.cards.length;
      int half = (count / 2).ceil();
      List<bool> dirs = [...List.filled(half, true), ...List.filled(count - half, false)]..shuffle();
      for (int i = 0; i < count; i++) {
        _cardDirections[_set!.cards[i].id] = dirs[i];
      }
    } else {
      // Fixed direction
      bool useTerm = _answerMode == _AnswerMode.korean;
      for (final card in _set!.cards) {
        _cardDirections[card.id] = useTerm;
      }
    }
  }

  bool _getUseTerm(String cardId) {
    return _cardDirections[cardId] ?? (_answerMode == _AnswerMode.korean);
  }


  void _startRound(int targetLevel) {
    if (_set == null) return;
    setState(() {
      _currentRoundTarget = targetLevel;
      // Cards eligible for this round: Mastery < Target
      _roundCards = _set!.cards.where((c) => (_cardMastery[c.id] ?? 0) < targetLevel).toList();
      if (_shuffle) _roundCards.shuffle();
      _isRoundComplete = false;
    });
    
    if (_roundCards.isEmpty) {
      if (targetLevel == 1) {
        // Round 1 Done, Start Round 2 (Familiar -> Mastered)
        _startRound(2);
      } else {
        // All rounds done
        setState(() => _isSessionComplete = true);
      }
      return;
    }
    
    _fillBatch();
  }
  
  void _fillBatch() {
    if (_roundCards.isEmpty && _batchQueue.isEmpty) {
      // Round Finished (Pool exhausted & Batch cleared)
      // Check if any cards need another pass in this same target level?
      // In this logic, failed cards are re-queued in batch, so batch never clears until they promote.
      // So if both empty, we are truly done with this Target Level.
      _startRound(_currentRoundTarget + 1);
      return;
    }

    if (_batchQueue.isEmpty) {
      // Fill batch from pool (Max 7)
      int takeCount = min(7, _roundCards.length);
      for (int i = 0; i < takeCount; i++) {
        _batchQueue.add(_roundCards.removeAt(0));
      }
    }
    
    _generateQuestion();
  }

  void _generateQuestion() {
    if (_batchQueue.isEmpty) {
      _fillBatch();
      return;
    }
    
    // Get next card
    _currentCard = _batchQueue.first;
    final card = _currentCard!;
    
    // Determine direction
    bool useTerm = _cardDirections[card.id] ?? (_answerMode == _AnswerMode.korean);
    
    // Determine type (Adaptive or Random)
    final availableTypes = <_QuestionType>[];
    if (_flashcardMode) availableTypes.add(_QuestionType.flashcard);
    if (_multipleChoice) availableTypes.add(_QuestionType.multipleChoice);
    if (_written) availableTypes.add(_QuestionType.written);
    if (availableTypes.isEmpty) availableTypes.add(_QuestionType.multipleChoice);
    
    _questionType = availableTypes[_random.nextInt(availableTypes.length)];
    
    // Generate Choices if MC
    if (_questionType == _QuestionType.multipleChoice) {
      final correctAnswer = useTerm ? card.term : card.definition;
      final otherCards = _set!.cards.where((c) => c.id != card.id).toList()..shuffle();
      
      _choices = [correctAnswer];
      for (int i = 0; i < 3 && i < otherCards.length; i++) {
        _choices.add(useTerm ? otherCards[i].term : otherCards[i].definition);
      }
      _choices.shuffle();
    }
    
    // TTS
    if (_textToSpeech) {
      // Prompt is opposite
      final prompt = useTerm ? card.definition : card.term;
      context.read<TtsService>().speak(prompt);
    }
    
    setState(() {
      _selectedAnswer = null;
      _showResult = false;
      _writtenAnswer = '';
      _answerController.clear();
      _flashcardRevealed = false;
    });
  }

  void _checkAnswer(String answer) {
    if (_currentCard == null) return;
    

    bool useTerm = _getUseTerm(_currentCard!.id);
    final correctAnswer = useTerm ? _currentCard!.term : _currentCard!.definition;
    
    bool isCorrect = _isAnswerCorrect(answer, correctAnswer);
    
    setState(() {
      _selectedAnswer = answer;
      _showResult = true;
      
      if (isCorrect) {
        _processCorrectAnswer();
      } else {
        _processIncorrectAnswer();
      }
      
      _currentCard!.lastStudied = DateTime.now();
      _saveProgress(); // Async save (or batch save later)
    });
  }
  
  void _processCorrectAnswer() {
    _correctCount++;
    _currentCard!.timesCorrect++;
    
    // Upgrade Mastery
    int current = _cardMastery[_currentCard!.id] ?? 0;
    int next = current + 1;
    _cardMastery[_currentCard!.id] = next;
    
    if (next >= _currentRoundTarget) {
      // Promoted! Leave batch.
      _batchQueue.removeAt(0);
      
      // If mastered (Level 2), apply Spaced Repetition Logic (Long Term)
      if (next == 2) {
         final scheduler = SpacedRepetitionService();
         scheduler.processResult(_currentCard!, 5); // 5 = Perfect recall (Mastered)
      }
    } else {
      // Not yet at target (e.g. 0->1 but target 2). 
      // Re-queue to end of batch to practice again?
      // Or consider it 'passed' for this micro-loop?
      // Quizlet usually does: 2 correct answers to master.
      // Let's simplified: If we promoted (0->1), we keep it in batch?
      // No, let's remove it and let it come back in Round 2.
      // Logic: Round 1 goal is Level 1. Round 2 goal is Level 2.
      // So if next >= Target, remove.
      // If Target is 2, and we go 0->1.
      // We are NOT at Target. So we keep it?
      // If we keep it, user answers "New" card correct, becomes "Familiar".
      // Then immediately asked again to become "Mastered"?
      // Quizlet does spacing. 
      // For now: "Promote and Remove". 
      // Wait, if I remove 0->1 in Round 2 (Target 2), it's gone from batch.
      // Then it's gone from Round 2 pool.
      // So it never reaches Level 2?
      // FIX: 
      // Case Round 2 (Target 2). Card is Level 1.
      // Correct -> Level 2. >= Target. Remove. Correct.
      // Case Round 2. Card is Level 0 (was reset).
      // Correct -> Level 1. < Target.
      // Must stay in batch to reach Level 2.
      // So: If < Target, rotate to end.
       _batchQueue.add(_batchQueue.removeAt(0));
    }
  }
  
  void _processIncorrectAnswer() {
    _incorrectCount++;
    _currentCard!.timesIncorrect++;
    
    // Reset Mastery
    _cardMastery[_currentCard!.id] = 0;
    
    // Rotate to end of batch (Must clear before batch finishes)
    _batchQueue.add(_batchQueue.removeAt(0));
  }
  
  void _saveProgress() async {
    if (_set == null) return;
    context.read<StorageService>().saveSet(_set!);
  }
  
  void _handleNext() {
    // Called after "Continue" (if we add one) or auto logic
    // Currently UI shows result then next question?
    // We usually need a "Continue" button or delay.
    // Assuming UI handles trigger.
     _generateQuestion();
  }

  bool _isAnswerCorrect(String answer, String correct) {
    if (answer.isEmpty) return false;
    final a = answer.toLowerCase().trim();
    
    // Split correct answer by commonly used delimiters (semicolon, slash, comma)
    // Quizlet supports these for alternative answers
    final correctSegments = correct.split(RegExp(r'[;,\/]'));
    
    for (var segment in correctSegments) {
      if (_checkSingleAnswer(a, segment)) return true;
    }
    return false;
  }
  
  bool _checkSingleAnswer(String a, String correct) {
    final c = correct.toLowerCase().trim();
    
    // 1. Exact match (case-insensitive)
    if (a == c) return true;

    // 2. Normalized match (remove optional content in parentheses)
    final aNorm = _normalizeText(a);
    final cNorm = _normalizeText(c);
    
    if (aNorm == cNorm) return true;
    
    // Apply grading mode tolerance on NORMALIZED text
    switch (_gradingMode) {
      case _GradingMode.strict:
        return false;
        
      case _GradingMode.moderate:
        // Moderate: allow 1 character difference for words > 3 chars
        if (cNorm.length > 3) {
          int diff = _calculateLevenshteinDistance(aNorm, cNorm);
          return diff <= 1;
        }
        return false;
        
      case _GradingMode.relaxed:
        // Relaxed: allow 2 character differences for words > 4 chars
        if (cNorm.length > 4) {
          int diff = _calculateLevenshteinDistance(aNorm, cNorm);
          return diff <= 2;
        }
        return false;
    }
  }

  String _normalizeText(String text) {
    // Remove content in parentheses, e.g., "Answer (Optional)" -> "Answer"
    // Also removes extra spaces
    var normalized = text.toLowerCase().trim();
    normalized = normalized.replaceAll(RegExp(r'\s*\(.*?\)'), '');
    return normalized.trim();
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
                
                // Answer with section
                Text('Answer with', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                )),
                const SizedBox(height: 8),
                Text('Select what you need to provide as the answer (Prompt will be the opposite)', 
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                
                DropdownButtonFormField<_AnswerMode>(
                  value: _answerMode,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: _AnswerMode.korean, 
                      child: Text('Korean (Term)'),
                    ),
                    DropdownMenuItem(
                      value: _AnswerMode.english, 
                      child: Text('English (Definition)'),
                    ),
                    DropdownMenuItem(
                      value: _AnswerMode.both, 
                      child: Text('Both (Mixed)'),
                    ),
                  ],
                  onChanged: (v) {
                    if(v != null) {
                      setState(() => _answerMode = v);
                      _initializeCardDirections();
                      Navigator.pop(context);
                      _showOptionsModal();
                    }
                  }
                ),
                
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
                        _currentBatchIndex = 0;
                        _correctCount = 0;
                        _incorrectCount = 0;
                        _isSessionComplete = false;
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
        // Learn Progress
        title: Column(
          children: [
            Text(
              'Round $_currentRoundTarget',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_set != null && _cardMastery.isNotEmpty)
             Text(
                '${_batchQueue.length} in batch',
                 style: Theme.of(context).textTheme.labelSmall,
             ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showOptionsModal,
          ),
        ],
      ),
      body: _isSessionComplete ? _buildCompleteView() : _buildQuestionView(),
      bottomNavigationBar: _isSessionComplete ? null : _buildBottomProgress(),
    );
  }
  
  Widget _buildBottomProgress() {
    int mastered = _cardMastery.values.where((v) => v == 2).length;
    int familiar = _cardMastery.values.where((v) => v == 1).length;
    int newItems = _cardMastery.values.where((v) => v == 0).length;
    int total = _set!.cards.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('New', newItems, total, AppColors.textSecondary),
          _buildStatItem('Familiar', familiar, total, Colors.orange),
          _buildStatItem('Mastered', mastered, total, AppColors.success),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, int value, int total, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }

  Widget _buildQuestionView() {
    if (_currentCard == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final card = _currentCard!;
    
    // Choose View based on Type
    if (_questionType == _QuestionType.flashcard) {
      return _buildFlashcardQuestion(card);
    }
    
    // Prompt depending on direction
    bool useTerm = _getUseTerm(card.id);
    final promptText = useTerm ? card.definition : card.term;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Question Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    promptText,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _questionType == _QuestionType.written
                        ? 'Type the answer'
                        : 'Select the definition',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
  
            // Answer area
            _questionType == _QuestionType.written
                  ? _buildWrittenAnswer(card)
                  : _buildMultipleChoice(card),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFlashcardQuestion(Flashcard card) {
    bool useTerm = _getUseTerm(card.id);
    final promptText = useTerm ? card.definition : card.term; // Prompt
    final answerText = useTerm ? card.term : card.definition; // Correct Answer
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                 if (!_flashcardRevealed) {
                   setState(() => _flashcardRevealed = true);
                   if (_textToSpeech) {
                     context.read<TtsService>().speak(answerText);
                   }
                 }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            promptText,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          if (_flashcardRevealed) ...[
                            const SizedBox(height: 32),
                            const Divider(),
                            const SizedBox(height: 32),
                            Text(
                              answerText,
                               textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else ...[
                             const SizedBox(height: 48),
                             Text(
                                'Tap to reveal answer',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                             ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Manual TTS Button
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.volume_up_outlined),
                        onPressed: () {
                          final text = _flashcardRevealed ? answerText : promptText;
                          context.read<TtsService>().speak(text, force: true);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Buttons
          SizedBox(
            height: 60,
            child: _flashcardRevealed
              ? Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          foregroundColor: AppColors.error,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        // Handle result using logic methods directly
                        onPressed: () {
                          _processIncorrectAnswer();
                          _generateQuestion(); // Immediate advance
                        },
                        child: const Text('Study again'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                           padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          _processCorrectAnswer();
                          _generateQuestion(); // Immediate advance
                        },
                        child: const Text('Got it'),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMultipleChoice(Flashcard card) {
    if (_showResult) {
      bool useTerm = _getUseTerm(card.id);
      final correctAnswer = useTerm ? card.term : card.definition;
      final isCorrect = _isAnswerCorrect(_selectedAnswer ?? '', correctAnswer);
      
      return Column(
        children: [
          // Feedback container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCorrect ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCorrect ? AppColors.success : AppColors.error,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      color: isCorrect ? AppColors.success : AppColors.error,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isCorrect ? 'Nicely done!' : 'Study this one!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isCorrect ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
                if (!isCorrect) ...[
                  const SizedBox(height: 12),
                  const Text('Correct answer:', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    correctAnswer,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _handleNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ),
          if (!isCorrect) ...[
             const SizedBox(height: 12),
             TextButton(
               onPressed: () {
                 // Override as correct
                 _processCorrectAnswer(); // Fix stats
                 // But we already processed incorrect. 
                 // So we need to UNDO incorrect and DO correct.
                 // This logic requires state rollback.
                 // Simplified: Just increment correct count and mastery.
                 // But "Incorrect" was already logged.
                 // It's fine, "Override" usually means "Oops I was right".
                 // We can decrement _incorrectCount?
                 setState(() {
                    _incorrectCount--;
                    card.timesIncorrect--;
                    _processCorrectAnswer(); // Will add to stats and mastery
                 });
                 _handleNext();
               },
               child: const Text('I was correct'),
             ),
          ],
        ],
      );
    }

    return Column(
      children: _choices.map((choice) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _checkAnswer(choice),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: AppColors.surfaceLight),
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                choice,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWrittenAnswer(Flashcard card) {
    if (_showResult) {
       // Re-use MC result view logic or build similar
       // For brevity, using same logic structure
       bool useTerm = _getUseTerm(card.id);
       final correctAnswer = useTerm ? card.term : card.definition;
       final isCorrect = _isAnswerCorrect(_writtenAnswer, correctAnswer);
       
       return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCorrect ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isCorrect ? AppColors.success : AppColors.error),
            ),
            child: Column(
              children: [
                Text(isCorrect ? 'Correct!' : 'Incorrect', 
                  style: TextStyle(color: isCorrect ? AppColors.success : AppColors.error, fontWeight: FontWeight.bold, fontSize: 18)),
                if (!isCorrect) ...[
                  const SizedBox(height: 8),
                  Text('Correct: $correctAnswer'),
                  const SizedBox(height: 8),
                  Text('You said: $_writtenAnswer'),
                ]
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleNext,
              child: const Text('Continue'),
            ),
          ),
           if (!isCorrect) ...[
             TextButton(
               onPressed: () {
                 setState(() {
                    _incorrectCount--;
                    card.timesIncorrect--;
                    _processCorrectAnswer();
                 });
                 _handleNext();
               },
               child: const Text('I was correct'),
             ),
          ],
        ],
       );
    }

    return Column(
      children: [
        TextField(
          controller: _answerController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Type your answer...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (val) {
            _writtenAnswer = val;
            _checkAnswer(val);
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              _writtenAnswer = _answerController.text;
              _checkAnswer(_answerController.text);
            },
            child: const Text('Check Answer'),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            _writtenAnswer = "Don't know";
            _checkAnswer("Don't know");
          },
          child: const Text("Don't know"),
        ),
      ],
    );
  }

  Widget _buildCompleteView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
          const SizedBox(height: 24),
          Text(
            'Session Complete!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'You have mastered all terms in this set.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Back to Library'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                 _isSessionComplete = false;
                 _loadSet(); // Restart
              });
            },
            child: const Text('Study Again'),
          ),
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

enum _AnswerMode {
  korean,
  english,
  both,
}

