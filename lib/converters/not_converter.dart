import 'dart:math';

import 'package:ucsconvertertool/converters/i_converter.dart';
import 'package:ucsconvertertool/step_files/not_file.dart';
import 'package:ucsconvertertool/step_files/ucs_file.dart';
import "package:path/path.dart" as p;

import '../step_files/andamiro_common.dart';

class NotConverterBunkiLineInfo {
  int bunkiEnterLines = -1;
  double bunkiEnterOffset = -1;
  int bunkiExitLines = -1;
  double bunkiExitOffset = -1;
}

class NotConverter implements IConverter {
  final String _filename;

  NotConverter(this._filename);

  //We already do a sanity check before using this function so no checking here
  ({List<int> startTimes, List<double> bpms, List<int> bunkis})
      _filterBpmsAndBunkis(
          List<int> startTimes, List<double> bpms, List<int> bunkis) {
    //BPM list always has the very first one
    List<double> resultBpms = List.filled(1, bpms[0], growable: true);
    List<int> resultStartTimes = List.filled(1, startTimes[0], growable: true);
    List<int> resultBunkis = [];

    int previousBunki = -1;
    for (int i = 0; i < maxChanges - 1; i++) {
      var bunki = bunkis[i];
      if (bunki == 0) {
        //A bunki of 0 means that's the end of any BPM changes
        break;
      }

      if (bunki == previousBunki) {
        //This bunki is a duplicate, ignore (this seems to be common on official charts
        //where a bunki and bpm would be repeated 2x)
        continue;
      }

      resultBpms.add(bpms[i + 1]);
      resultStartTimes.add(startTimes[i + 1]);
      resultBunkis.add(bunki);

      previousBunki = bunki;
    }

    return (
      startTimes: resultStartTimes,
      bpms: resultBpms,
      bunkis: resultBunkis
    );
  }

  List<NotConverterBunkiLineInfo> _getBunkiLineInfo(List<int> startTimes,
      List<double> bpms, List<int> bunkis, int beatSplit) {
    if (bunkis.isEmpty) {
      return [];
    }

    List<NotConverterBunkiLineInfo> result = [];
    //Handle first bunki line info
    NotConverterBunkiLineInfo firstBunkiLineInfo = NotConverterBunkiLineInfo();
    double rawLineCount =
        ((bunkis[0] - startTimes[0]) * (bpms[0] / 6000.0) * beatSplit);
    firstBunkiLineInfo.bunkiExitLines = rawLineCount.floor();
    firstBunkiLineInfo.bunkiExitOffset =
        (rawLineCount - firstBunkiLineInfo.bunkiExitLines) /
            ((bpms[0] / 6000.0) * beatSplit);

    result.add(firstBunkiLineInfo);

    for (int i = 0; i < bunkis.length; i++) {
      NotConverterBunkiLineInfo bunkiLineInfo = NotConverterBunkiLineInfo();
      rawLineCount = ((bunkis[i] - startTimes[i + 1]) *
          (bpms[i + 1] / 6000.0) *
          beatSplit);
      bunkiLineInfo.bunkiEnterLines = rawLineCount.ceil();
      bunkiLineInfo.bunkiEnterOffset =
          (bunkiLineInfo.bunkiEnterLines - rawLineCount) /
              ((bpms[i + 1] / 6000.0) * beatSplit);

      if (i < bunkis.length - 1) {
        rawLineCount = ((bunkis[i + 1] - startTimes[i + 1]) *
            (bpms[i + 1] / 6000.0) *
            beatSplit);
        bunkiLineInfo.bunkiExitLines = rawLineCount.floor();
        bunkiLineInfo.bunkiExitOffset =
            (rawLineCount - bunkiLineInfo.bunkiExitLines) /
                ((bpms[0] / 6000.0) * beatSplit);
      }

      result.add(bunkiLineInfo);
    }

    return result;
  }

  @override
  String get getFilename {
    return _filename;
  }

  @override
  Future<List<UCSFile>> convert() async {
    NotFile file = NotFile(_filename);

    await file.intialize();

    List<double> validBpms;
    List<int> validBunkis;
    List<int> validStartTimes;
    (startTimes: validStartTimes, bpms: validBpms, bunkis: validBunkis) =
        _filterBpmsAndBunkis(file.getStartTimes, file.getBpms, file.getBunkis);

    String ucsFilename = "${p.withoutExtension(_filename)}.ucs";
    UCSFile resultUCS = UCSFile(ucsFilename);
    int numberOfArrowsPerLine;

    //Set to double
    if (_filename.toUpperCase().contains('_XD') ||
        _filename.toUpperCase().contains("_DB")) {
      resultUCS.chartType = UCSChartType.double;
      numberOfArrowsPerLine = 10;
    } else {
      resultUCS.chartType = UCSChartType.single;
      numberOfArrowsPerLine = 5;
    }

    var bunkiLineInfo = _getBunkiLineInfo(
        validStartTimes, validBpms, validBunkis, file.getBeatSplit);

    if (bunkiLineInfo.isEmpty) {
      UCSBlock block = _buildUCSBlock(0, file.getLines.length - 1, file,
          validBpms[0], numberOfArrowsPerLine, validStartTimes[0].toDouble());

      //For NOT4, add padding line to beginning of the sole block's lines to emulate
      //official converters
      if (!file.isNot5) {
        AndamiroStepLine paddingLine = AndamiroStepLine();
        for (int i = 0; i < numberOfArrowsPerLine; i++) {
          paddingLine.notes.add(AMNoteType.none);
        }

        block.lines.insert(0, paddingLine);
      }

      resultUCS.getBlocks.add(block);

      return List.filled(1, resultUCS);
    }

    //Create blocks based on bunki
    for (int i = 0; i < bunkiLineInfo.length; i++) {
      NotConverterBunkiLineInfo lineInfo = bunkiLineInfo[i];
      int beginLineIndex = 0;

      int endLineIndex = file.getLines.length - 1;
      double offset;

      //For NOT4, we subtract 2 because of the padding line to be added to beginning of file to emulate official converters
      if (lineInfo.bunkiEnterLines != -1) {
        if (!file.isNot5) {
          beginLineIndex = lineInfo.bunkiEnterLines - 2;
        } else {
          beginLineIndex = lineInfo.bunkiEnterLines - 1;
        }
      }

      if (lineInfo.bunkiExitLines != -1) {
        if (!file.isNot5) {
          endLineIndex = lineInfo.bunkiExitLines - 2;
        } else {
          endLineIndex = lineInfo.bunkiExitLines - 1;
        }
      }

      if (i > 0) {
        double adjustment = 16;   //Adjustment of centiseconds for NOT4 offset, needed or chart will be out of sync
        if (file.isNot5) {
          adjustment = 14;    //Adjustment value for NOT5
        }
        offset = max((bunkiLineInfo[i - 1].bunkiExitOffset +
                lineInfo.bunkiEnterOffset -
                adjustment).floorToDouble(), 0);
      } else {
        offset = validStartTimes[0].toDouble();
      }
      UCSBlock block = _buildUCSBlock(beginLineIndex, endLineIndex, file,
          validBpms[i], numberOfArrowsPerLine, offset);

      if (!file.isNot5 && i == 0) {
        //For NOT4, add padding line to beginning of the first block's lines to emulate
        //official converters
        AndamiroStepLine paddingLine = AndamiroStepLine();
        for (int i = 0; i < numberOfArrowsPerLine; i++) {
          paddingLine.notes.add(AMNoteType.none);
        }

        block.lines.insert(0, paddingLine);
      }

      resultUCS.getBlocks.add(block);
    }

    return List.filled(1, resultUCS);
  }

  UCSBlock _buildUCSBlock(int beginLineIndex, int endLineIndex, NotFile file,
      double bpm, int numberOfArrowsPerLine, double offset) {
    UCSBlock ucsBlock = UCSBlock();
    ucsBlock.beatPerMeasure = file.getBeatsPerMeasure;
    ucsBlock.beatSplit = file.getBeatSplit;
    ucsBlock.bpm = bpm;
    ucsBlock.startTime =
        offset * 10.0; //convert from centiseconds to milliseconds

    for (int i = beginLineIndex; i <= endLineIndex; i++) {
      var notLine = file.getLines[i];
      assert(notLine.notes.length == 10,
          "This NOT file's lines are malformed, not having 10 arrows");

      AndamiroStepLine ucsBlockLine = AndamiroStepLine();
      for (int i = 0; i < numberOfArrowsPerLine; i++) {
        ucsBlockLine.notes.add(notLine.notes[i]);
      }

      ucsBlock.lines.add(ucsBlockLine);
    }

    return ucsBlock;
  }
}
