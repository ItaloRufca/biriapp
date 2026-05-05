import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';
import '../data/carteados_list.dart';

class BggService {
  // Using the JSON API which is more reliable and avoids 401 errors
  static const String _baseUrl = 'https://api.geekdo.com/api';
  static const String _proxyUrl = 'https://corsproxy.io/?';

  Future<List<Game>> fetchTopRankedGames() async {
    final List<Game> rankedGames = [];
    int page = 1;
    int currentRank = 1; // Keep track of global rank

    try {
      // Search deeper (up to 50 pages = 5000 games) to find 50 carteados
      while (rankedGames.length < 50 && page <= 50) {
        var urlString = 'https://boardgamegeek.com/browse/boardgame/page/$page';
        if (kIsWeb) {
          urlString = '$_proxyUrl${Uri.encodeComponent(urlString)}';
        }

        final response = await http.get(
          Uri.parse(urlString),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html',
          },
        );

        if (response.statusCode == 200) {
          // Regex to capture ID and Name from the link
          // Example: <a href="/boardgame/174430/gloomhaven" ...>Gloomhaven</a>
          // We look for the specific structure in the browse table
          final regex = RegExp(
            r'href="/boardgame/(\d+)/[^"]*"[^>]*>([^<]+)</a>',
          );
          final matches = regex.allMatches(response.body);

          for (final match in matches) {
            final id = match.group(1)!;
            final name = match.group(2)!;

            // Only add if it's in our carteados list
            if (carteadosIds.contains(id)) {
              // Check if we already added this ID (browse page might have duplicates or we might re-scan?)
              // actually pages are distinct.
              if (!rankedGames.any((g) => g.id == id)) {
                rankedGames.add(
                  Game(
                    id: id,
                    name: name,
                    rank: currentRank.toString(),
                    imageUrl: null, // Will be fetched later
                  ),
                );
              }
            }
            currentRank++; // Increment global rank counter for every game found

            if (rankedGames.length >= 50) break;
          }

          page++;
        } else {
          debugPrint('Failed to load rank page $page: ${response.statusCode}');
          break;
        }
      }

      if (rankedGames.isEmpty) return [];

      // Fetch details (images, etc) for the found ranked games
      // We do this in parallel
      final detailedGames = await Future.wait(
        rankedGames.map((game) => _fetchGameDetails(game)),
      );

      return detailedGames.whereType<Game>().toList();
    } catch (e) {
      debugPrint('Error fetching top ranked games: $e');
      return [];
    }
  }

  Future<List<Game>> searchGames(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      // Step 1: Search via HTML scraping (Bypassing XML API block)
      var searchUrl =
          'https://boardgamegeek.com/search/boardgame?q=${Uri.encodeComponent(query)}';
      if (kIsWeb) {
        searchUrl = '$_proxyUrl${Uri.encodeComponent(searchUrl)}';
      }

      final searchResponse = await http.get(
        Uri.parse(searchUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        },
      );

      if (searchResponse.statusCode != 200) {
        throw Exception('Failed to search games: ${searchResponse.statusCode}');
      }

      // Parse HTML to get IDs and Names
      final games = _parseGamesFromHtml(searchResponse.body);

      if (games.isEmpty) return [];

      // Filter by carteados list
      final filteredGames = games
          .where((g) => carteadosIds.contains(g.id))
          .toList();

      if (filteredGames.isEmpty) return [];

      // Step 2: Fetch details for top 10 items (or all filtered if less)
      final topGames = filteredGames.take(10).toList();
      final detailedGames = await Future.wait(
        topGames.map((game) => _fetchGameDetails(game)),
      );

      return detailedGames.whereType<Game>().toList();
    } catch (e) {
      debugPrint('Error searching games: $e');
      rethrow;
    }
  }

  List<Game> _parseGamesFromHtml(String html) {
    final List<Game> games = [];
    // Regex to find game links: /boardgame/12345/game-name
    // and the name inside the link tag. Handles extra attributes like class='primary'
    final regex = RegExp(r'href="/boardgame/(\d+)/[^"]+"[^>]*>([^<]+)</a>');
    final matches = regex.allMatches(html);

    final seenIds = <String>{};

    for (final match in matches) {
      final id = match.group(1);
      final name = match.group(2);

      if (id != null && name != null && !seenIds.contains(id)) {
        seenIds.add(id);
        games.add(
          Game(
            id: id,
            name: name,
            imageUrl: null, // Will be fetched later
            rank: null,
            yearPublished: null,
          ),
        );
      }
    }
    return games;
  }

  Future<Game?> fetchGameDetails(String gameId) async {
    // Create a dummy game object to reuse existing logic
    final basicGame = Game(id: gameId, name: '', imageUrl: null);
    return _fetchGameDetails(basicGame);
  }

  Future<Game?> _fetchGameDetails(Game basicGame) async {
    try {
      var url =
          'https://api.geekdo.com/api/geekitems?objectid=${basicGame.id}&objecttype=thing';
      if (kIsWeb) {
        url = '$_proxyUrl${Uri.encodeComponent(url)}';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('item')) {
          final item = jsonData['item'];

          // Extract image
          String? imageUrl;
          if (item['images'] != null && item['images']['original'] != null) {
            imageUrl = item['images']['original'];
          } else if (item['imageurl'] != null) {
            imageUrl = item['imageurl'];
          }

          if (kIsWeb && imageUrl != null) {
            imageUrl = 'https://corsproxy.io/?${Uri.encodeComponent(imageUrl)}';
          }

          return Game(
            id: basicGame.id,
            name:
                item['name'] ?? basicGame.name, // Use fetched name if available
            imageUrl: imageUrl,
            rank: basicGame.rank, // Keep the rank we scraped
            yearPublished: item['yearpublished']?.toString(),
            description: item['description'],
            minPlayers: item['minplayers']?.toString(),
            maxPlayers: item['maxplayers']?.toString(),
            playingTime: item['playingtime']?.toString(),
          );
        }
      }
      return basicGame; // Return basic info if details fail
    } catch (e) {
      debugPrint('Error fetching details for ${basicGame.name}: $e');
      return basicGame;
    }
  }
}
