import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_model.dart';

class DatabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId => _client.auth.currentUser!.id;

  Future<void> toggleCollection(Game game) async {
    final existing = await _client
        .from('user_items')
        .select()
        .eq('user_id', _userId)
        .eq('game_id', game.id)
        .maybeSingle();

    if (existing != null) {
      final currentStatus = existing['is_collection'] as bool? ?? false;
      await _client
          .from('user_items')
          .update({
            'is_collection': !currentStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', existing['id']);
    } else {
      await _client.from('user_items').insert({
        'user_id': _userId,
        'game_id': game.id,
        'name': game.name,
        'image_url': game.imageUrl,
        'is_collection': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> toggleWishlist(Game game) async {
    final existing = await _client
        .from('user_items')
        .select()
        .eq('user_id', _userId)
        .eq('game_id', game.id)
        .maybeSingle();

    if (existing != null) {
      final currentStatus = existing['is_wishlist'] as bool? ?? false;
      await _client
          .from('user_items')
          .update({
            'is_wishlist': !currentStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', existing['id']);
    } else {
      await _client.from('user_items').insert({
        'user_id': _userId,
        'game_id': game.id,
        'name': game.name,
        'image_url': game.imageUrl,
        'is_wishlist': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<bool> isInCollection(String gameId) async {
    final response = await _client
        .from('user_items')
        .select('is_collection')
        .eq('user_id', _userId)
        .eq('game_id', gameId)
        .maybeSingle();
    return response != null && (response['is_collection'] as bool? ?? false);
  }

  Future<bool> isInWishlist(String gameId) async {
    final response = await _client
        .from('user_items')
        .select('is_wishlist')
        .eq('user_id', _userId)
        .eq('game_id', gameId)
        .maybeSingle();
    return response != null && (response['is_wishlist'] as bool? ?? false);
  }

  Stream<List<Map<String, dynamic>>> getCollectionStream() {
    return _client
        .from('user_items')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map(
          (data) => data
              .where((item) => (item['is_collection'] as bool? ?? false))
              .toList(),
        );
  }

  Stream<List<Map<String, dynamic>>> getWishlistStream() {
    return _client
        .from('user_items')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map(
          (data) => data
              .where((item) => (item['is_wishlist'] as bool? ?? false))
              .toList(),
        );
  }

  Future<int?> getRating(String gameId) async {
    final response = await _client
        .from('user_items')
        .select('rating')
        .eq('user_id', _userId)
        .eq('game_id', gameId)
        .maybeSingle();

    if (response == null) return null;
    return response['rating'] as int?;
  }

  Future<void> setRating(Game game, int rating) async {
    await _client.from('user_items').upsert({
      'user_id': _userId,
      'game_id': game.id,
      'name': game.name,
      'image_url': game.imageUrl,
      'rating': rating,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,game_id');
  }

  Future<void> deleteRating(String gameId) async {
    // Instead of deleting, we set rating to null
    await _client
        .from('user_items')
        .update({'rating': null})
        .eq('user_id', _userId)
        .eq('game_id', gameId);
  }

  Future<Map<String, dynamic>?> getAverageRating(String gameId) async {
    final response = await _client
        .from('game_averages')
        .select()
        .eq('game_id', gameId)
        .maybeSingle();
    return response;
  }

  Future<void> updateGameMetadata(Game game) async {
    // Only update if we have meaningful data (e.g. image)
    if (game.imageUrl == null) return;

    await _client
        .from('user_items')
        .update({
          'name': game.name,
          'image_url': game.imageUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', _userId)
        .eq('game_id', game.id);
  }

  Future<void> clearGameImage(String gameId) async {
    await _client
        .from('user_items')
        .update({
          'image_url': null,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', _userId)
        .eq('game_id', gameId);
  }

  Stream<List<Map<String, dynamic>>> getRatedGamesStream() {
    return _client
        .from('user_items')
        .stream(primaryKey: ['id'])
        .order('rating', ascending: false)
        .map((data) => data.where((item) => item['rating'] != null).toList());
  }

  Future<Map<String, dynamic>> claimLegacyRatings(String accessCode) async {
    try {
      final response = await _client.rpc(
        'claim_legacy_ratings',
        params: {'p_access_code': accessCode},
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Erro ao resgatar: $e'};
    }
  }

  Future<void> resetAccount() async {
    await _client.rpc('reset_account');
  }

  Future<bool> hasClaimedLegacy() async {
    final response = await _client
        .from('profiles')
        .select('claimed_legacy')
        .eq('id', _userId)
        .maybeSingle();

    if (response == null) return false;
    return response['claimed_legacy'] as bool? ?? false;
  }

  Future<List<Game>> getAllUserItems() async {
    final response = await _client
        .from('user_items')
        .select()
        .eq('user_id', _userId);

    final List<dynamic> data = response as List<dynamic>;
    return data
        .map(
          (item) => Game(
            id: item['game_id'] as String,
            name: item['name'] as String? ?? 'Unknown',
            imageUrl: item['image_url'] as String?,
          ),
        )
        .toList();
  }

  // New method for Top Reviewers
  Future<List<Map<String, dynamic>>> getTopReviewers() async {
    try {
      final response = await _client.rpc('get_top_reviewers');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching top reviewers: $e');
      return [];
    }
  }

  // New method for BiriApp Ranking
  Future<List<Game>> getAppGamesRanking() async {
    try {
      // Fetch pre-calculated stats from the dedicated table
      final response = await _client
          .from('game_stats')
          .select()
          .order('average', ascending: false)
          .order('count', ascending: false);

      final List<dynamic> data = response as List<dynamic>;

      // Fetch user's ratings to populate userRating
      final userRatingsResponse = await _client
          .from('user_items')
          .select('game_id, rating')
          .eq('user_id', _userId)
          .not('rating', 'is', null);

      final Map<String, int> userRatings = {
        for (var item in userRatingsResponse as List<dynamic>)
          item['game_id'] as String: item['rating'] as int,
      };

      return data.asMap().entries.map((entry) {
        final rank = entry.key + 1;
        final item = entry.value;
        final gameId = item['game_id']?.toString() ?? '';
        final double average = (item['average'] as num?)?.toDouble() ?? 0.0;
        final int count = (item['count'] as num?)?.toInt() ?? 0;

        return Game(
          id: gameId,
          name: item['name'] as String? ?? 'Unknown',
          imageUrl: item['image_url'] as String?,
          rank: rank.toString(),
          communityRating: average,
          communityRatingCount: count,
          playersRange: item['players_range'] as String?,
          category: item['category'] as String?,
          userRating: userRatings[gameId]?.toDouble(),
          description: null, // Description is no longer used for stats
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching app ranking: $e');
      return [];
    }
  }
}
