import 'dart:developer';

class UCSFile {
  final String _filename;

  UCSFile(this._filename);

  void outputToFile() {
    //TODO(ktan): Actually create UCS File here
    String message =
        "Will need to implement writing to $_filename.eventually...";
    log(message);
  }
}
