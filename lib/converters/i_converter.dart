import "package:ucsconvertertool/step_files/ucs_file.dart";

abstract class IConverter {
  String get getFilename;

  Future<List<UCSFile>> convert() async {
    throw(AssertionError("convert function not implemented"));
  }
}
