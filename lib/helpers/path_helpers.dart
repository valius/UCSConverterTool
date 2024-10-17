import 'dart:io';
import "package:path/path.dart" as p;

Future<List<String>> getListOfFilesFromPath(
    String path, List<String> supportedExtensions) async {
  bool isDirectoryResult = await FileSystemEntity.isDirectory(path);
  if (isDirectoryResult) {
    final dir = Directory(path);
    final List<FileSystemEntity> entities =
        await dir.list(recursive: true).toList();
    final Iterable<File> files = entities.whereType<File>();
    List<String> result = [];
    for (var file in files) {
      String ext = p.extension(file.path).toLowerCase();
      if (ext.length <= 1) {
        //Ignore no extension or ones with just period?
        continue;
      }

      if (supportedExtensions.contains(ext.substring(1))) {
        result.add(file.path);
      }
    }

    return result;
  }

  return List<String>.filled(1, path);
}
