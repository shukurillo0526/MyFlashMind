import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/flashcard_set.dart';
import '../../data/models/folder.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/supabase_service.dart';
import '../flashcard_detail/flashcard_detail_screen.dart';
import '../create/create_set_screen.dart';

/// Screen showing sets within a folder
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
