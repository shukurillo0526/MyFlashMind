import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/flashcard_set.dart';
import '../../data/services/storage_service.dart';
import '../flashcard_detail/flashcard_detail_screen.dart';
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
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentSets();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRecentSets();
  }

  void _loadRecentSets() {
    final storage = context.read<StorageService>();
    setState(() {
      _recentSets = storage.getRecentSets(limit: 10);
      if (_recentSets.isEmpty) {
        // Show all sets if no recent ones
        _recentSets = storage.getAllSets().take(10).toList();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Search bar only
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SearchBarWidget(
                  onSearch: _onSearch,
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
    );
  }

  Widget _buildHomeContent() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jump back in section
          if (_recentSets.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Jump back in',
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ProgressCard(
                      flashcardSet: _recentSets[index],
                      onTap: () => _openSet(_recentSets[index]),
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
