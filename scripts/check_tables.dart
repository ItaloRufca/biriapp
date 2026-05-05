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

  try {
    print('Checking user_items...');
    await client.from('user_items').select().limit(1);
    print('user_items exists.');
  } catch (e) {
    print('user_items error: $e');
  }

  try {
    print('Checking user_ratings...');
    await client.from('user_ratings').select().limit(1);
    print('user_ratings exists.');
  } catch (e) {
    print('user_ratings error: $e');
  }
}
