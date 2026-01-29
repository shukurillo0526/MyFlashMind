import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/flashcard_set.dart';
import '../../data/models/folder.dart';
import '../../data/services/storage_service.dart';
import '../flashcard_detail/flashcard_detail_screen.dart';
import '../create/create_set_screen.dart';

/// Library screen with tabs for flashcard sets and folders
class LibraryScreen extends StatefulWidget {
  final VoidCallback? onNavigateToCreate;

  const LibraryScreen({super.key, this.onNavigateToCreate});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FlashcardSet> _sets = [];
  List<Folder> _folders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    final storage = context.read<StorageService>();
    setState(() {
      _sets = storage.getAllSets();
      _folders = storage.getAllFolders();
    });
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

  void _deleteSet(FlashcardSet set) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Delete set?'),
        content: Text('Are you sure you want to delete "${set.title}"?'),
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
      await context.read<StorageService>().deleteSet(set.id);
      _loadData();
    }
  }

  void _deleteFolder(Folder folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Delete folder?'),
        content: Text('Are you sure you want to delete "${folder.name}"?'),
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
      await context.read<StorageService>().deleteFolder(folder.id);
      _loadData();
    }
  }

  String _getDateGroupLabel(DateTime date) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final dateMonth = DateTime(date.year, date.month);

    if (dateMonth == thisMonth) {
      return 'This month';
    } else {
      final monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return 'In ${monthNames[date.month - 1]} ${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your library',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  IconButton(
                    onPressed: _createNewSet,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Flashcard sets'),
                  Tab(text: 'Folders'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSetsTab(),
                  _buildFoldersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetsTab() {
    if (_sets.isEmpty) {
      return _buildEmptyState(
        icon: Icons.style_outlined,
        title: 'No flashcard sets yet',
        subtitle: 'Create your first set to start learning',
        onAction: _createNewSet,
      );
    }

    // Group sets by month
    final grouped = <String, List<FlashcardSet>>{};
    for (final set in _sets) {
      final label = _getDateGroupLabel(set.createdAt);
      grouped.putIfAbsent(label, () => []).add(set);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final label = grouped.keys.elementAt(index);
        final sets = grouped[label]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            ...sets.map((set) => _buildSetTile(set)),
          ],
        );
      },
    );
  }

  Widget _buildSetTile(FlashcardSet set) {
    return Dismissible(
      key: Key(set.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteSet(set),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            title: const Text('Delete set?'),
            content: Text('Delete "${set.title}"?'),
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
      },
      child: ListTile(
        onTap: () => _openSet(set),
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.style, color: AppColors.textSecondary),
        ),
        title: Text(
          set.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          'Flashcard set · ${set.termCount} terms · by you',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _buildFoldersTab() {
    if (_folders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_outlined,
        title: 'No folders yet',
        subtitle: 'Create folders to organize your sets',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        return Dismissible(
          key: Key(folder.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: AppColors.error,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => _deleteFolder(folder),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder, color: AppColors.textSecondary),
            ),
            title: Text(folder.name),
            subtitle: Text('${folder.setCount} sets'),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: const Text('Create set'),
            ),
          ],
        ],
      ),
    );
  }
}
