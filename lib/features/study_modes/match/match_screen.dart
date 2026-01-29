import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/flashcard.dart';
import '../../../data/models/flashcard_set.dart';
import '../../../data/services/storage_service.dart';

/// Match game - pair terms with definitions against the clock
class MatchScreen extends StatefulWidget {
  final String setId;

  const MatchScreen({super.key, required this.setId});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with SingleTickerProviderStateMixin {
  FlashcardSet? _set;
  List<_MatchTile> _tiles = [];
  _MatchTile? _selectedTile;
  bool _isComplete = false;
  
  // Timer
  late Stopwatch _stopwatch;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  
  // Animation
  late AnimationController _shakeController;
  
  // Game config
  static const int _maxCards = 6;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadSetAndStart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _loadSetAndStart() {
    final set = context.read<StorageService>().getSet(widget.setId);
    if (set != null) {
      setState(() {
        _set = set;
        _generateTiles();
        _startTimer();
      });
    }
  }

  void _generateTiles() {
    if (_set == null) return;
    
    final cards = List<Flashcard>.from(_set!.cards)..shuffle();
    final selectedCards = cards.take(_maxCards).toList();
    
    _tiles = [];
    
    // Create term and definition tiles
    for (final card in selectedCards) {
      _tiles.add(_MatchTile(
        id: '${card.id}_term',
        cardId: card.id,
        text: card.term,
        isTerm: true,
      ));
      _tiles.add(_MatchTile(
        id: '${card.id}_def',
        cardId: card.id,
        text: card.definition,
        isTerm: false,
      ));
    }
    
    _tiles.shuffle();
  }

  void _startTimer() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _elapsed = _stopwatch.elapsed;
      });
    });
  }

  void _onTileTap(_MatchTile tile) {
    if (tile.isMatched) return;
    
    if (_selectedTile == null) {
      // First selection
      setState(() {
        _selectedTile = tile;
        tile.isSelected = true;
      });
    } else if (_selectedTile!.id == tile.id) {
      // Deselect same tile
      setState(() {
        _selectedTile!.isSelected = false;
        _selectedTile = null;
      });
    } else if (_selectedTile!.isTerm == tile.isTerm) {
      // Can't match two terms or two definitions
      _shakeController.forward().then((_) {
        _shakeController.reset();
      });
      setState(() {
        _selectedTile!.isSelected = false;
        _selectedTile = tile;
        tile.isSelected = true;
      });
    } else {
      // Check for match
      if (_selectedTile!.cardId == tile.cardId) {
        // Match found!
        setState(() {
          _selectedTile!.isMatched = true;
          _selectedTile!.isSelected = false;
          tile.isMatched = true;
          _selectedTile = null;
        });
        
        // Check if game is complete
        if (_tiles.every((t) => t.isMatched)) {
          _stopwatch.stop();
          _timer?.cancel();
          setState(() => _isComplete = true);
        }
      } else {
        // No match - shake and reset
        _shakeController.forward().then((_) {
          _shakeController.reset();
        });
        setState(() {
          _selectedTile!.isSelected = false;
          tile.isSelected = true;
          _selectedTile = tile;
        });
      }
    }
  }

  void _restart() {
    setState(() {
      _isComplete = false;
      _elapsed = Duration.zero;
      _selectedTile = null;
      _generateTiles();
    });
    _stopwatch.reset();
    _startTimer();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final tenths = (d.inMilliseconds % 1000) ~/ 100;
    
    if (minutes > 0) {
      return '$minutes:${seconds.toString().padLeft(2, '0')}.$tenths';
    }
    return '$seconds.$tenths';
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
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Match'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                _formatDuration(_elapsed),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'monospace',
                    ),
              ),
            ),
          ),
        ],
      ),
      body: _isComplete ? _buildCompleteView() : _buildGameView(),
    );
  }

  Widget _buildGameView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.2,
        ),
        itemCount: _tiles.length,
        itemBuilder: (context, index) {
          final tile = _tiles[index];
          return _buildTile(tile);
        },
      ),
    );
  }

  Widget _buildTile(_MatchTile tile) {
    Color bgColor = AppColors.cardBackground;
    Color borderColor = Colors.transparent;
    double opacity = 1.0;
    
    if (tile.isMatched) {
      opacity = 0.0; // Fade out matched tiles
    } else if (tile.isSelected) {
      borderColor = tile.isTerm ? AppColors.primary : AppColors.secondary;
      bgColor = tile.isTerm
          ? AppColors.primary.withOpacity(0.2)
          : AppColors.secondary.withOpacity(0.2);
    }
    
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: opacity,
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          double offset = 0;
          if (tile.isSelected && _shakeController.isAnimating) {
            offset = sin(_shakeController.value * 3 * pi) * 5;
          }
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: GestureDetector(
          onTap: tile.isMatched ? null : () => _onTileTap(tile),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: borderColor != Colors.transparent
                  ? Border.all(color: borderColor, width: 2)
                  : null,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  tile.text,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: const Icon(
                Icons.timer,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            
            Text(
              _formatDuration(_elapsed),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            
            Text(
              'Nice work!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _restart,
                child: const Text('Play again'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchTile {
  final String id;
  final String cardId;
  final String text;
  final bool isTerm;
  bool isSelected;
  bool isMatched;

  _MatchTile({
    required this.id,
    required this.cardId,
    required this.text,
    required this.isTerm,
    this.isSelected = false,
    this.isMatched = false,
  });
}
