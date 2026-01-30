import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/flashcard.dart';
import '../../../data/models/flashcard_set.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/supabase_service.dart';

/// Test screen with various question types
class TestScreen extends StatefulWidget {
  final String setId;
  final int questionCount;
  final bool instantFeedback;
  final bool shuffleTerms;
  final bool answerWithTerm;
  final bool includeTrueFalse;
  final bool includeMultipleChoice;
  final bool includeWritten;

  const TestScreen({
    super.key,
    required this.setId,
    required this.questionCount,
    required this.instantFeedback,
    required this.shuffleTerms,
    required this.answerWithTerm,
    required this.includeTrueFalse,
    required this.includeMultipleChoice,
    required this.includeWritten,
  });

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  FlashcardSet? _set;
  List<_Question> _questions = [];
  int _currentIndex = 0;
  bool _isComplete = false;
  final Random _random = Random();
  final TextEditingController _answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSetAndGenerateQuestions();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _loadSetAndGenerateQuestions() {
    final set = context.read<StorageService>().getSet(widget.setId);
    if (set != null) {
      setState(() {
        _set = set;
        _questions = _generateQuestions(set);
      });
    }
  }

  List<_Question> _generateQuestions(FlashcardSet set) {
    final cards = List<Flashcard>.from(set.cards);
    if (widget.shuffleTerms) cards.shuffle();
    
    final selectedCards = cards.take(widget.questionCount).toList();
    final questions = <_Question>[];
    
    // Collect enabled question types
    final types = <_QuestionType>[];
    if (widget.includeTrueFalse) types.add(_QuestionType.trueFalse);
    if (widget.includeMultipleChoice) types.add(_QuestionType.multipleChoice);
    if (widget.includeWritten) types.add(_QuestionType.written);
    
    if (types.isEmpty) types.add(_QuestionType.multipleChoice);
    
    for (final card in selectedCards) {
      final type = types[_random.nextInt(types.length)];
      final prompt = widget.answerWithTerm ? card.definition : card.term;
      final correctAnswer = widget.answerWithTerm ? card.term : card.definition;
      
      List<String>? choices;
      bool? trueFalseStatement;
      String? displayedAnswer;
      
      if (type == _QuestionType.multipleChoice) {
        final otherCards = set.cards.where((c) => c.id != card.id).toList()..shuffle();
        choices = [correctAnswer];
        for (int i = 0; i < 3 && i < otherCards.length; i++) {
          choices.add(widget.answerWithTerm
              ? otherCards[i].term
              : otherCards[i].definition);
        }
        choices.shuffle();
      } else if (type == _QuestionType.trueFalse) {
        trueFalseStatement = _random.nextBool();
        if (trueFalseStatement) {
          displayedAnswer = correctAnswer;
        } else {
          final otherCards = set.cards.where((c) => c.id != card.id).toList()..shuffle();
          if (otherCards.isNotEmpty) {
            displayedAnswer = widget.answerWithTerm
                ? otherCards.first.term
                : otherCards.first.definition;
          } else {
            displayedAnswer = correctAnswer;
            trueFalseStatement = true;
          }
        }
      }
      
      questions.add(_Question(
        card: card,
        type: type,
        prompt: prompt,
        correctAnswer: correctAnswer,
        choices: choices,
        trueFalseIsTrue: trueFalseStatement,
        displayedAnswer: displayedAnswer,
      ));
    }
    
    return questions;
  }

  void _submitAnswer(dynamic answer) {
    final question = _questions[_currentIndex];
    bool isCorrect = false;
    
    if (question.type == _QuestionType.trueFalse) {
      isCorrect = (answer as bool) == question.trueFalseIsTrue;
    } else if (question.type == _QuestionType.multipleChoice) {
      isCorrect = answer == question.correctAnswer;
    } else {
      // Written answer with relaxed grading
      isCorrect = _isAnswerCorrect(answer as String, question.correctAnswer);
    }
    
    setState(() {
      question.userAnswer = answer;
      question.isCorrect = isCorrect;
    });
    
    if (widget.instantFeedback) {
      _showFeedback(isCorrect, question.correctAnswer);
    } else {
      _nextQuestion();
    }
  }

  bool _isAnswerCorrect(String answer, String correct) {
    final a = answer.toLowerCase().trim();
    final c = correct.toLowerCase().trim();
    
    if (a == c) return true;
    
    // Relaxed: allow 1-2 character differences for longer answers
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

  void _showFeedback(bool isCorrect, String correctAnswer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isCorrect
          ? AppColors.success.withOpacity(0.9)
          : AppColors.error.withOpacity(0.9),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              isCorrect ? 'Correct!' : 'Incorrect',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isCorrect) ...[
              const SizedBox(height: 8),
              Text(
                'Correct answer: $correctAnswer',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _nextQuestion();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: isCorrect ? AppColors.success : AppColors.error,
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextQuestion() {
    _answerController.clear();
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      setState(() => _isComplete = true);
      _saveResults();
    }
  }

  void _saveResults() async {
    if (_set == null) return;
    
    for (final question in _questions) {
      if (question.isCorrect == true) {
        question.card.timesCorrect++;
      } else if (question.isCorrect == false) {
        question.card.timesIncorrect++;
      }
      question.card.lastStudied = DateTime.now();
    }
    
    _set!.lastStudied = DateTime.now();
    _set!.updateProgress();
    // Save locally
    await context.read<StorageService>().saveSet(_set!);
    // Sync to cloud
    await context.read<SupabaseService>().saveSet(_set!);
  }

  @override
  Widget build(BuildContext context) {
    if (_set == null || _questions.isEmpty) {
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
        title: Text('Question ${_currentIndex + 1} of ${_questions.length}'),
      ),
      body: _isComplete ? _buildResults() : _buildQuestion(),
    );
  }

  Widget _buildQuestion() {
    final question = _questions[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              backgroundColor: AppColors.surface,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 24),

          // Prompt
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              question.prompt,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // Answer area based on type
          Expanded(
            child: _buildAnswerArea(question),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerArea(_Question question) {
    switch (question.type) {
      case _QuestionType.trueFalse:
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                question.displayedAnswer ?? '',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _submitAnswer(true),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: AppColors.success,
                      side: const BorderSide(color: AppColors.success),
                    ),
                    child: const Text('True'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _submitAnswer(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('False'),
                  ),
                ),
              ],
            ),
          ],
        );

      case _QuestionType.multipleChoice:
        return ListView.builder(
          itemCount: question.choices!.length,
          itemBuilder: (context, index) {
            final choice = question.choices![index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _submitAnswer(choice),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Text(choice),
                  ),
                ),
              ),
            );
          },
        );

      case _QuestionType.written:
        return Column(
          children: [
            TextField(
              controller: _answerController,
              onSubmitted: (value) {
                if (value.isNotEmpty) _submitAnswer(value);
              },
              decoration: InputDecoration(
                hintText: 'Type your answer...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_answerController.text.isNotEmpty) {
                    _submitAnswer(_answerController.text);
                  }
                },
                child: const Text('Submit'),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildResults() {
    final correct = _questions.where((q) => q.isCorrect == true).length;
    final total = _questions.length;
    final percentage = (correct / total * 100).round();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                      '$percentage%',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: percentage >= 70
                                ? AppColors.success
                                : percentage >= 50
                                    ? AppColors.warning
                                    : AppColors.error,
                          ),
                    ),
                    Text(
                      '$correct/$total correct',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              percentage >= 90
                  ? 'Excellent!'
                  : percentage >= 70
                      ? 'Great job!'
                      : percentage >= 50
                          ? 'Good effort!'
                          : 'Keep practicing!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                    _isComplete = false;
                    _questions = _generateQuestions(_set!);
                  });
                },
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _QuestionType {
  trueFalse,
  multipleChoice,
  written,
}

class _Question {
  final Flashcard card;
  final _QuestionType type;
  final String prompt;
  final String correctAnswer;
  final List<String>? choices;
  final bool? trueFalseIsTrue;
  final String? displayedAnswer;
  
  dynamic userAnswer;
  bool? isCorrect;

  _Question({
    required this.card,
    required this.type,
    required this.prompt,
    required this.correctAnswer,
    this.choices,
    this.trueFalseIsTrue,
    this.displayedAnswer,
  });
}
