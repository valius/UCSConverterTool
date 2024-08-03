import "package:ucsconvertertool/step_files/ucs_file.dart";

abstract class IConverter {
  String get getFilename;

  List<UCSFile> convert();
}
