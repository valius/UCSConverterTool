import "package:ucsconvertertool/converters/fallback_converter.dart";
import "package:ucsconvertertool/converters/i_converter.dart";
import "package:path/path.dart" as p;
import "package:ucsconvertertool/converters/sm_converter.dart";

class ConverterGenerator {
  static IConverter createConverter(String filename) {
    String ext = p.extension(filename);
    if (ext.toUpperCase() == ".SM") {
      return SMConverter(filename);
    } else {
      return FallbackConverter(filename);
    }
  }
}
