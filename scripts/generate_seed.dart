import 'dart:io';
import 'dart:math';
import 'package:csv/csv.dart';

void main() async {
  final file = File('carteados.csv');
  if (!await file.exists()) {
    print('carteados.csv not found');
    return;
  }

  final content = await file.readAsString();
  final rows = const CsvToListConverter().convert(content, eol: '\n');

  if (rows.isEmpty) return;

  final headers = rows[0].map((e) => e.toString().trim()).toList();

  // Find BGG column index
  final bggIndex = headers.indexOf('BGG');
  if (bggIndex == -1) {
    print('BGG column not found');
    return;
  }

  // Known users from inspection:
  final users = [
    'Alex',
    'Bia',
    'Ênyo',
    'Fel',
    'Júlio',
    'Leo',
    'Narumi',
    'Torselli',
    'Fabrício',
    'Jorge O.',
    'Aline',
    'Alison',
    'Bruno Menezes',
    'Daniel',
    'Diego',
    'Fernando',
    'Gustavo',
    'Ju Palmares',
    'Kennedy',
    'Luís Francisco',
    'Marco Portugal',
    'Paty',
    'Paulo',
    'Renato',
    'Thom Bellotto',
    'Zanferrari',
    'Amábili',
    'André',
    'Arthur',
    'BH',
    'Bruno Carvalho',
    'Bruno Feitosa',
    'Bruno Fernandes',
    'Bruno Sia',
    'Flávio',
    'Ítalo',
    'Jorge F.',
    'Luís Tanaka',
    'Mauro',
    'Nan Te',
    'Perdomo',
    'Studart',
    'Targino',
    'Thom Cunha',
    'Walter',
    'Breno Carvalho',
    'Carla',
    'Eurico',
    'Fernanda',
    'Marcelo Lee',
    'Matias',
    'Mauricio I.',
    'Otávio',
    'Pablo',
    'Riva',
    'Lucas',
  ];

  // Dummies
  final dummies = List.generate(10, (i) => 'Dummy${i + 1}');

  final userIndices = <String, int>{};
  for (var user in users) {
    final index = headers.indexOf(user);
    if (index != -1) {
      userIndices[user] = index;
    }
  }

  final dummyIndices = <String, int>{};
  for (var dummy in dummies) {
    final index = headers.indexOf(dummy);
    if (index != -1) {
      dummyIndices[dummy] = index;
    }
  }

  // Generate random codes for users
  final random = Random();
  final userCodes = <String, String>{};

  for (var user in users) {
    String code;
    do {
      code = (random.nextInt(9000) + 1000).toString();
    } while (userCodes.containsValue(code));
    userCodes[user] = code;
  }

  final sb = StringBuffer();
  sb.writeln('-- Seed Legacy Users');
  for (var user in users) {
    sb.writeln(
      "INSERT INTO legacy_users (username, access_code) VALUES ('$user', '${userCodes[user]}') ON CONFLICT DO NOTHING;",
    );
  }

  sb.writeln('\n-- Seed Dummy Users');
  for (var dummy in dummies) {
    String code = (random.nextInt(9000) + 1000).toString();
    sb.writeln(
      "INSERT INTO legacy_users (username, access_code) VALUES ('$dummy', '$code') ON CONFLICT DO NOTHING;",
    );
  }

  sb.writeln('\n-- Seed Ratings');
  int ratingCount = 0;

  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.length <= bggIndex) continue;

    final bggUrl = row[bggIndex].toString();
    final gameId = _extractGameId(bggUrl);

    if (gameId == null) continue;

    // Extract Name and Image
    final name = row[0].toString().replaceAll(
      "'",
      "''",
    ); // Escape single quotes
    // Image is at index 6 based on inspection
    final imageUrl = row.length > 6 ? row[6].toString() : '';

    // Users
    for (var entry in userIndices.entries) {
      final user = entry.key;
      final index = entry.value;
      if (index >= row.length) continue;
      final rating = _parseRating(row[index]);
      if (rating != null) {
        sb.writeln(
          "INSERT INTO legacy_ratings (game_id, username, rating, name, image_url) VALUES ('$gameId', '$user', $rating, '$name', '$imageUrl');",
        );
        ratingCount++;
      }
    }

    // Dummies
    for (var entry in dummyIndices.entries) {
      final dummy = entry.key;
      final index = entry.value;
      if (index >= row.length) continue;
      final rating = _parseRating(row[index]);
      if (rating != null) {
        sb.writeln(
          "INSERT INTO legacy_ratings (game_id, username, rating, name, image_url) VALUES ('$gameId', '$dummy', $rating, '$name', '$imageUrl');",
        );
      }
    }
  }

  await File('seed_legacy.sql').writeAsString(sb.toString());
  print(
    'Generated seed_legacy.sql with users and ratings (Count: $ratingCount).',
  );
}

String? _extractGameId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  final segments = uri.pathSegments;
  // path is usually /boardgame/12345/name
  if (segments.contains('boardgame')) {
    final index = segments.indexOf('boardgame');
    if (index + 1 < segments.length) {
      return segments[index + 1];
    }
  }
  return null;
}

int? _parseRating(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  if (s.isEmpty) return null;
  final n = int.tryParse(s);
  if (n != null && n >= 1 && n <= 5) return n;
  return null;
}
