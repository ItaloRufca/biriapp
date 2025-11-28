import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse(
    'https://cf.geekdo-images.com/cf0xxkevbwTGF3VUZymKjg__imagepage/img/c1nUYPglSR9Br_zPKasdnwi4q78=/fit-in/900x600/filters:no_upscale():strip_icc()/pic6398727.png',
  );

  print('Testing fetch for: $url');

  // Test 1: No headers
  try {
    final response = await http.get(url);
    print(
      'Test 1 (No Headers): Status ${response.statusCode}, Length: ${response.bodyBytes.length}',
    );
  } catch (e) {
    print('Test 1 Error: $e');
  }

  // Test 2: User-Agent
  try {
    final response = await http.get(
      url,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      },
    );
    print(
      'Test 2 (User-Agent): Status ${response.statusCode}, Length: ${response.bodyBytes.length}',
    );
  } catch (e) {
    print('Test 2 Error: $e');
  }

  // Test 3: User-Agent + Referer
  try {
    final response = await http.get(
      url,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Referer': 'https://boardgamegeek.com/',
      },
    );
    print(
      'Test 3 (UA + Referer): Status ${response.statusCode}, Length: ${response.bodyBytes.length}',
    );
  } catch (e) {
    print('Test 3 Error: $e');
  }
}
