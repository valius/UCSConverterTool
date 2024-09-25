import 'dart:developer';

import 'package:ucsconvertertool/converters/i_converter.dart';
import 'package:ucsconvertertool/converters/sm_converter_common.dart';
import 'package:ucsconvertertool/step_files/andamiro_common.dart';
import 'package:ucsconvertertool/step_files/sm_common.dart';
import 'package:ucsconvertertool/step_files/ssc_file.dart';
import 'package:ucsconvertertool/step_files/ucs_file.dart';
import "package:path/path.dart" as p;

class SSCConverter implements IConverter {
  late String _filename;

  SSCConverter(String filename) {
    _filename = filename;
  }

  (bool, int) _tickCountChangeIfNeeded(int linesProcessed, int targetTickCount,
      List<SMConverterHelperTuple> tickCountsWithinMeasure) {
    for (int i = 0; i < tickCountsWithinMeasure.length; i++) {
      if (linesProcessed == tickCountsWithinMeasure[i].chartLocation) {
        targetTickCount = tickCountsWithinMeasure[i].value.floor();
        return (true, targetTickCount);
      }
    }

    return (false, targetTickCount);
  }

  UCSFile convertSSCChartToUCS(
      String filename, SSCFileMetaData sscFileData, SSCChart chart) {
    List<SMValuePair> bpms = chart.metaData.bpms;
    List<SMValuePair> stops = chart.metaData.stops;
    List<SMValuePair> tickCounts = chart.metaData.tickCounts;

    //Fallback if bpms or tickcounts are empty
    if (bpms.isEmpty) {
      bpms = sscFileData.bpms;
    }
    if (tickCounts.isEmpty) {
      tickCounts = sscFileData.tickCounts;
    }

    UCSFile resultUCS = UCSFile(filename);

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
    int currentTickCountIndex = -1;

    UCSBlock? currentUcsBlock;

    int index = 0;
    int lastBeatSplit = -1;

    //SSC files don't have Hold "Middle"/Continue Notes like Andamiro formats, so keep track if a lane is in the middle of a hold
    List<bool> isHolding = [false, false, false, false, false, false, false, false, false, false];
    int targetTickCount = -1;

    while (index < chart.getMeasureData.length) {
      SMMeasure currentMeasure = chart.getMeasureData[index];

      bool measureDirty = false;

      List<SMConverterHelperTuple> bpmsWithinMeasure;
      List<SMConverterHelperTuple> stopsWithinMeasure;
      List<SMConverterHelperTuple> tickCountsWithinMeasure;

      //Assume 4/4 time, but maybe we'll support other time signatures someday?
      int origMeasureBeatsplit = currentMeasure.measureLines.length ~/ 4;
      int measureBeatSplitFactor = 1;
      while (true) {
        //Check for upcoming BPM pairs within this measure
        (bpmsWithinMeasure, measureBeatSplitFactor, currentMeasure, measureDirty) = createListOfTuplesWithinMeasure(
          currentBpmIndex, origMeasureBeatsplit, measureBeatSplitFactor, bpms, numberOfBeatsProcessed, currentMeasure, measureDirty);
        (stopsWithinMeasure, measureBeatSplitFactor, currentMeasure, measureDirty) = createListOfTuplesWithinMeasure(
          currentStopIndex, origMeasureBeatsplit, measureBeatSplitFactor, stops, numberOfBeatsProcessed, currentMeasure, measureDirty);
        (tickCountsWithinMeasure, measureBeatSplitFactor, currentMeasure, measureDirty) = createListOfTuplesWithinMeasure(
          currentTickCountIndex, origMeasureBeatsplit, measureBeatSplitFactor, tickCounts, numberOfBeatsProcessed, currentMeasure, measureDirty);

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
      for (int i = 0; i < currentMeasure.measureLines.length; i++) {
        SMMeasureLine line = currentMeasure.measureLines[i];

        bool tickcountCheckResult = false;
        (tickcountCheckResult, targetTickCount) = _tickCountChangeIfNeeded(
          numberOfMeasureLinesProcessed, targetTickCount, tickCountsWithinMeasure);
        if (tickcountCheckResult) {
          currentTickCountIndex++;
        }

        int resultBeatSplit;
        if (targetTickCount <= 0 || targetTickCount <= beatSplit) {
          //UCS doesn't support 0 tick counts, so just set to original beat split
          //Also if target is below current beat split, don't do anything
          resultBeatSplit = beatSplit;
        } else {
          //try to get the nearest integer multiple to target tick count
          int multiplier = (targetTickCount / beatSplit).ceil();
          resultBeatSplit = beatSplit * multiplier;
        }

        bool stopQueued = false;
        bool bpmChanged = false;
        (bpmChanged, resultUCS, currentUcsBlock) = changeUCSBlockIfNeededForBPMChange(
          numberOfMeasureLinesProcessed, resultBeatSplit, sscFileData.offset, bpmsWithinMeasure, resultUCS, currentUcsBlock);
        if (bpmChanged) {
          currentBpmIndex++;
        }
        if (checkIfStopMustBeQueued(
            numberOfMeasureLinesProcessed, stopsWithinMeasure)) {
          stopQueued = true;
        }

        if ((lastBeatSplit > 0 && resultBeatSplit != lastBeatSplit) || stopQueued) {
          //The beat split of this measure is different than last one, so create new block
          if (currentUcsBlock != null && currentUcsBlock.lines.isNotEmpty) {
            resultUCS.getBlocks.add(currentUcsBlock);
            currentUcsBlock = UCSBlock();
          } else {
            currentUcsBlock ??= UCSBlock();
          }
          currentUcsBlock.bpm = bpms[currentBpmIndex].value;
          if (stopQueued) {
            currentUcsBlock.beatSplit = 128;
          } else {
            currentUcsBlock.beatSplit = resultBeatSplit;
          }
          //SM chart beat per measure is 4 because of 4/4 time for now?
          currentUcsBlock.beatPerMeasure = 4;
          currentUcsBlock.startTime = 0;
        }

        UCSBlockLine ucsLine = UCSBlockLine();

        if (chart.getChartType == SMChartType.halfDouble) {
          //Pad with 2 0s on left side
          ucsLine.notes.add(AMNoteType.none);
          ucsLine.notes.add(AMNoteType.none);
        }

        for (int j = 0; j < line.lineNotes.length; j++) {
          switch (line.lineNotes[j]) {
            case SMNoteType.none:
              {
                if (isHolding[j]) {
                  //Hold transition notes are not specified in SM format, so you need to check if hold in hold array is on
                  ucsLine.notes.add(AMNoteType.hold);
                } else {
                  ucsLine.notes.add(AMNoteType.none);
                }
                break;
              }
            case SMNoteType.normal:
              ucsLine.notes.add(AMNoteType.regular);
              break;
            case SMNoteType.freezeBegin:
            case SMNoteType.rollBegin:
              {
                //Treat rolls as if they are freezes for UCS
                isHolding[j] = true;
                ucsLine.notes.add(AMNoteType.holdBegin);
                break;
              }
            case SMNoteType.freezeOrRollEnd:
              {
                //Turn off holding on freeze/roll end
                isHolding[j] = false;
                ucsLine.notes.add(AMNoteType.holdEnd);
                break;
              }
            default:
              {
                //Unknown note type, so default to none
                ucsLine.notes.add(AMNoteType.none);
                break;
              }
          }
        }

        if (chart.getChartType == SMChartType.halfDouble) {
          //Pad with 2 0s on right side
          ucsLine.notes.add(AMNoteType.none);
          ucsLine.notes.add(AMNoteType.none);
        }

        //Add line
        currentUcsBlock?.lines.add(ucsLine);

        //Process stops
        if (stopQueued) {
          bool stopResult = false;
          (stopResult, resultUCS, currentUcsBlock) = changeUCSBlockIfNeededForStop(
            numberOfMeasureLinesProcessed, resultBeatSplit, bpms[currentBpmIndex].value, isHolding, stopsWithinMeasure, resultUCS, currentUcsBlock);
          if (stopResult) {
            currentStopIndex++;
          }
        }

        int numLinesToInsert = (resultBeatSplit ~/ beatSplit) - 1;
        //Finished adding the line, so add padding lines to maintain the tickcount
        for (int k = 0; k < numLinesToInsert; k++) {
          UCSBlockLine paddingLine = UCSBlockLine();

          if (chart.getChartType == SMChartType.halfDouble) {
            //Pad with 2 0s on left side
            paddingLine.notes.add(AMNoteType.none);
            paddingLine.notes.add(AMNoteType.none);
          }

          int numberOfNotesPerLine = 5;
          if (chart.getChartType == SMChartType.double) {
            numberOfNotesPerLine = 10;
          } else if (chart.getChartType == SMChartType.halfDouble) {
            numberOfNotesPerLine = 6;
          }

          for (int l = 0; l < numberOfNotesPerLine; l++) {
            if (isHolding[l]) {
              paddingLine.notes.add(AMNoteType.hold);
            } else {
              paddingLine.notes.add(AMNoteType.none);
            }
          }

          if (chart.getChartType == SMChartType.halfDouble) {
            //Pad with 2 0s on right side
            paddingLine.notes.add(AMNoteType.none);
            paddingLine.notes.add(AMNoteType.none);
          }

          currentUcsBlock?.lines.add(paddingLine);
        }

        numberOfMeasureLinesProcessed++;
        //update last beatsplit
        lastBeatSplit = resultBeatSplit;
      }

      //4 beats processed because 4 beats in 1 measure (4/4 time)
      numberOfBeatsProcessed += 4;
      index++;
    }

    //Add final ucs block here
    if (currentUcsBlock != null) {
      resultUCS.getBlocks.add(currentUcsBlock);
    }

    return resultUCS;
  }

  @override
  Future<List<UCSFile>> convert() async {
    if (_filename.isEmpty) {
      //Can't convert SM with invalid filename

      return List.empty();
    }
    SSCFile sscFile = SSCFile(_filename);
    await sscFile.intialize();

    List<UCSFile> result = [];

    try {
      for (var chart in sscFile.charts) {
        var ucsFile = convertSSCChartToUCS(
            "${p.withoutExtension(_filename)}-${chart.difficulty}-${chart.meter}-${chart.description}.ucs",
            sscFile.metaData,
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
