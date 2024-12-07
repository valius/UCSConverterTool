import 'dart:developer';

import 'package:ucsconvertertool/converters/i_converter.dart';
import 'package:ucsconvertertool/converters/sm_converter_common.dart';
import 'package:ucsconvertertool/step_files/sm_common.dart';
import 'package:ucsconvertertool/step_files/sm_file.dart';
import 'package:ucsconvertertool/step_files/ucs_file.dart';
import "package:path/path.dart" as p;

class SMConverter implements IConverter {
  late String _filename;

  UCSFile _convertSMChartToUCS(
      String outputFileName, SMFileMetadata smFileData, SMChart chart) {
    var resultUCS = UCSFile(outputFileName);
    switch (chart.getChartType) {
      case SMChartType.double:
      case SMChartType.halfDouble:
      case SMChartType.routine:
        resultUCS.chartType = UCSChartType.double;
        break;
      default:
        resultUCS.chartType = UCSChartType.single;
        break;
    }

    int numberOfBeatsProcessed = 0;
    int currentBpmIndex = -1; //Default to no bpm selected yet
    int currentStopIndex = -1; //Default to no stop selected yet

    UCSBlock? currentUcsBlock;

    int currentMeasureIndex = 0;
    int lastMeasureBeatSplit = -1;

    //SM files don't have Hold "Middle"/Continue Notes like Andamiro formats, so keep track if a lane is in the middle of a hold
    List<bool> isHolding = List<bool>.filled(10, false);
    
    while (currentMeasureIndex < chart.getMeasureData.length) {
      SMMeasure currentMeasure = chart.getMeasureData[currentMeasureIndex];

      bool measureDirty = false;

      List<SMConverterHelperTuple> bpmsWithinMeasure;
      List<SMConverterHelperTuple> stopsWithinMeasure;

      //Assume 4/4 time, but maybe we'll support other time signatures someday?
      int origMeasureBeatsplit = currentMeasure.measureLines.length ~/ 4;
      int measureBeatSplitFactor = 1;
      while (true) {
        //Check for upcoming BPM pairs within this measure
        (
          bpmsWithinMeasure,
          measureBeatSplitFactor,
          measureDirty
        ) = createListOfTuplesWithinMeasure(
            currentBpmIndex,
            origMeasureBeatsplit,
            measureBeatSplitFactor,
            smFileData.bpms,
            numberOfBeatsProcessed,
            currentMeasure,
            measureDirty);
        (
          stopsWithinMeasure,
          measureBeatSplitFactor,
          measureDirty
        ) = createListOfTuplesWithinMeasure(
            currentStopIndex,
            origMeasureBeatsplit,
            measureBeatSplitFactor,
            smFileData.stops,
            numberOfBeatsProcessed,
            currentMeasure,
            measureDirty);
        if (measureDirty) {
          //Stops changed the measure, have to recalculate bpms
          measureDirty = false;
          continue;
        }

        break;
      }

      //Beatsplit will be number of lines in measure divided by 4, assume 4/4 time for now
      int beatSplit = currentMeasure.measureLines.length ~/ 4;
      int numberOfMeasureLinesProcessed = 0;

      for (int measureLineIndex = 0;
          measureLineIndex < currentMeasure.measureLines.length;
          measureLineIndex++) {
        SMMeasureLine line = currentMeasure.measureLines[measureLineIndex];
        bool stopQueued = false;
        bool bpmChanged = false;
        (bpmChanged, resultUCS, currentUcsBlock) =
            changeUCSBlockIfNeededForBPMChange(
                numberOfMeasureLinesProcessed,
                beatSplit,
                smFileData.offset,
                bpmsWithinMeasure,
                resultUCS,
                currentUcsBlock);
        if (bpmChanged) {
          currentBpmIndex++;
        }
        if (checkIfStopMustBeQueued(
            numberOfMeasureLinesProcessed, stopsWithinMeasure)) {
          stopQueued = true;
        }

        if ((measureLineIndex == 0 &&
                lastMeasureBeatSplit > 0 &&
                beatSplit != lastMeasureBeatSplit) ||
            stopQueued) {
          //The beat split of this measure is different than last one, so create new block
          if (currentUcsBlock != null && currentUcsBlock.lines.isNotEmpty) {
            resultUCS.getBlocks.add(currentUcsBlock);
            currentUcsBlock = UCSBlock();
          } else {
            currentUcsBlock ??= UCSBlock();
          }
          currentUcsBlock.bpm = smFileData.bpms[currentBpmIndex].value;
          if (stopQueued) {
            currentUcsBlock.beatSplit = 128;
          } else {
            currentUcsBlock.beatSplit = beatSplit;
          }
          //SM chart beat per measure is 4 because of 4/4 time for now?
          currentUcsBlock.beatPerMeasure = 4;
          currentUcsBlock.startTime = 0;
        }

        UCSBlockLine ucsLine =
            convertSMLineToUCSLine(line, chart.getChartType, isHolding);

        //Add line
        currentUcsBlock?.lines.add(ucsLine);

        //Process stops
        if (stopQueued) {
          bool stopResult = false;
          (stopResult, resultUCS, currentUcsBlock) =
              changeUCSBlockIfNeededForStop(
                  numberOfMeasureLinesProcessed,
                  beatSplit,
                  smFileData.bpms[currentBpmIndex].value,
                  isHolding,
                  stopsWithinMeasure,
                  resultUCS,
                  currentUcsBlock);
          if (stopResult) {
            currentStopIndex++;
          }
        }

        numberOfMeasureLinesProcessed++;
      }

      //4 beats processed because 4 beats in 1 measure (4/4 time)
      numberOfBeatsProcessed += 4;
      currentMeasureIndex++;
      //update last measure beatsplit
      lastMeasureBeatSplit = beatSplit;
    }

    //Add final ucs block here
    if (currentUcsBlock != null) {
      resultUCS.getBlocks.add(currentUcsBlock);
    }

    return resultUCS;
  }

  SMConverter(String filename) {
    _filename = filename;
  }

  @override
  Future<List<UCSFile>> convert() async {
    if (_filename.isEmpty) {
      //Can't convert SM with invalid filename

      return List.empty();
    }
    SMFile smFile = SMFile(_filename);
    await smFile.intialize();

    List<UCSFile> result = [];

    try {
      for (var chart in smFile.charts) {
        var ucsFile = _convertSMChartToUCS(
            "${p.withoutExtension(_filename)}-${chart.difficulty}.ucs",
            smFile.metadata,
            chart);

        result.add(ucsFile);
      }
    } catch (e) {
      log("Encountered error $e");
    }

    return result;
  }

  @override
  String get getFilename {
    return _filename;
  }
}
