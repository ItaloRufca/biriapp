import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../models/game_model.dart';
import '../screens/game_details_screen.dart';

enum GameCardLayout { list, grid }

class GameCard extends StatelessWidget {
  final Game game;
  final GameCardLayout layout;
  final bool showRank;
  final VoidCallback? onReturn;

  const GameCard({
    super.key,
    required this.game,
    this.layout = GameCardLayout.list,
    this.showRank = true,
    this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameDetailsScreen(game: game),
          ),
        );
        onReturn?.call();
      },
      child: layout == GameCardLayout.list
          ? _buildListLayout(context)
          : _buildGridLayout(context),
    );
  }

  Widget _buildListLayout(BuildContext context) {
    final rank = int.tryParse(game.rank ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showRank && rank != null) ...[
            Container(
              constraints: const BoxConstraints(minWidth: 30),
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank <= 3
                    ? const Color(0xFFE94560)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '#$rank',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 60, height: 60, child: _buildImage()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (game.category != null)
                  Text(
                    game.category!.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE94560),
                      letterSpacing: 0.5,
                    ),
                  ),
                Text(
                  game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (game.playersRange != null) ...[
                      const Icon(
                        Icons.people_outline,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        game.playersRange!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (game.communityRating != null) ...[
                      Text(
                        _getRatingEmoji(game.communityRating!),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${game.communityRatingCount})',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
                if (game.userRating != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          'Sua nota: ${_getRatingEmoji(game.userRating!)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildGridLayout(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: _buildImage(),
                ),
                if (game.userRating != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 10, color: Colors.white),
                          const SizedBox(width: 2),
                          Text(
                            _getRatingEmoji(game.userRating!),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (game.category != null)
                  Text(
                    game.category!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE94560),
                    ),
                  ),
                Text(
                  game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                if (game.playersRange != null)
                  Text(
                    game.playersRange!,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (game.communityRating != null) ...[
                      Text(
                        _getRatingEmoji(game.communityRating!),
                        style: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${game.communityRatingCount})',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ] else
                      Text(
                        '-',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (game.imageUrl == null || game.imageUrl!.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_not_supported, color: Colors.grey),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _fetchImage(game.imageUrl!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.grey,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
          },
        );
      },
    );
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

  String _getRatingEmoji(double rating) {
    if (rating >= 4.25) return '⭐⭐⭐';
    if (rating >= 3.25) return '⭐⭐';
    if (rating >= 2.5) return '⭐';
    if (rating >= 2.0) return '👍';
    return '💩';
  }
}
