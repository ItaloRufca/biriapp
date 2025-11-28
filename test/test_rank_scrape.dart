import 'package:http/http.dart' as http;

Future<void> main() async {
  // Proxy needed for web, but for this dart script we might need standard headers
  // Trying direct access first with headers
  final url = 'https://boardgamegeek.com/browse/boardgame';

  print('Fetching $url...');
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html',
      },
    );

    if (response.statusCode == 200) {
      print('Page loaded. Length: ${response.body.length}');

      // Regex to find game IDs in rank order
      // Pattern typically: <a href="/boardgame/174430/gloomhaven" ...>
      // And rank is usually in a cell before or implied by order

      final regex = RegExp(r'href="/boardgame/(\d+)/[^"]*"');
      final matches = regex.allMatches(response.body);

      print('Found ${matches.length} game links.');

      final ids = <String>[];
      for (final match in matches) {
        final id = match.group(1)!;
        if (!ids.contains(id)) {
          ids.add(id);
        }
      }

      print('Unique IDs found (first 20): ${ids.take(20).toList()}');
    } else {
      print('Failed to load: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
