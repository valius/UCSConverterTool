import 'package:ucsconvertertool/converters/i_converter.dart';
import 'package:ucsconvertertool/step_files/not_file.dart';
import 'package:ucsconvertertool/step_files/ucs_file.dart';
import "package:path/path.dart" as p;

import '../step_files/andamiro_common.dart';

class NotConverter implements IConverter {
  final String _filename;

  NotConverter(this._filename);

  //We already do a sanity check before using this function so no checking here
  ({List<double> bpms, List<int> bunkis}) filterBpmsAndBunkis(
      List<double> bpms, List<int> bunkis) {
    //BPM list always has the very first one
    List<double> resultBpms = List.filled(1, bpms[0], growable: true);
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
      resultBunkis.add(bunki);

      previousBunki = bunki;
    }

    return (bpms: resultBpms, bunkis: resultBunkis);
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
    (bpms: validBpms, bunkis: validBunkis) =
        filterBpmsAndBunkis(file.getBpms, file.getBunkis);

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

    //Create first block
    UCSBlock currentUCSBlock = UCSBlock();
    currentUCSBlock.bpm = validBpms[0];
    currentUCSBlock.beatPerMeasure = file.getBeatsPerMeasure;

    //The first start time is the only one we care about, the other start times are used so that the chart will be in the correct spot for when bunki is reached in the engine
    //We will make the assumption that the bunki is the time when the BPM changed regardless of whether the start time is correct or not, since that's how it was used in
    //the Extra engine
    currentUCSBlock.startTime = file.getStartTimes[0] *
        10.0; //convert from centiseconds to milliseconds
    currentUCSBlock.beatSplit = file.getBeatSplit;

    double timeNeededForOneLine = (1.0 / file.getBeatSplit) /
        (file.getBpms[0] / 6000.0); //Done in centiseconds to check against bunki which is in centiseconds

    double timePassed = file.getStartTimes[0].toDouble();
    int currentBpmIndex = 1;
    int currentBunkiIndex = 0;
    bool hasBunkis = validBunkis.isNotEmpty;
    for (var notLine in file.getLines) {
      if (hasBunkis && currentBunkiIndex != validBunkis.length) {
        if (timePassed >= validBunkis[currentBunkiIndex]) {
          if (currentUCSBlock.lines.isNotEmpty) {
            resultUCS.getBlocks.add(currentUCSBlock);
          }
          //create new block
          currentUCSBlock = UCSBlock();
          currentUCSBlock.bpm = validBpms[currentBpmIndex];
          currentUCSBlock.beatSplit = file.getBeatSplit;
          currentUCSBlock.startTime = 0;
          currentUCSBlock.beatPerMeasure = file.getBeatsPerMeasure;

          currentBunkiIndex++;
          currentBpmIndex++;

          timeNeededForOneLine = (1.0 / file.getBeatSplit) /
              (file.getBpms[currentBpmIndex] / 6000.0);
        }
      }

      timePassed += timeNeededForOneLine;

      assert(notLine.notes.length == 10,
          "This NOT file's lines are malformed, not having 10 arrows");

      AndamiroStepLine ucsBlockLine = AndamiroStepLine();
      for (int i = 0; i < numberOfArrowsPerLine; i++) {
        ucsBlockLine.notes.add(notLine.notes[i]);
      }

      currentUCSBlock.lines.add(ucsBlockLine);
    }

    if (currentUCSBlock.lines.isNotEmpty) {
      resultUCS.getBlocks.add(currentUCSBlock);
    }

    return List.filled(1, resultUCS);
  }
}
