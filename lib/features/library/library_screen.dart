import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/flashcard_set.dart';
import '../../data/models/folder.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/supabase_service.dart';
import '../flashcard_detail/flashcard_detail_screen.dart';
import '../create/create_set_screen.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/toast_utils.dart';
import 'folder_detail_screen.dart';

/// Library screen with tabs for flashcard sets and folders
class LibraryScreen extends StatefulWidget {
  final VoidCallback? onNavigateToCreate;

  const LibraryScreen({super.key, this.onNavigateToCreate});

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<FlashcardSet> _sets = [];
  List<Folder> _folders = [];
  List<FlashcardSet> _filteredSets = [];
  List<Folder> _filteredFolders = [];
  String _searchQuery = '';
  _SortMode _sortMode = _SortMode.recent;
  bool _isLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Load data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  /// Public method to reload data (called when tab becomes active)
  void reloadData() {
    if (mounted) {
      _loadData();
    }
  }

  void _loadData() {
    final storage = context.read<StorageService>();
    setState(() {
      _sets = storage.getAllSets();
      _folders = storage.getAllFolders();
      _isLoaded = true;
      _applySearch();
    });
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredSets = List.from(_sets);
      _filteredFolders = _folders;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredSets = _sets.where((s) => 
        s.title.toLowerCase().contains(query) ||
        (s.description?.toLowerCase().contains(query) ?? false)
      ).toList();
      _filteredFolders = _folders.where((f) => 
        f.name.toLowerCase().contains(query)
      ).toList();
    }
    
    // Apply sorting
    switch (_sortMode) {
      case _SortMode.recent:
        _filteredSets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case _SortMode.title:
        _filteredSets.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _SortMode.created:
        _filteredSets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _applySearch();
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

  void _createNewFolder() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Folder name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              
              final now = DateTime.now();
              final folder = Folder(
                id: const Uuid().v4(),
                name: name,
                createdAt: now,
                updatedAt: now,
              );
              
              await context.read<StorageService>().saveFolder(folder);
              await context.read<SupabaseService>().saveFolder(folder);
              
              if (mounted) {
                Navigator.pop(context);
                _loadData();
                ToastUtils.showInfo(context, 'Folder created');
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _openFolder(Folder folder) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FolderDetailScreen(folderId: folder.id),
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
      // Delete locally
      await context.read<StorageService>().deleteSet(set.id);
      // Delete from cloud
      await context.read<SupabaseService>().deleteSet(set.id);
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
      // Delete locally
      await context.read<StorageService>().deleteFolder(folder.id);
      // Delete from cloud
      await context.read<SupabaseService>().deleteFolder(folder.id);
      _loadData();
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
                  PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, size: 20),
                    ),
                    onSelected: (value) {
                      if (value == 'set') {
                        _createNewSet();
                      } else if (value == 'folder') {
                        _createNewFolder();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'set',
                        child: Row(
                          children: [
                            Icon(Icons.style, size: 20),
                            SizedBox(width: 12),
                            Text('New flashcard set'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'folder',
                        child: Row(
                          children: [
                            Icon(Icons.folder, size: 20),
                            SizedBox(width: 12),
                            Text('New folder'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Search your library...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

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
    if (_filteredSets.isEmpty) {
      return _buildEmptyState(
        icon: Icons.style_outlined,
        title: _searchQuery.isEmpty ? 'No flashcard sets yet' : 'No results found',
        subtitle: _searchQuery.isEmpty ? 'Create your first set to start learning' : 'Try a different search term',
        onAction: _searchQuery.isEmpty ? _createNewSet : null,
      );
    }

    return Column(
      children: [
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
                        _applySearch();
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
            itemCount: _filteredSets.length,
            itemBuilder: (context, index) {
              return _buildSetTile(_filteredSets[index]);
            },
          ),
        ),
      ],
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
    if (_filteredFolders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_outlined,
        title: _searchQuery.isEmpty ? 'No folders yet' : 'No results found',
        subtitle: _searchQuery.isEmpty ? 'Create folders to organize your sets' : 'Try a different search term',
      );
    }

    final storage = context.read<StorageService>();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredFolders.length,
      itemBuilder: (context, index) {
        final folder = _filteredFolders[index];
        // Dynamically compute set count
        final setCount = storage.getSetsInFolder(folder.id).length;
        
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
            onTap: () => _openFolder(folder),
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
            subtitle: Text('$setCount sets'),
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

/// Sort modes for library sets
enum _SortMode {
  recent,
  title,
  created,
}
