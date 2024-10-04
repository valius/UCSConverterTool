
import 'dart:io';

Future<List<String>> getListOfFilesFromPath(String path) async {
  bool isDirectoryResult = await FileSystemEntity.isDirectory(path);
  if (isDirectoryResult) {
    final dir = Directory(path);
    final List<FileSystemEntity> entities = await dir.list(recursive: true).toList();
    final Iterable<File> files = entities.whereType<File>();
    List<String> result = List<String>.empty();
    for (var file in files) {
      result.add(file.path);
    }

    return result;
  }

  return List<String>.filled(1, path);
}