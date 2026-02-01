import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/flashcard_set.dart';
import '../../../data/services/storage_service.dart';
import 'test_screen.dart';

/// Test setup screen matching Quizlet's test configuration UI
class TestSetupScreen extends StatefulWidget {
  final String setId;

  const TestSetupScreen({super.key, required this.setId});

  @override
  State<TestSetupScreen> createState() => _TestSetupScreenState();
}

class _TestSetupScreenState extends State<TestSetupScreen> {
  FlashcardSet? _set;
  
  // Test options
  int _questionCount = 10;
  bool _instantFeedback = true;
  bool _shuffleTerms = true;
  _AnswerMode _answerMode = _AnswerMode.definition;
  
  // Prompt options (what appears as the question)
  bool _promptWithKorean = true;   // Term
  bool _promptWithEnglish = true;  // Definition
  
  // Question types
  bool _trueFalse = false;
  bool _multipleChoice = true;
  bool _written = true;

  @override
  void initState() {
    super.initState();
    _loadSet();
  }

  void _loadSet() {
    final set = context.read<StorageService>().getSet(widget.setId);
    setState(() {
      _set = set;
      if (set != null) {
        _questionCount = set.termCount.clamp(1, 50);
      }
    });
  }

  void _startTest() {
    if (_set == null) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => TestScreen(
          setId: _set!.id,
          questionCount: _questionCount,
          instantFeedback: _instantFeedback,
          shuffleTerms: _shuffleTerms,
          answerMode: _answerMode.name,  // Pass as string
          includeTrueFalse: _trueFalse,
          includeMultipleChoice: _multipleChoice,
          includeWritten: _written,
        ),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _set!.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set up your test',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.quiz, color: Colors.white, size: 32),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Question count
            _buildOptionRow(
              'Question count',
              trailing: DropdownButton<int>(
                value: _questionCount,
                dropdownColor: AppColors.cardBackground,
                underline: const SizedBox(),
                items: _buildQuestionCountOptions(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _questionCount = value);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),

            // Instant feedback
            _buildOptionRow(
              'Instant feedback',
              trailing: Switch(
                value: _instantFeedback,
                onChanged: (value) => setState(() => _instantFeedback = value),
              ),
            ),
            const SizedBox(height: 12),
            
            // Answer options - opens modal
            _buildOptionRow(
              'Answer options',
              subtitle: _getAnswerOptionsSubtitle(),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showAnswerOptionsModal,
            ),

            const SizedBox(height: 24),
            const Divider(color: AppColors.surface),
            const SizedBox(height: 24),

            // Answer with
            Text('Answer with', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<_AnswerMode>(
              segments: const [
                ButtonSegment(value: _AnswerMode.term, label: Text('Korean')),
                ButtonSegment(value: _AnswerMode.definition, label: Text('English')),
                ButtonSegment(value: _AnswerMode.both, label: Text('Both')),
              ],
              selected: {_answerMode},
              onSelectionChanged: (Set<_AnswerMode> newSelection) {
                setState(() => _answerMode = newSelection.first);
              },
            ),

            const SizedBox(height: 24),
            const Divider(color: AppColors.surface),
            const SizedBox(height: 24),

            // Question types
            _buildOptionRow(
              'True/false',
              trailing: Switch(
                value: _trueFalse,
                onChanged: (value) => setState(() => _trueFalse = value),
              ),
            ),
            const SizedBox(height: 12),

            _buildOptionRow(
              'Multiple choice',
              trailing: Switch(
                value: _multipleChoice,
                onChanged: (value) {
                  // Ensure at least one type is selected
                  if (!value && !_written && !_trueFalse) return;
                  setState(() => _multipleChoice = value);
                },
              ),
            ),
            const SizedBox(height: 12),

            _buildOptionRow(
              'Written',
              trailing: Switch(
                value: _written,
                onChanged: (value) {
                  if (!value && !_multipleChoice && !_trueFalse) return;
                  setState(() => _written = value);
                },
              ),
            ),

            const SizedBox(height: 48),

            // Start button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startTest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Start test'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow(
    String label, {
    String? subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final content = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        trailing,
      ],
    );
    
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: content,
        ),
      );
    }
    return content;
  }
  
  String _getAnswerOptionsSubtitle() {
    final prompts = <String>[];
    if (_promptWithKorean) prompts.add('Korean');
    if (_promptWithEnglish) prompts.add('English');
    return 'Prompt with: ${prompts.join(', ')}';
  }
  
  void _showAnswerOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Answer options',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Text('Prompt with', style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
            )),
            const SizedBox(height: 8),
            Text('Select what appears as the question', 
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            
            _buildModalToggle('Korean (Term)', _promptWithKorean, (v) {
              if (!v && !_promptWithEnglish) return;
              setState(() => _promptWithKorean = v);
              Navigator.pop(context);
              _showAnswerOptionsModal();
            }),
            const SizedBox(height: 8),
            _buildModalToggle('English (Definition)', _promptWithEnglish, (v) {
              if (!v && !_promptWithKorean) return;
              setState(() => _promptWithEnglish = v);
              Navigator.pop(context);
              _showAnswerOptionsModal();
            }),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  Widget _buildModalToggle(String label, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  List<DropdownMenuItem<int>> _buildQuestionCountOptions() {
    final maxQuestions = _set?.termCount ?? 10;
    final options = <int>[];
    
    for (int i = 5; i <= maxQuestions; i += 5) {
      options.add(i);
    }
    if (!options.contains(maxQuestions)) {
      options.add(maxQuestions);
    }
    
    return options.map((count) {
      return DropdownMenuItem<int>(
        value: count,
        child: Row(
          children: [
            Text('$count'),
            const Icon(Icons.arrow_drop_down, color: AppColors.primary),
          ],
        ),
      );
    }).toList();
  }
}

/// Answer mode for test questions
enum _AnswerMode {
  term,
  definition,
  both,
}
