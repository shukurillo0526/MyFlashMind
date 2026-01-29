import 'package:hive_flutter/hive_flutter.dart';
import '../models/flashcard.dart';
import '../models/flashcard_set.dart';
import '../models/folder.dart';

/// Service for handling local storage with Hive
/// Uses IndexedDB on web platform automatically
class StorageService {
  static const String _setsBoxName = 'flashcard_sets';
  static const String _foldersBoxName = 'folders';

  late Box<FlashcardSet> _setsBox;
  late Box<Folder> _foldersBox;

  bool _initialized = false;

  /// Initialize Hive and open boxes
  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FlashcardAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(FlashcardSetAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(FolderAdapter());
    }

    // Open boxes
    _setsBox = await Hive.openBox<FlashcardSet>(_setsBoxName);
    _foldersBox = await Hive.openBox<Folder>(_foldersBoxName);

    _initialized = true;
  }

  // ============ Flashcard Sets ============

  /// Get all flashcard sets
  List<FlashcardSet> getAllSets() {
    return _setsBox.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Get a specific flashcard set by ID
  FlashcardSet? getSet(String id) {
    return _setsBox.get(id);
  }

  /// Get recently studied sets
  List<FlashcardSet> getRecentSets({int limit = 5}) {
    final sets = getAllSets()
        .where((s) => s.lastStudied != null)
        .toList()
      ..sort((a, b) => b.lastStudied!.compareTo(a.lastStudied!));
    return sets.take(limit).toList();
  }

  /// Get sets in a specific folder
  List<FlashcardSet> getSetsInFolder(String folderId) {
    return getAllSets().where((s) => s.folderId == folderId).toList();
  }

  /// Save a flashcard set
  Future<void> saveSet(FlashcardSet set) async {
    await _setsBox.put(set.id, set);
  }

  /// Delete a flashcard set
  Future<void> deleteSet(String id) async {
    await _setsBox.delete(id);
  }

  /// Search sets by title
  List<FlashcardSet> searchSets(String query) {
    final lowerQuery = query.toLowerCase();
    return getAllSets().where((s) {
      return s.title.toLowerCase().contains(lowerQuery) ||
          (s.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // ============ Folders ============

  /// Get all folders
  List<Folder> getAllFolders() {
    return _foldersBox.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Get a specific folder by ID
  Folder? getFolder(String id) {
    return _foldersBox.get(id);
  }

  /// Save a folder
  Future<void> saveFolder(Folder folder) async {
    await _foldersBox.put(folder.id, folder);
  }

  /// Delete a folder
  Future<void> deleteFolder(String id) async {
    await _foldersBox.delete(id);
  }

  // ============ Data Export/Import ============

  /// Export all data as JSON map
  Map<String, dynamic> exportAllData() {
    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'flashcardSets': getAllSets().map((s) => s.toJson()).toList(),
      'folders': getAllFolders().map((f) => f.toJson()).toList(),
    };
  }

  /// Import data from JSON map
  Future<void> importData(Map<String, dynamic> data) async {
    // Import folders first
    final foldersJson = data['folders'] as List<dynamic>?;
    if (foldersJson != null) {
      for (final folderJson in foldersJson) {
        final folder = Folder.fromJson(folderJson as Map<String, dynamic>);
        await saveFolder(folder);
      }
    }

    // Import sets
    final setsJson = data['flashcardSets'] as List<dynamic>?;
    if (setsJson != null) {
      for (final setJson in setsJson) {
        final set = FlashcardSet.fromJson(setJson as Map<String, dynamic>);
        await saveSet(set);
      }
    }
  }

  /// Clear all data
  Future<void> clearAllData() async {
    await _setsBox.clear();
    await _foldersBox.clear();
  }
}
