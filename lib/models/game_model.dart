import 'package:xml/xml.dart';
import 'package:flutter/foundation.dart';

class Game {
  final String id;
  final String name;
  final String? yearPublished;
  final String? imageUrl;
  final String? rank;
  final String? description;
  final String? minPlayers;
  final String? maxPlayers;
  final String? playingTime;
  final double? communityRating;
  final int? communityRatingCount;
  final String? playersRange;
  final String? category;
  final double? userRating;

  Game({
    required this.id,
    required this.name,
    this.yearPublished,
    this.imageUrl,
    this.rank,
    this.description,
    this.minPlayers,
    this.maxPlayers,
    this.playingTime,
    this.communityRating,
    this.communityRatingCount,
    this.playersRange,
    this.category,
    this.userRating,
  });

  factory Game.fromXml(XmlElement element) {
    final id = element.getAttribute('id') ?? '';
    final name =
        element.findElements('name').firstOrNull?.getAttribute('value') ??
        'Unknown';
    final yearPublished = element
        .findElements('yearpublished')
        .firstOrNull
        ?.getAttribute('value');
    final imageUrl = element
        .findElements('thumbnail')
        .firstOrNull
        ?.getAttribute('value');

    // XML parsing for description/stats omitted as we focus on JSON
    return Game(
      id: id,
      name: name,
      yearPublished: yearPublished,
      imageUrl: imageUrl,
    );
  }

  factory Game.fromJson(Map<String, dynamic> json) {
    String? img = json['imageurl'];

    // Try to get a higher resolution image
    if (json['images'] != null && json['images'] is Map) {
      final images = json['images'];
      if (images['mediacard'] != null) {
        // Prefer @2x (high res) if available, otherwise standard src
        img = images['mediacard']['src@2x'] ?? images['mediacard']['src'];
      }
    }

    return Game(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown',
      yearPublished: json['yearpublished']?.toString(),
      imageUrl: img,
      rank: json['rank']?.toString(),
      description: json['description'],
      minPlayers: json['minplayers']?.toString(),
      maxPlayers: json['maxplayers']?.toString(),
      playingTime: json['playingtime']?.toString(),
      communityRating: (json['communityRating'] as num?)?.toDouble(),
      communityRatingCount: (json['communityRatingCount'] as num?)?.toInt(),
      playersRange: json['playersRange'] as String?,
      category: json['category'] as String?,
      userRating: (json['userRating'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'rank': rank,
      'yearPublished': yearPublished,
      'description': description,
      'minPlayers': minPlayers,
      'maxPlayers': maxPlayers,
      'playingTime': playingTime,
      'communityRating': communityRating,
      'communityRatingCount': communityRatingCount,
      'playersRange': playersRange,
      'category': category,
      'userRating': userRating,
    };
  }

  Game copyWith({
    String? id,
    String? name,
    String? yearPublished,
    String? imageUrl,
    String? rank,
    String? description,
    String? minPlayers,
    String? maxPlayers,
    String? playingTime,
    double? communityRating,
    int? communityRatingCount,
    String? playersRange,
    String? category,
    double? userRating,
  }) {
    return Game(
      id: id ?? this.id,
      name: name ?? this.name,
      yearPublished: yearPublished ?? this.yearPublished,
      imageUrl: imageUrl ?? this.imageUrl,
      rank: rank ?? this.rank,
      description: description ?? this.description,
      minPlayers: minPlayers ?? this.minPlayers,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      playingTime: playingTime ?? this.playingTime,
      communityRating: communityRating ?? this.communityRating,
      communityRatingCount: communityRatingCount ?? this.communityRatingCount,
      playersRange: playersRange ?? this.playersRange,
      category: category ?? this.category,
      userRating: userRating ?? this.userRating,
    );
  }
}
