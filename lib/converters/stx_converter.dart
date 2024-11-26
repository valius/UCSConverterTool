import 'package:ucsconvertertool/step_files/stx_file.dart';

import '../step_files/ucs_file.dart';
import 'i_converter.dart';

class STXConverter implements IConverter {
  late String _filename;

  STXConverter(this._filename);

  @override
  Future<List<UCSFile>> convert() async {
    if (_filename.isEmpty) {
      //Can't convert SM with invalid filename

      return List.empty();
    }
    STXFile stxFile = STXFile(_filename);
    await stxFile.intialize();

    List<UCSFile> result = [];
    return result;
  }

  @override
  String get getFilename {
    return _filename;
  }
}
