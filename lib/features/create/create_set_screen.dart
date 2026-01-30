import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/flashcard.dart';
import '../../data/models/flashcard_set.dart';
import '../../data/models/folder.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/supabase_service.dart';

/// Screen for creating/editing a flashcard set
class CreateSetScreen extends StatefulWidget {
  final String? editSetId;

  const CreateSetScreen({super.key, this.editSetId});

  @override
  State<CreateSetScreen> createState() => _CreateSetScreenState();
}

class _CreateSetScreenState extends State<CreateSetScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<_CardEntry> _cards = [];
  List<Folder> _folders = [];
  String? _selectedFolderId;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.editSetId != null) {
      _loadExistingSet();
    } else {
      // Start with 2 empty cards
      _cards.add(_CardEntry());
      _cards.add(_CardEntry());
    }
    _loadFolders();
  }

  void _loadFolders() {
    _folders = context.read<StorageService>().getAllFolders();
  }

  void _loadExistingSet() {
    final set = context.read<StorageService>().getSet(widget.editSetId!);
    if (set != null) {
      _isEditing = true;
      _titleController.text = set.title;
      _titleController.text = set.title;
      _descriptionController.text = set.description ?? '';
      _selectedFolderId = set.folderId;
      for (final card in set.cards) {
        _cards.add(_CardEntry(
          id: card.id,
          term: card.term,
          definition: card.definition,
          imageUrl: card.imageUrl,
        ));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final card in _cards) {
      card.termController.dispose();
      card.definitionController.dispose();
      card.imageUrlController.dispose();
    }
    super.dispose();
  }

  void _addCard() {
    setState(() {
      _cards.add(_CardEntry());
    });
  }

  void _removeCard(int index) {
    if (_cards.length > 2) {
      setState(() {
        _cards[index].termController.dispose();
        _cards[index].definitionController.dispose();
        _cards[index].imageUrlController.dispose();
        _cards.removeAt(index);
      });
    }
  }

  Future<void> _saveSet() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    // Filter out empty cards
    final validCards = _cards.where((c) {
      return c.termController.text.trim().isNotEmpty &&
          c.definitionController.text.trim().isNotEmpty;
    }).toList();

    if (validCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one card')),
      );
      return;
    }

    final now = DateTime.now();
    final flashcards = validCards.map((c) {
      return Flashcard(
        id: c.id ?? const Uuid().v4(),
        term: c.termController.text.trim(),
        definition: c.definitionController.text.trim(),
        imageUrl: c.imageUrlController.text.trim().isNotEmpty 
            ? c.imageUrlController.text.trim() 
            : null,
      );
    }).toList();

    final set = FlashcardSet(
      id: widget.editSetId ?? const Uuid().v4(),
      title: title,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      cards: flashcards,
      createdAt: _isEditing
          ? context.read<StorageService>().getSet(widget.editSetId!)?.createdAt ?? now
          : now,
      updatedAt: now,
      folderId: _selectedFolderId,
    );

    // Save locally
    final storage = context.read<StorageService>();
    final supabase = context.read<SupabaseService>();
    
    await storage.saveSet(set);
    await supabase.saveSet(set);

    // Update folder if assigned
    if (_selectedFolderId != null) {
      final folder = _folders.firstWhere((f) => f.id == _selectedFolderId);
      if (!folder.setIds.contains(set.id)) {
        folder.setIds.add(set.id);
        folder.updatedAt = DateTime.now();
        await storage.saveFolder(folder);
        await supabase.saveFolder(folder);
      }
    }

    if (mounted) {
      Navigator.of(context).pop(true);
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
        title: Text(_isEditing ? 'Edit set' : 'Create set'),
        actions: [
          TextButton(
            onPressed: _saveSet,
            child: Text(
              _isEditing ? 'Save' : 'Create',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Title and description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  style: Theme.of(context).textTheme.titleLarge,
                  decoration: InputDecoration(
                    hintText: 'Subject, chapter, unit...',
                    labelText: 'Title',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Add a description (optional)',
                    labelText: 'Description',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                if (_folders.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedFolderId,
                    decoration: InputDecoration(
                      labelText: 'Folder (Optional)',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      contentPadding: EdgeInsets.zero,
                    ),
                    items: _folders.map((folder) {
                      return DropdownMenuItem(
                        value: folder.id,
                        child: Text(folder.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFolderId = value;
                      });
                    },
                  ),
              ],
            ),
          ),

          // Cards list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _cards.length + 1,
              itemBuilder: (context, index) {
                if (index == _cards.length) {
                  // Add card button
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: OutlinedButton.icon(
                      onPressed: _addCard,
                      icon: const Icon(Icons.add),
                      label: const Text('Add card'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  );
                }

                return _buildCardEditor(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardEditor(int index) {
    final card = _cards[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header with card number and delete
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_cards.length > 2)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _removeCard(index),
                    color: AppColors.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // Term input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: card.termController,
              decoration: const InputDecoration(
                hintText: 'Term',
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.surface),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.surface),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                filled: false,
              ),
            ),
          ),

          // Definition input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: card.definitionController,
              decoration: const InputDecoration(
                hintText: 'Definition',
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.surface),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.surface),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                filled: false,
              ),
            ),
          ),

          // Image URL input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: card.imageUrlController,
              decoration: InputDecoration(
                hintText: 'Image URL (optional)',
                prefixIcon: const Icon(Icons.image_outlined, size: 20),
                border: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.surface),
                ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.surface),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                filled: false,
                suffixIcon: card.imageUrlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => card.imageUrlController.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Image preview
          if (card.imageUrlController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  card.imageUrlController.text,
                  height: 80,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 60,
                    color: AppColors.surface,
                    child: const Center(
                      child: Icon(Icons.broken_image, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Helper class to manage card input
class _CardEntry {
  final String? id;
  final TextEditingController termController;
  final TextEditingController definitionController;
  final TextEditingController imageUrlController;

  _CardEntry({
    this.id,
    String? term,
    String? definition,
    String? imageUrl,
  })  : termController = TextEditingController(text: term),
        definitionController = TextEditingController(text: definition),
        imageUrlController = TextEditingController(text: imageUrl);
}
