import 'dart:io';

void main() {
  final file = File('carteados.csv');
  if (!file.existsSync()) {
    print('File not found');
    return;
  }

  final lines = file.readAsLinesSync();
  final ids = <String>{};
  final regex = RegExp(r'boardgamegeek\.com/boardgame/(\d+)');

  for (var line in lines) {
    final match = regex.firstMatch(line);
    if (match != null) {
      ids.add(match.group(1)!);
    }
  }

  print('Found ${ids.length} unique BGG IDs.');
  print('First 10 IDs: ${ids.take(10).toList()}');

  // Generate a Dart file with these IDs
  final outputFile = File('lib/data/carteados_list.dart');
  final content =
      '''
// Auto-generated from carteados.csv
const Set<String> carteadosIds = {
${ids.map((id) => "  '$id',").join('\n')}
};
''';

  outputFile.writeAsStringSync(content);
  print('Generated lib/data/carteados_list.dart');
}
