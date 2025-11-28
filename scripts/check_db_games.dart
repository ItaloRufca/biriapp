import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final envFile = File('.env');
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

  final client = SupabaseClient(supabaseUrl!, supabaseKey!);

  final response = await client
      .from('game_stats')
      .select('game_id, name, image_url, players_range, category')
      .eq('game_id', 291453)
      .limit(1);

  final data = response as List<dynamic>;
  for (var item in data) {
    print('ID: ${item['game_id']} | Name: ${item['name']}');
    print('   URL: ${item['image_url']}');
  }
}
