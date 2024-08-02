import "package:ucsconvertertool/converters/fallback_converter.dart";
import "package:ucsconvertertool/converters/i_converter.dart";

class ConverterGenerator {
  static IConverter createConverter(String filename) {
    return FallbackConverter(filename);
  }
}
