import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/storage_service.dart';
import '../../core/utils/quizlet_parser.dart';

/// Screen for importing flashcards from Quizlet
class ImportQuizletScreen extends StatefulWidget {
  const ImportQuizletScreen({super.key});

  @override
  State<ImportQuizletScreen> createState() => _ImportQuizletScreenState();
}

class _ImportQuizletScreenState extends State<ImportQuizletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _urlController = TextEditingController();
  final _pasteController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please enter a Quizlet URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await QuizletParser.importFromUrl(url);
      if (result != null) {
        await context.read<StorageService>().saveSet(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported "${result.title}" with ${result.termCount} cards')),
          );
          Navigator.of(context).pop();
        }
      } else {
        setState(() => _error = 'Could not parse Quizlet set. Try manual paste.');
      }
    } catch (e) {
      setState(() => _error = 'Error importing: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _importFromPaste() {
    final text = _pasteController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please paste your flashcard data');
      return;
    }

    try {
      final result = QuizletParser.parseFromText(text);
      if (result != null && result.cards.isNotEmpty) {
        context.read<StorageService>().saveSet(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported "${result.title}" with ${result.termCount} cards')),
        );
        Navigator.of(context).pop();
      } else {
        setState(() => _error = 'Could not parse the pasted text');
      }
    } catch (e) {
      setState(() => _error = 'Error parsing: $e');
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
        title: const Text('Import from Quizlet'),
      ),
      body: Column(
        children: [
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'From URL'),
              Tab(text: 'Manual Paste'),
            ],
          ),

          // Error message
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUrlTab(),
                _buildPasteTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Quizlet Share URL',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Copy the share link from Quizlet and paste it below',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'https://quizlet.com/123456789/...',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _importFromUrl,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Import'),
            ),
          ),

          const SizedBox(height: 24),
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
                    'Note: The set must be public to import. If import fails, use the Manual Paste option.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasteTab() {
    return Padding(
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
            'Supports: alternating lines (term, then definition) or separator formats',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TextField(
              controller: _pasteController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: '가게\nstore\n공항\nairport\n...',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _importFromPaste,
              child: const Text('Import'),
            ),
          ),
        ],
      ),
    );
  }
}
