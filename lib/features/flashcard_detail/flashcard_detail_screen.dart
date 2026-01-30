import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/utils/toast_utils.dart';
import 'package:flip_card/flip_card.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/flashcard.dart';
import '../../data/models/flashcard_set.dart';
import '../../data/models/folder.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/supabase_service.dart';
import '../create/create_set_screen.dart';
import '../study_modes/flashcards/flashcards_screen.dart';
import '../study_modes/learn/learn_screen.dart';
import '../study_modes/test/test_setup_screen.dart';
import '../study_modes/match/match_screen.dart';

/// Screen showing flashcard set details with study mode options
class FlashcardDetailScreen extends StatefulWidget {
  final String setId;

  const FlashcardDetailScreen({super.key, required this.setId});

  @override
  State<FlashcardDetailScreen> createState() => _FlashcardDetailScreenState();
}

class _FlashcardDetailScreenState extends State<FlashcardDetailScreen> {
  FlashcardSet? _set;
  int _currentCardIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadSet();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadSet() {
    final set = context.read<StorageService>().getSet(widget.setId);
    setState(() => _set = set);
  }

  void _openFlashcards() {
    if (_set == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FlashcardsScreen(setId: _set!.id),
      ),
    ).then((_) => _loadSet());
  }

  void _openLearn() {
    if (_set == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LearnScreen(setId: _set!.id),
      ),
    ).then((_) => _loadSet());
  }

  void _openTest() {
    if (_set == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TestSetupScreen(setId: _set!.id),
      ),
    ).then((_) => _loadSet());
  }

  void _openMatch() {
    if (_set == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MatchScreen(setId: _set!.id),
      ),
    ).then((_) => _loadSet());
  }

  void _editSet() {
    if (_set == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateSetScreen(editSetId: _set!.id),
      ),
    ).then((_) => _loadSet());
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
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showOptionsMenu(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card preview carousel
            SizedBox(
              height: 240,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentCardIndex = index);
                },
                itemCount: _set!.cards.length,
                itemBuilder: (context, index) {
                  final card = _set!.cards[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FlipCard(
                      direction: FlipDirection.HORIZONTAL,
                      front: _buildCardFace(card.term, true),
                      back: _buildCardFace(card.definition, false),
                    ),
                  );
                },
              ),
            ),

            // Page indicators
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _set!.cards.length.clamp(0, 10),
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentCardIndex % 10
                            ? AppColors.primary
                            : AppColors.surface,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Set info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _set!.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download_outlined),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary,
                        child: const Text('U', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'You',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '|',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_set!.termCount} terms',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Study mode buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildStudyModeButton(
                    icon: Icons.style,
                    iconColor: AppColors.primary,
                    label: 'Flashcards',
                    onTap: _openFlashcards,
                  ),
                  const SizedBox(height: 8),
                  _buildStudyModeButton(
                    icon: Icons.psychology,
                    iconColor: AppColors.secondary,
                    label: 'Learn',
                    onTap: _openLearn,
                  ),
                  const SizedBox(height: 8),
                  _buildStudyModeButton(
                    icon: Icons.quiz,
                    iconColor: AppColors.primary,
                    label: 'Test',
                    onTap: _openTest,
                  ),
                  const SizedBox(height: 8),
                  _buildStudyModeButton(
                    icon: Icons.grid_view,
                    iconColor: AppColors.accent,
                    label: 'Match',
                    onTap: _openMatch,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Statistics Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Progress',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withOpacity(0.1),
                          AppColors.secondary.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.surface,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          icon: Icons.emoji_events,
                          color: AppColors.accent,
                          value: '${(_set!.progress * 100).round()}%',
                          label: 'Mastery',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.surface,
                        ),
                        _buildStatItem(
                          icon: Icons.check_circle,
                          color: AppColors.success,
                          value: '${_calculateAccuracy()}%',
                          label: 'Accuracy',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.surface,
                        ),
                        _buildStatItem(
                          icon: Icons.access_time,
                          color: AppColors.secondary,
                          value: _getLastStudiedText(),
                          label: 'Last Study',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  int _calculateAccuracy() {
    int totalCorrect = 0;
    int totalAttempts = 0;
    for (final card in _set!.cards) {
      totalCorrect += card.timesCorrect;
      totalAttempts += card.timesCorrect + card.timesIncorrect;
    }
    if (totalAttempts == 0) return 0;
    return (totalCorrect / totalAttempts * 100).round();
  }

  String _getLastStudiedText() {
    if (_set!.lastStudied == null) return 'Never';
    final diff = DateTime.now().difference(_set!.lastStudied!);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).round()}w ago';
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildCardFace(String text, bool isFront) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                text,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Icon(
              Icons.fullscreen,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyModeButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 16),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _duplicateSet() async {
    if (_set == null) return;
    
    final newSetId = const Uuid().v4();
    final now = DateTime.now();
    
    final newCards = _set!.cards.map((c) => Flashcard(
      id: const Uuid().v4(),
      term: c.term,
      definition: c.definition,
    )).toList();

    final newSet = FlashcardSet(
      id: newSetId,
      title: '${_set!.title} (Copy)',
      description: _set!.description,
      cards: newCards,
      createdAt: now,
      updatedAt: now,
      cardsKnown: 0,
      cardsLearning: 0,
    );
    
    final storage = context.read<StorageService>();
    final supabase = context.read<SupabaseService>();
    
    await storage.saveSet(newSet);
    await supabase.saveSet(newSet);
    
    if (mounted) {
      ToastUtils.showInfo(context, 'Set copied');
    }
  }

  void _addToFolder() {
    final folders = context.read<StorageService>().getAllFolders();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Add to folder'),
        content: SizedBox(
          width: double.maxFinite,
          child: folders.isEmpty 
              ? const Text('No folders created yet.')
              : ListView.builder(
            shrinkWrap: true,
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              final isInFolder = folder.setIds.contains(_set!.id);
              return ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder.name),
                trailing: isInFolder ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                onTap: () async {
                  if (!isInFolder) {
                     folder.setIds.add(_set!.id);
                     folder.updatedAt = DateTime.now();
                     await context.read<StorageService>().saveFolder(folder);
                     await context.read<SupabaseService>().saveFolder(folder);
                     
                     _set!.folderId = folder.id;
                      await context.read<StorageService>().saveSet(_set!);
                      await context.read<SupabaseService>().saveSet(_set!);
                      
                     if (mounted) {
                       Navigator.pop(context);
                       ToastUtils.showInfo(context, 'Added to ${folder.name}');
                     }
                  } else {
                     folder.setIds.remove(_set!.id);
                     folder.updatedAt = DateTime.now();
                      await context.read<StorageService>().saveFolder(folder);
                      await context.read<SupabaseService>().saveFolder(folder);
                      
                      if (_set!.folderId == folder.id) {
                        _set!.folderId = null;
                        await context.read<StorageService>().saveSet(_set!);
                        await context.read<SupabaseService>().saveSet(_set!);
                      }

                      if (mounted) {
                       Navigator.pop(context);
                       ToastUtils.showInfo(context, 'Removed from ${folder.name}');
                     }
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSetInfo() {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Set Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Author: You'),
            const SizedBox(height: 8),
            Text('Created: ${_set!.createdAt.toString().split(' ')[0]}'),
            const SizedBox(height: 8),
            Text('Terms: ${_set!.termCount}'),
            const SizedBox(height: 8),
            Text('Progress: ${(_set!.progress * 100).round()}%'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit set'),
              onTap: () {
                Navigator.pop(context);
                _editSet();
              },
            ),
             ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Add to folder'),
              onTap: () {
                Navigator.pop(context);
                _addToFolder();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Make a copy'),
              onTap: () {
                Navigator.pop(context);
                _duplicateSet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(
                  text: 'Check out my flashcard set "${_set!.title}" on MyFlashMind! (${_set!.termCount} terms)',
                ));
                if (mounted) {
                  ToastUtils.showInfo(context, 'Link copied to clipboard');
                }
              },
            ),
             ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Set info'),
              onTap: () {
                Navigator.pop(context);
                _showSetInfo();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('Delete set', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: AppColors.cardBackground,
                    title: const Text('Delete set?'),
                    content: Text('Delete "${_set!.title}"? This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await context.read<StorageService>().deleteSet(_set!.id);
                  if (mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
