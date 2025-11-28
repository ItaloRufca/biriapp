import 'dart:io';

void main() async {
  final inputFile = File('seed_legacy.sql');
  if (!await inputFile.exists()) {
    print('seed_legacy.sql not found');
    return;
  }

  final lines = await inputFile.readAsLines();
  final chunkSize = 1000; // Adjust chunk size as needed
  int fileCount = 1;

  List<String> currentChunk = [];

  for (var i = 0; i < lines.length; i++) {
    currentChunk.add(lines[i]);

    if (currentChunk.length >= chunkSize || i == lines.length - 1) {
      final outputFile = File('seed_legacy_part$fileCount.sql');
      await outputFile.writeAsString(currentChunk.join('\n'));
      print('Created ${outputFile.path} with ${currentChunk.length} lines');

      currentChunk = [];
      fileCount++;
    }
  }

  print('Done! Split into ${fileCount - 1} files.');
}
