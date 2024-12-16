import 'package:ucsconvertertool/converters/i_converter.dart';
import 'package:ucsconvertertool/step_files/not_file.dart';
import 'package:ucsconvertertool/step_files/ucs_file.dart';

class NotConverter implements IConverter {
  final String _filename;

  NotConverter(this._filename);

  @override
  String get getFilename {
    return _filename;
  }

  @override
  Future<List<UCSFile>> convert() async {
    Not5File file = Not5File(_filename);

    await file.intialize();

    //TODO: actually return UCS files
    return List.empty();
  }
}
