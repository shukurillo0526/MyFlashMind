import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/flashcard.dart';
import '../../data/models/flashcard_set.dart';
import '../../data/models/folder.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/supabase_service.dart';
import '../flashcard_detail/flashcard_detail_screen.dart';
import '../create/create_set_screen.dart';
import '../study_modes/flashcards/flashcards_screen.dart';
import '../study_modes/learn/learn_screen.dart';
import '../study_modes/match/match_screen.dart';
import '../study_modes/test/test_setup_screen.dart';

/// Screen showing sets within a folder with study mode options
class FolderDetailScreen extends StatefulWidget {
  final String folderId;

  const FolderDetailScreen({super.key, required this.folderId});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  Folder? _folder;
  List<FlashcardSet> _sets = [];
  _SortMode _sortMode = _SortMode.recent;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final storage = context.read<StorageService>();
    final folder = storage.getFolder(widget.folderId);
    if (folder != null) {
      setState(() {
        _folder = folder;
        _sets = storage.getSetsInFolder(widget.folderId);
        _applySorting();
      });
    }
  }

  void _applySorting() {
    switch (_sortMode) {
      case _SortMode.recent:
        _sets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case _SortMode.title:
        _sets.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _SortMode.created:
        _sets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
  }

  /// Get total cards count across all sets in folder
  int get _totalCards {
    return _sets.fold(0, (sum, set) => sum + set.cards.length);
  }

  /// Aggregate all cards from all sets in this folder
  List<Flashcard> _getAllCards({bool shuffle = false}) {
    final allCards = <Flashcard>[];
    for (final set in _sets) {
      allCards.addAll(set.cards);
    }
    if (shuffle) {
      allCards.shuffle();
    }
    return allCards;
  }

  /// Create a temporary combined set for folder study
  Future<FlashcardSet> _createFolderStudySet({bool shuffle = false}) async {
    final allCards = _getAllCards(shuffle: shuffle);
    final storage = context.read<StorageService>();
    
    // Create a temporary study set with all folder cards
    final folderSet = FlashcardSet(
      id: 'folder_${widget.folderId}',
      title: '${_folder?.name} (All Cards)',
      description: 'Study all ${allCards.length} cards from this folder',
      cards: allCards,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    // Save temporarily so study screens can load it
    await storage.saveSet(folderSet);
    
    return folderSet;
  }

  void _showStudyModeModal() {
    if (_totalCards == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards to study in this folder')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.folder, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Study Folder',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '$_totalCards cards from ${_sets.length} sets',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Shuffle option card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shuffle, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Cards will be shuffled from all sets')),
                ],
              ),
            ),

            // Study mode options
            _buildStudyModeButton(
              icon: Icons.style,
              label: 'Flashcards',
              description: 'Swipe through cards',
              onTap: () => _startStudyMode('flashcards'),
            ),
            _buildStudyModeButton(
              icon: Icons.school,
              label: 'Learn',
              description: 'Master with spaced repetition',
              onTap: () => _startStudyMode('learn'),
            ),
            _buildStudyModeButton(
              icon: Icons.grid_view,
              label: 'Match',
              description: 'Race against the clock',
              onTap: () => _startStudyMode('match'),
            ),
            _buildStudyModeButton(
              icon: Icons.quiz,
              label: 'Test',
              description: 'Written and multiple choice',
              onTap: () => _startStudyMode('test'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyModeButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          description,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }

  Future<void> _startStudyMode(String mode) async {
    Navigator.pop(context); // Close modal
    
    // Create the combined study set
    final studySet = await _createFolderStudySet(shuffle: true);
    
    if (!mounted) return;
    
    Widget screen;
    switch (mode) {
      case 'flashcards':
        screen = FlashcardsScreen(setId: studySet.id);
        break;
      case 'learn':
        screen = LearnScreen(setId: studySet.id);
        break;
      case 'match':
        screen = MatchScreen(setId: studySet.id);
        break;
      case 'test':
        screen = TestSetupScreen(setId: studySet.id);
        break;
      default:
        return;
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) => _loadData());
  }

  void _openSet(FlashcardSet set) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FlashcardDetailScreen(setId: set.id),
      ),
    ).then((_) => _loadData());
  }

  void _createNewSet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateSetScreen(), 
      ),
    ).then((_) => _loadData());
  }
  
  void _editFolder() {
    // TODO: Implement folder editing (rename)
  }

  void _deleteFolder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Delete folder?'),
        content: Text('Delete "${_folder?.name}"? Sets inside will not be deleted.'),
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
      await context.read<StorageService>().deleteFolder(widget.folderId);
      await context.read<SupabaseService>().deleteFolder(widget.folderId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_folder == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_folder!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
               showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.cardBackground,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text('Rename folder'),
                      onTap: () {
                        Navigator.pop(context);
                        _editFolder();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete, color: AppColors.error),
                      title: const Text('Delete folder', style: TextStyle(color: AppColors.error)),
                      onTap: () {
                        Navigator.pop(context);
                        _deleteFolder();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      // Floating action button for study mode
      floatingActionButton: _totalCards > 0
          ? FloatingActionButton.extended(
              onPressed: _showStudyModeModal,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text('Study All', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: _sets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'Empty folder',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _createNewSet,
                    icon: const Icon(Icons.add),
                    label: const Text('Create set'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Folder stats header
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder, color: Colors.white, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_sets.length} sets • $_totalCards cards',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Study All" to learn everything',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Sort selector dropdown
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text('Sort by:', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<_SortMode>(
                          value: _sortMode,
                          underline: const SizedBox(),
                          isDense: true,
                          dropdownColor: AppColors.cardBackground,
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 14,
                          ),
                          items: const [
                            DropdownMenuItem(value: _SortMode.recent, child: Text('Recent')),
                            DropdownMenuItem(value: _SortMode.title, child: Text('Title')),
                            DropdownMenuItem(value: _SortMode.created, child: Text('Created')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _sortMode = value;
                                _applySorting();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Sets list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _sets.length,
                    itemBuilder: (context, index) {
                      final set = _sets[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () => _openSet(set),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          tileColor: AppColors.cardBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.style, color: AppColors.primary),
                          ),
                          title: Text(
                            set.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            '${set.termCount} terms',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// Sort modes for folder sets
enum _SortMode {
  recent,
  title,
  created,
}
