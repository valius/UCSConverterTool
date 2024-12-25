import "../converters/fallback_converter.dart";
import "../converters/i_converter.dart";
import "../converters/not_converter.dart";
import "../converters/sm_converter.dart";
import "../converters/ssc_converter.dart";
import "../converters/stx_converter.dart";
import "package:path/path.dart" as p;

class ConverterGenerator {
  static final Map<String, IConverter Function(String)> _converterConstructors =
      {
    '.SM': (filename) => SMConverter(filename),
    '.SSC': (filename) => SSCConverter(filename),
    '.STX': (filename) => STXConverter(filename),
    '.NOT': (filename) => NotConverter(filename),
  };

  static IConverter createConverter(String filename) {
    String ext = p.extension(filename).toUpperCase();
    final constructor = _converterConstructors[ext];
    if (constructor != null) {
      return constructor(filename);
    } else {
      //File unknown, return fallback
      return FallbackConverter(filename);
    }
  }
}
