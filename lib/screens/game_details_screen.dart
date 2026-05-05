import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../models/game_model.dart';
import '../services/database_service.dart';
import '../services/bgg_service.dart';
import '../widgets/rating_dialog.dart';

class GameDetailsScreen extends StatefulWidget {
  final Game game;

  const GameDetailsScreen({super.key, required this.game});

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _inCollection = false;
  bool _inWishlist = false;
  int? _userRating;
  double? _averageRating;
  int _ratingCount = 0;
  bool _isLoading = true;

  late Game _game;

  @override
  void initState() {
    super.initState();
    _game = widget.game;
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      // 1. Fetch local status
      final results = await Future.wait([
        _dbService.isInCollection(widget.game.id),
        _dbService.isInWishlist(widget.game.id),
        _dbService.getRating(widget.game.id),
        _dbService.getAverageRating(widget.game.id),
      ]);

      // 2. Fetch fresh BGG data (Self-Healing)
      // We do this in parallel but don't block the UI for it immediately if we have local data
      // However, to show the image ASAP, we might want to wait or update state twice.
      // Let's update state with local data first.

      if (mounted) {
        setState(() {
          _inCollection = results[0] as bool;
          _inWishlist = results[1] as bool;
          _userRating = results[2] as int?;

          final avgData = results[3] as Map<String, dynamic>?;
          if (avgData != null) {
            _averageRating = (avgData['average_rating'] as num).toDouble();
            _ratingCount = avgData['rating_count'] as int;
          }
          _isLoading = false;
        });
      }

      // 3. Background Metadata Refresh
      BggService().fetchGameDetails(_game.id).then((freshGame) {
        if (freshGame != null && mounted) {
          // If we got a better image, update UI
          if (_game.imageUrl == null && freshGame.imageUrl != null) {
            setState(() {
              _game = freshGame;
            });
          }

          // Update DB if user has this item
          if (_inCollection || _inWishlist || _userRating != null) {
            _dbService.updateGameMetadata(freshGame);
          }
        }
      });
    } catch (e) {
      debugPrint('Error checking status: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleCollection() async {
    setState(() => _isLoading = true);
    try {
      await _dbService.toggleCollection(_game);
      await _checkStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _inCollection ? 'Adicionado à coleção!' : 'Removido da coleção.',
            ),
            backgroundColor: _inCollection ? Colors.green : Colors.grey,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling collection: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleWishlist() async {
    setState(() => _isLoading = true);
    try {
      await _dbService.toggleWishlist(_game);
      await _checkStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _inWishlist
                  ? 'Adicionado à lista de desejos!'
                  : 'Removido da lista de desejos.',
            ),
            backgroundColor: _inWishlist ? Colors.pink : Colors.grey,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling wishlist: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao atualizar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showRatingDialog() async {
    final rating = await showDialog<int>(
      context: context,
      builder: (context) => RatingDialog(initialRating: _userRating),
    );

    if (rating != null) {
      setState(() => _isLoading = true);
      try {
        if (rating == 0) {
          // Remove rating
          await _dbService.deleteRating(_game.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Avaliação removida.'),
                backgroundColor: Colors.grey,
              ),
            );
          }
        } else {
          // Set rating
          await _dbService.setRating(_game, rating);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Avaliação salva com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
        await _checkStatus();
      } catch (e) {
        debugPrint('Error saving rating: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar avaliação: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  String _stripHtml(String htmlString) {
    final RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString
        .replaceAll(exp, '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ');
  }

  String _getRatingEmoji(double rating) {
    int r = rating.round();
    switch (r) {
      case 1:
        return '💩';
      case 2:
        return '👍';
      case 3:
        return '⭐';
      case 4:
        return '⭐⭐';
      case 5:
        return '⭐⭐⭐';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _game.name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Image
            if (_game.imageUrl != null)
              Container(
                height: 300,
                decoration: BoxDecoration(color: Colors.grey.shade100),
                child: FutureBuilder<Uint8List?>(
                  future: _fetchImage(_game.imageUrl!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFE94560),
                        ),
                      );
                    }
                    if (snapshot.hasError || snapshot.data == null) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      );
                    }
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Year
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _game.name,
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (_game.yearPublished != null)
                              Text(
                                '(${_game.yearPublished})',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // User Rating Display
                      if (_userRating != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: Text(
                            'Sua nota: ${_getRatingEmoji(_userRating!.toDouble())}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Average Rating Display
                  if (_averageRating != null)
                    Row(
                      children: [
                        Text(
                          'Média da Comunidade: ',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          _getRatingEmoji(_averageRating!),
                          style: const TextStyle(fontSize: 18),
                        ),
                        Text(
                          ' (${_averageRating!.toStringAsFixed(1)})',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          ' • $_ratingCount votos',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _toggleCollection,
                          icon: Icon(
                            _inCollection ? Icons.check : Icons.add,
                            color: Colors.white,
                          ),
                          label: Text(
                            _inCollection ? 'Na Coleção' : 'Coleção',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _inCollection
                                ? Colors.green
                                : const Color(0xFFE94560),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _toggleWishlist,
                          icon: Icon(
                            _inWishlist
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _inWishlist
                                ? Colors.pink
                                : const Color(0xFFE94560),
                          ),
                          label: Text(
                            _inWishlist ? 'Desejado' : 'Desejos',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: _inWishlist
                                  ? Colors.pink
                                  : const Color(0xFFE94560),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: _inWishlist
                                  ? Colors.pink
                                  : const Color(0xFFE94560),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Rating Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _showRatingDialog,
                      icon: const Icon(Icons.star_outline, color: Colors.amber),
                      label: Text(
                        _userRating != null
                            ? 'Alterar Avaliação'
                            : 'Avaliar Jogo',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.amber.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Stats Row
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          Icons.people_outline,
                          'Jogadores',
                          '${_game.minPlayers ?? "?"} - ${_game.maxPlayers ?? "?"}',
                        ),
                        _buildVerticalDivider(),
                        _buildStatItem(
                          Icons.timer_outlined,
                          'Tempo',
                          '${_game.playingTime ?? "?"} min',
                        ),
                        _buildVerticalDivider(),
                        _buildStatItem(
                          Icons.emoji_events_outlined,
                          'Rank',
                          _game.rank != null && _game.rank != '0'
                              ? '#${_game.rank}'
                              : 'N/A',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'Sobre o Jogo',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _game.description != null
                        ? _stripHtml(_game.description!)
                        : 'Nenhuma descrição disponível.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFE94560), size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 40, width: 1, color: Colors.grey.shade300);
  }

  Future<Uint8List?> _fetchImage(String url) async {
    // Strategy 1: Direct fetch (Works on Mobile/Desktop, fails on Web if CORS blocked)
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      debugPrint('Direct fetch failed for $url: $e');
    }

    // Strategy 2: CORS Proxy (corsproxy.io)
    try {
      final proxyUrl = 'https://corsproxy.io/?${Uri.encodeComponent(url)}';
      final response = await http.get(Uri.parse(proxyUrl));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      debugPrint('Proxy 1 failed for $url: $e');
    }

    // Strategy 3: AllOrigins Proxy (Fallback)
    try {
      final proxyUrl =
          'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
      final response = await http.get(Uri.parse(proxyUrl));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      debugPrint('Proxy 2 failed for $url: $e');
    }

    return null;
  }
}
