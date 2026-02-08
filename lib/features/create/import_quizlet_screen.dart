import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/supabase_service.dart';
import '../../core/utils/quizlet_parser.dart';

/// Screen for importing flashcards via manual paste
class ImportQuizletScreen extends StatefulWidget {
  const ImportQuizletScreen({super.key});

  @override
  State<ImportQuizletScreen> createState() => _ImportQuizletScreenState();
}

class _ImportQuizletScreenState extends State<ImportQuizletScreen> {
  final _pasteController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _importFromPaste() async {
    final text = _pasteController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please paste your flashcard data');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = QuizletParser.parseFromText(text);
      if (result != null && result.cards.isNotEmpty) {
        // Save locally
        await context.read<StorageService>().saveSet(result);
        // Sync to cloud
        await context.read<SupabaseService>().saveSet(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported "${result.title}" with ${result.termCount} cards'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        setState(() => _error = 'Could not parse the pasted text. Make sure each card is on alternating lines (term, then definition).');
      }
    } catch (e) {
      setState(() => _error = 'Error parsing: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Import Flashcards'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste Flashcard Data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Copy flashcards from Quizlet (use Export feature) and paste below.\n'
              'Supports: alternating lines (term, then definition) or tab/semicolon separators.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Error message
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),

            Expanded(
              child: TextField(
                controller: _pasteController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: '가게\nstore\n공항\nairport\n...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Format help
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: In Quizlet, go to the set → "..." menu → Export → Copy all',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _importFromPaste,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Import'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
