import "dart:developer";

import "package:ucsconvertertool/step_files/ucs_file.dart";

import "i_converter.dart";

class FallbackConverter implements IConverter {
  final String _filename;

  FallbackConverter(this._filename);

  @override
  String get getFilename {
    return _filename;
  }

  @override
  List<UCSFile> convert() {
    if (_filename.isEmpty) {
      log("Found empty filename. Skipping...");
    } else {
      String message =
          "Found an unknown file type to convert from $_filename. Skipping...";
      log(message);
    }

    return List.empty();
  }
}
