import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  // IDs: Uno (2223), Azul (230802)
  final ids = ['2223', '230802'];

  for (final id in ids) {
    print('\n--- Fetching Data for ID: $id ---');
    final url =
        'https://api.geekdo.com/api/geekitems?objectid=$id&objecttype=thing';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final item = data['item'];
        print('Name: ${item['name']}');

        // Check links for categories/families
        final links = item['links'];
        print('Links type: ${links.runtimeType}');

        if (links is List) {
          print('Categories:');
          links.where((l) => l['rel'] == 'boardgamecategory').forEach((l) {
            print(' - ${l['name']} (ID: ${l['objectid']})');
          });

          print('Families:');
          links.where((l) => l['rel'] == 'boardgamefamily').forEach((l) {
            print(' - ${l['name']} (ID: ${l['objectid']})');
          });
        } else {
          print('Raw links: $links');
        }
      } else {
        print('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
