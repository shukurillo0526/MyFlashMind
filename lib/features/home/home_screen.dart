import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/utils/toast_utils.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../data/models/flashcard_set.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/supabase_service.dart';
import '../create/create_set_screen.dart';
import '../flashcard_detail/flashcard_detail_screen.dart';
import '../statistics/statistics_screen.dart';
import '../../data/services/import_export_service.dart';
import '../../core/widgets/animations.dart';
import 'widgets/progress_card.dart';
import 'widgets/search_bar_widget.dart';

/// Home screen with recent sets and search
class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToCreate;

  const HomeScreen({super.key, this.onNavigateToCreate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FlashcardSet> _recentSets = [];
  List<FlashcardSet> _searchResults = [];
  int _dueCardCount = 0;
  bool _isSearching = false;
  bool _isSyncing = false;
  StreamSubscription? _realtimeSubscription;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentSets();
      _setupRealtimeSubscription();
      _syncFromCloud(); // Auto-sync on startup
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRecentSets();
  }

  void _loadRecentSets() {
    final storage = context.read<StorageService>();
    final allSets = storage.getAllSets();
    
    // Count due cards across all sets
    int dueCount = 0;
    for (final set in allSets) {
      for (final card in set.cards) {
        if (card.isDue) dueCount++;
      }
    }
    
    setState(() {
      _recentSets = allSets.take(10).toList();
      _dueCardCount = dueCount;
    });
  }

  void _setupRealtimeSubscription() {
    final supabase = context.read<SupabaseService>();
    if (!supabase.isAuthenticated) return;

    _realtimeSubscription = supabase.subscribeToChanges().listen((data) {
      if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
      _debounceTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) _syncFromCloud();
      });
    });
  }

  Future<void> _syncFromCloud() async {
    setState(() => _isSyncing = true);
    try {
      final supabaseService = context.read<SupabaseService>();
      final storageService = context.read<StorageService>();
      
      // Fetch cloud data
      final cloudSets = await supabaseService.fetchAllSets();
      final cloudFolders = await supabaseService.fetchAllFolders();
      
      // Update local storage
      for (final set in cloudSets) {
        await storageService.saveSet(set);
      }
      for (final folder in cloudFolders) {
        await storageService.saveFolder(folder);
      }
      
      _loadRecentSets();
      
      if (mounted) {
        ToastUtils.showInfo(context, 'Synced from cloud');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, 'Sync failed: $e', isError: true);
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _onSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    final storage = context.read<StorageService>();
    setState(() {
      _isSearching = true;
      _searchResults = storage.searchSets(query);
    });
  }

  void _openSet(FlashcardSet set) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FlashcardDetailScreen(setId: set.id),
      ),
    ).then((_) => _loadRecentSets());
  }

  void _editSet(FlashcardSet set) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateSetScreen(editSetId: set.id),
      ),
    ).then((_) {
      _loadRecentSets();
      _syncFromCloud();
    });
  }

  Future<void> _deleteSet(FlashcardSet set) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Set'),
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

    if (confirm == true) {
      if (mounted) {
        await context.read<StorageService>().deleteSet(set.id);
        if (mounted) {
          await context.read<SupabaseService>().deleteSet(set.id);
          _loadRecentSets();
          ToastUtils.showInfo(context, 'Set deleted');
        }
      }
    }
  }

  Future<void> _exportAllSets() async {
    Navigator.pop(context);
    final storage = context.read<StorageService>();
    final sets = storage.getAllSets();
    if (sets.isEmpty) {
      ToastUtils.showInfo(context, 'No sets to export');
      return;
    }
    final service = ImportExportService();
    final json = service.exportSetsToJson(sets);
    await service.copyToClipboard(json);
    if (mounted) ToastUtils.showSuccess(context, 'Copied ${sets.length} sets to clipboard');
  }

  Future<void> _importFromClipboard() async {
    Navigator.pop(context);
    final service = ImportExportService();
    final clipboard = await service.getFromClipboard();
    if (clipboard == null || clipboard.isEmpty) {
      if (mounted) ToastUtils.showInfo(context, 'Clipboard is empty');
      return;
    }
    final sets = service.importSetsFromJson(clipboard);
    if (sets == null || sets.isEmpty) {
      if (mounted) ToastUtils.showInfo(context, 'Could not parse clipboard data');
      return;
    }
    final storage = context.read<StorageService>();
    for (final set in sets) {
      await storage.saveSet(set);
    }
    _loadRecentSets();
    if (mounted) ToastUtils.showSuccess(context, 'Imported ${sets.length} sets');
  }

  void _showProfileMenu() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color ?? theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.sync, color: theme.iconTheme.color),
                title: Text('Sync Data', style: TextStyle(color: theme.colorScheme.onSurface)),
                subtitle: Text('Sync with cloud', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data synced!')),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.bar_chart, color: theme.iconTheme.color),
                title: Text('Statistics', style: TextStyle(color: theme.colorScheme.onSurface)),
                subtitle: Text('View your progress', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                  );
                },
              ),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return ListTile(
                    leading: Icon(themeProvider.isDarkMode 
                        ? Icons.dark_mode 
                        : Icons.light_mode,
                        color: theme.iconTheme.color),
                    title: Text('Dark Mode', style: TextStyle(color: theme.colorScheme.onSurface)),
                    trailing: Switch(
                      value: themeProvider.isDarkMode,
                      onChanged: (_) => themeProvider.toggleTheme(),
                    ),
                    onTap: () => themeProvider.toggleTheme(),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.upload, color: theme.iconTheme.color),
                title: Text('Export All', style: TextStyle(color: theme.colorScheme.onSurface)),
                subtitle: Text('Copy all sets to clipboard', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                onTap: () => _exportAllSets(),
              ),
              ListTile(
                leading: Icon(Icons.download, color: theme.iconTheme.color),
                title: Text('Import', style: TextStyle(color: theme.colorScheme.onSurface)),
                subtitle: Text('Import from clipboard', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                onTap: () => _importFromClipboard(),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(context);
                  await Supabase.instance.client.auth.signOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _syncFromCloud,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // Sync indicator
              if (_isSyncing)
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: AppColors.primary.withOpacity(0.1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Syncing...',
                          style: TextStyle(color: AppColors.primary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

              // Search bar and profile
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: SearchBarWidget(
                          onSearch: _onSearch,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _showProfileMenu,
                        child: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              if (_isSearching)
                _buildSearchResults()
              else
                _buildHomeContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Due Today Banner
          if (_dueCardCount > 0 && !_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.2), AppColors.secondary.withOpacity(0.2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.access_time, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_dueCardCount cards due',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Review now to strengthen memory',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _recentSets.isNotEmpty ? () => _openSet(_recentSets.first) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Study'),
                    ),
                  ],
                ),
              ),
            ),
          
          // Recent Sets section
          if (_recentSets.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Recent Sets',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.9),
                itemCount: _recentSets.length,
                itemBuilder: (context, index) {
                  return FadeSlideAnimation(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ProgressCard(
                        flashcardSet: _recentSets[index],
                        onTap: () => _openSet(_recentSets[index]),
                        onEdit: () => _editSet(_recentSets[index]),
                        onDelete: () => _deleteSet(_recentSets[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Empty state
          if (_recentSets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(
                      Icons.style_outlined,
                      size: 80,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No flashcard sets yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first set to start learning',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: widget.onNavigateToCreate,
                      icon: const Icon(Icons.add),
                      label: const Text('Create set'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'No results found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final set = _searchResults[index];
          return ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.style, color: AppColors.primary),
            ),
            title: Text(set.title),
            subtitle: Text('${set.termCount} terms'),
            onTap: () => _openSet(set),
          );
        },
        childCount: _searchResults.length,
      ),
    );
  }
}
