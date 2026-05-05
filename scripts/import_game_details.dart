import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:supabase/supabase.dart';

void main() async {
  // 1. Load Environment Variables
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('Error: .env file not found.');
    return;
  }

  final envLines = await envFile.readAsLines();
  String? supabaseUrl;
  String? supabaseKey;

  for (final line in envLines) {
    if (line.startsWith('SUPABASE_URL=')) {
      supabaseUrl = line.split('=')[1].trim();
    } else if (line.startsWith('SUPABASE_ANON_KEY=')) {
      supabaseKey = line.split('=')[1].trim();
    }
  }

  if (supabaseUrl == null || supabaseKey == null) {
    print('Error: SUPABASE_URL or SUPABASE_ANON_KEY not found in .env');
    return;
  }

  // 2. Initialize Supabase Client
  final client = SupabaseClient(supabaseUrl, supabaseKey);

  // 3. Read CSV
  final csvFile = File('scripts/carteados.csv');
  if (!csvFile.existsSync()) {
    print('Error: scripts/carteados.csv not found.');
    return;
  }

  print('Reading CSV file...');
  final input = await csvFile.readAsString();
  print('File length: ${input.length}');

  // Detect EOL
  String? eol;
  if (input.contains('\r\n')) {
    eol = '\r\n';
    print('Detected EOL: CRLF (\\r\\n)');
  } else if (input.contains('\n')) {
    eol = '\n';
    print('Detected EOL: LF (\\n)');
  } else if (input.contains('\r')) {
    eol = '\r';
    print('Detected EOL: CR (\\r)');
  }

  // Convert
  final fields = CsvToListConverter(eol: eol).convert(input);
  print('Parsed rows: ${fields.length}');

  if (fields.isEmpty) {
    print('Error: No rows parsed.');
    return;
  }

  int updatedCount = 0;
  int errorCount = 0;
  int skippedCount = 0;

  // Skip header
  for (var i = 1; i < fields.length; i++) {
    final row = fields[i];
    if (row.length < 8) continue;

    final name = row[0].toString();
    final category = row[5].toString().trim(); // Categoria_Display
    final imageUrl = row[6].toString();
    final bggUrl = row[7].toString();
    final playersRange = row[1].toString();

    // Extract ID from BGG URL
    // https://boardgamegeek.com/boardgame/103651/23
    final uri = Uri.tryParse(bggUrl);
    if (uri == null) continue;

    final segments = uri.pathSegments;
    String? gameId;
    // pathSegments usually: [boardgame, 103651, 23]
    if (segments.contains('boardgame')) {
      final index = segments.indexOf('boardgame');
      if (index + 1 < segments.length) {
        gameId = segments[index + 1];
      }
    }

    if (name.toLowerCase().contains('crew') ||
        name.toLowerCase().contains('seas') ||
        name.toLowerCase().contains('let me off')) {
      print('Found: $name (ID: $gameId)');
      print('  Image: $imageUrl');
      print('  Category: $category');
      print('  Players: $playersRange');
    }

    if (gameId != null) {
      try {
        // Check if game exists
        final response = await client
            .from('game_stats')
            .select()
            .eq('game_id', gameId)
            .maybeSingle();

        if (response != null) {
          // Update existing
          await client
              .from('game_stats')
              .update({
                'players_range': playersRange,
                'category': category,
                'name': name,
                'image_url': imageUrl,
              })
              .eq('game_id', gameId);
          updatedCount++;
        } else {
          // Insert new
          await client.from('game_stats').insert({
            'game_id': gameId,
            'name': name,
            'image_url': imageUrl,
            'players_range': playersRange,
            'category': category,
            'average': 0,
            'count': 0,
          });
          updatedCount++;
        }
      } catch (e) {
        print('Error processing game $gameId: $e');
        errorCount++;
      }
    }
  }

  print(
    'Final Stats - Total: ${fields.length}, Updated/Inserted: $updatedCount, Errors: $errorCount',
  );
}
