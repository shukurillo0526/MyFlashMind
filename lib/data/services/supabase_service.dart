import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flashcard.dart';
import '../models/flashcard_set.dart';
import '../models/folder.dart';

/// Service for syncing data with Supabase cloud database
class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  /// Get current user ID
  String? get userId => _client.auth.currentUser?.id;

  /// Check if user is authenticated
  bool get isAuthenticated => _client.auth.currentUser != null;

  // ============ AUTH ============

  /// Sign up with email and password
  Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get auth state stream
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ============ REALTIME ============

  /// Subscribe to changes
  Stream<List<Map<String, dynamic>>> subscribeToChanges() {
    final sets = _client
        .from('flashcard_sets')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId ?? '')
        .order('updated_at');

    return sets;
  }

  // ============ FLASHCARD SETS ============

  /// Fetch all sets for current user
  Future<List<FlashcardSet>> fetchAllSets() async {
    if (!isAuthenticated) return [];

    final response = await _client
        .from('flashcard_sets')
        .select()
        .eq('user_id', userId!)
        .order('updated_at', ascending: false);

    final sets = <FlashcardSet>[];
    for (final row in response) {
      final cards = await _fetchCardsForSet(row['id']);
      sets.add(_setFromRow(row, cards));
    }
    return sets;
  }

  /// Fetch cards for a set
  Future<List<Flashcard>> _fetchCardsForSet(String setId) async {
    final response = await _client
        .from('flashcards')
        .select()
        .eq('set_id', setId)
        .order('position');

    return response.map<Flashcard>((row) => _cardFromRow(row)).toList();
  }

  /// Save a flashcard set (insert or update)
  Future<void> saveSet(FlashcardSet set) async {
    if (!isAuthenticated) return;

    // Upsert the set
    await _client.from('flashcard_sets').upsert({
      'id': set.id,
      'user_id': userId,
      'title': set.title,
      'description': set.description,
      'term_language': set.termLanguage,
      'definition_language': set.definitionLanguage,
      'folder_id': set.folderId,
      'cards_known': set.cardsKnown,
      'cards_learning': set.cardsLearning,
      'last_studied': set.lastStudied?.toIso8601String(),
      'created_at': set.createdAt.toIso8601String(),
      'updated_at': set.updatedAt.toIso8601String(),
    });

    // Delete existing cards and re-insert
    await _client.from('flashcards').delete().eq('set_id', set.id);

    // Insert cards with position
    // Insert cards with position (Batch Insert)
    if (set.cards.isNotEmpty) {
      final cardsData = List<Map<String, dynamic>>.generate(set.cards.length, (i) {
        final card = set.cards[i];
        return {
          'id': card.id,
          'set_id': set.id,
          'term': card.term,
          'definition': card.definition,
          'term_language': card.termLanguage,
          'definition_language': card.definitionLanguage,
          'image_url': card.imageUrl,
          'times_correct': card.timesCorrect,
          'times_incorrect': card.timesIncorrect,
          'last_studied': card.lastStudied?.toIso8601String(),
          'is_starred': card.isStarred,
          'easiness_factor': card.easinessFactor,
          'interval': card.interval,
          'repetitions': card.repetitions,
          'next_review_date': card.nextReviewDate?.toIso8601String(),
          'position': i,
        };
      });
      
      await _client.from('flashcards').insert(cardsData);
    }
  }

  /// Delete a flashcard set
  Future<void> deleteSet(String setId) async {
    if (!isAuthenticated) return;
    await _client.from('flashcard_sets').delete().eq('id', setId);
  }

  // ============ FOLDERS ============

  /// Fetch all folders for current user
  Future<List<Folder>> fetchAllFolders() async {
    if (!isAuthenticated) return [];

    final response = await _client
        .from('folders')
        .select()
        .eq('user_id', userId!)
        .order('created_at', ascending: false);

    return response.map<Folder>((row) => _folderFromRow(row)).toList();
  }

  /// Save a folder
  Future<void> saveFolder(Folder folder) async {
    if (!isAuthenticated) return;

    await _client.from('folders').upsert({
      'id': folder.id,
      'user_id': userId,
      'name': folder.name,
      'description': folder.description,
      'created_at': folder.createdAt.toIso8601String(),
      'updated_at': folder.updatedAt.toIso8601String(),
    });
  }

  /// Delete a folder
  Future<void> deleteFolder(String folderId) async {
    if (!isAuthenticated) return;
    await _client.from('folders').delete().eq('id', folderId);
  }

  // ============ HELPERS ============

  FlashcardSet _setFromRow(Map<String, dynamic> row, List<Flashcard> cards) {
    return FlashcardSet(
      id: row['id'],
      title: row['title'],
      description: row['description'],
      cards: cards,
      termLanguage: row['term_language'],
      definitionLanguage: row['definition_language'],
      folderId: row['folder_id'],
      cardsKnown: row['cards_known'] ?? 0,
      cardsLearning: row['cards_learning'] ?? 0,
      lastStudied: row['last_studied'] != null 
          ? DateTime.parse(row['last_studied']) 
          : null,
      createdAt: DateTime.parse(row['created_at']),
      updatedAt: DateTime.parse(row['updated_at']),
    );
  }

  Flashcard _cardFromRow(Map<String, dynamic> row) {
    return Flashcard(
      id: row['id'],
      term: row['term'],
      definition: row['definition'],
      termLanguage: row['term_language'],
      definitionLanguage: row['definition_language'],
      imageUrl: row['image_url'],
      timesCorrect: row['times_correct'] ?? 0,
      timesIncorrect: row['times_incorrect'] ?? 0,
      lastStudied: row['last_studied'] != null 
          ? DateTime.parse(row['last_studied']) 
          : null,
      isStarred: row['is_starred'] ?? false,
    );
  }

  Folder _folderFromRow(Map<String, dynamic> row) {
    return Folder(
      id: row['id'],
      name: row['name'],
      description: row['description'],
      createdAt: DateTime.parse(row['created_at']),
      updatedAt: DateTime.parse(row['updated_at']),
    );
  }
}
