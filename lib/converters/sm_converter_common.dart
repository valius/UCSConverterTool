import 'package:ucsconvertertool/step_files/andamiro_common.dart';
import 'package:ucsconvertertool/step_files/sm_common.dart';
import 'package:ucsconvertertool/step_files/ucs_file.dart';

class SMConverterHelperTuple {
  late double value;
  late double chartLocation;
  late double beatAdjustment;
}

(bool, UCSFile, UCSBlock?) changeUCSBlockIfNeededForBPMChange(
    int linesProcessed,
    int beatsplit,
    double offset,
    List<SMConverterHelperTuple> bpmsWithinMeasure,
    UCSFile resultUCS,
    UCSBlock? currentUcsBlock) {
  //Check if need bpm change
  for (int i = 0; i < bpmsWithinMeasure.length; i++) {
    if (linesProcessed == bpmsWithinMeasure[i].chartLocation) {
      bool takeStartTimeFromOffset = false;

      //Create new block to indicate new BPM
      if (currentUcsBlock != null) {
        if (currentUcsBlock.lines.isNotEmpty) {
          //Add existing block first
          resultUCS.getBlocks.add(currentUcsBlock);
        } else {
          //Replace this empty block with our bpm
          currentUcsBlock.bpm = bpmsWithinMeasure[i].value;
          return (true, resultUCS, currentUcsBlock);
        }
      } else {
        //This is the first block, so we need to set the first block to use the SM file's offset
        takeStartTimeFromOffset = true;
      }
      currentUcsBlock = UCSBlock();
      currentUcsBlock.bpm = bpmsWithinMeasure[i].value;
      currentUcsBlock.beatSplit = beatsplit;
      currentUcsBlock.beatPerMeasure =
          4; //SM chart beat per measure is always 4
      if (takeStartTimeFromOffset) {
        currentUcsBlock.startTime = -1000.0 * offset;
      } else {
        currentUcsBlock.startTime = 0;
      }

      return (true, resultUCS, currentUcsBlock);
    }
  }

  return (false, resultUCS, currentUcsBlock);
}

bool checkIfStopMustBeQueued(
    int linesProcessed, List<SMConverterHelperTuple> stopsWithinMeasure) {
  for (int i = 0; i < stopsWithinMeasure.length; i++) {
    if (linesProcessed == stopsWithinMeasure[i].chartLocation) {
      return true;
    }
  }
  return false;
}

(bool, UCSFile, UCSBlock?) changeUCSBlockIfNeededForStop(
    int linesProcessed,
    int beatsplit,
    double bpm,
    List<bool> isHolding,
    List<SMConverterHelperTuple> stopsWithinMeasure,
    UCSFile resultUCS,
    UCSBlock? currentUcsBlock) {
  //Check if need bpm change
  for (int i = 0; i < stopsWithinMeasure.length; i++) {
    if (linesProcessed == stopsWithinMeasure[i].chartLocation) {
      if (currentUcsBlock != null) {
        if (currentUcsBlock.lines.isNotEmpty) {
          //Add existing block first
          resultUCS.getBlocks.add(currentUcsBlock);
          currentUcsBlock = UCSBlock();
        }
        //Don't add new block just update current block
      } else {
        //How is this possible that there was no block with bpm already existing?
        return (false, resultUCS, currentUcsBlock);
      }

      double stopBpm = 1;
      double timeNeededForOneBeat = 1.0 / 128 / (stopBpm / 60000.0);
      currentUcsBlock.beatSplit =
          128; //Lowest possible number of beats in a block to make this stop happen
      currentUcsBlock.beatPerMeasure =
          4; //SM chart beat per measure is always 4

      double lengthOfStop = stopsWithinMeasure[i].value * 1000.0;

      if (lengthOfStop < timeNeededForOneBeat) {
        //Somehow this stop is very, very small, just adjust bpm
        currentUcsBlock.bpm = (1.0 / 128) / lengthOfStop * 60000.0;
        currentUcsBlock.startTime = 0;
      } else {
        currentUcsBlock.bpm = stopBpm;
        currentUcsBlock.startTime = lengthOfStop -
            timeNeededForOneBeat; //Take into account line before stop and after stop
      }

      //Add line for stop
      UCSBlockLine paddingLine = UCSBlockLine();

      int numberOfArrowsPerLine = 5;
      if (resultUCS.chartType == UCSChartType.double) {
        numberOfArrowsPerLine = 10;
      }
      for (int j = 0; j < numberOfArrowsPerLine; j++) {
        if (isHolding[j]) {
          paddingLine.notes.add(AMNoteType.hold);
        } else {
          paddingLine.notes.add(AMNoteType.none);
        }
      }

      currentUcsBlock.lines.add(paddingLine);

      resultUCS.getBlocks.add(currentUcsBlock);

      //Beatsplit was altered, try accounting for it
      if (beatsplit < 128) {
        double timeRemainingAtRegularBpm =
            ((1.0 / beatsplit) - (2.0 / 128)) / (bpm / 60000.0);

        currentUcsBlock = UCSBlock();
        currentUcsBlock.bpm = bpm;
        currentUcsBlock.beatSplit = 128;
        currentUcsBlock.beatPerMeasure = 4;
        currentUcsBlock.startTime = timeRemainingAtRegularBpm;

        //Add line for stop to help account for beatsplit alteration
        paddingLine = UCSBlockLine();

        for (int j = 0; j < numberOfArrowsPerLine; j++) {
          if (isHolding[j]) {
            paddingLine.notes.add(AMNoteType.hold);
          } else {
            paddingLine.notes.add(AMNoteType.none);
          }
        }

        currentUcsBlock.lines.add(paddingLine);

        resultUCS.getBlocks.add(currentUcsBlock);
      }

      //Continue block
      currentUcsBlock = UCSBlock();
      currentUcsBlock.bpm = bpm;
      currentUcsBlock.beatSplit = beatsplit;
      currentUcsBlock.beatPerMeasure = 4;
      currentUcsBlock.startTime = 0;

      return (true, resultUCS, currentUcsBlock);
    }
  }

  return (false, resultUCS, currentUcsBlock);
}

(List<SMConverterHelperTuple>, int, SMMeasure, bool)
    createListOfTuplesWithinMeasure(
        int index,
        int origMeasureBeatsplit,
        int measureBeatSplitFactor,
        List<SMValuePair> chartChanges,
        int numberOfBeatsProcessed,
        SMMeasure measure,
        bool measureDirty) {
  List<SMConverterHelperTuple> result = [];

  int chartChangesCount = chartChanges.length;

  double threshold =
      0.001; //Denotes how far off from the precise beat the change is allowed to occur

  while (true) {
    //Depending on density of number of changes, we may need to double measure line count
    var locationSet = <int>{};
    bool needIncreaseMeasureLineCount = false;

    for (int i = index + 1; i < chartChangesCount; i++) {
      SMValuePair upcomingChangePair = chartChanges[i];

//Assuming 4-4 time, but maybe we should support more time signatures?
      if (upcomingChangePair.chartLocation < numberOfBeatsProcessed + 4) {
        //Figure out how many lines in our result measure it will take to reach the BPM change, given the new beat split, should divide evenly because of logic above...
        double numLinesBeforeChangeDouble =
            (upcomingChangePair.chartLocation - numberOfBeatsProcessed) *
                origMeasureBeatsplit *
                measureBeatSplitFactor;
        int numberOfLinesBeforeChangeInt = numLinesBeforeChangeDouble.round();

        double diff =
            (numLinesBeforeChangeDouble - numberOfLinesBeforeChangeInt).abs() *
                (1.0 / (origMeasureBeatsplit * measureBeatSplitFactor));

        if (locationSet.contains(numberOfLinesBeforeChangeInt) ||
            diff > threshold) {
          //Measure not dense enough so multiple changes on the same line
          //Or change can't start precisely because measure not dense enough
          needIncreaseMeasureLineCount = true;
        }

        locationSet.add(numberOfLinesBeforeChangeInt);

        SMConverterHelperTuple pair = SMConverterHelperTuple();
        pair.chartLocation = numberOfLinesBeforeChangeInt.toDouble();
        pair.value = upcomingChangePair.value;
        pair.beatAdjustment = 0;
        result.add(pair);
      }
    }

    //Cannot have a measure line count higher than 128
    if (needIncreaseMeasureLineCount &&
        origMeasureBeatsplit * (measureBeatSplitFactor + 1) < 128) {
      measureBeatSplitFactor++;
      result.clear();
      locationSet.clear();
      measureDirty = true;
      continue;
    }

    //Set the measure new line count after finishing calculation
    if (measureDirty) {
      measure.measureLines = setMeasureLineCount(measure.measureLines,
          origMeasureBeatsplit * 4 * measureBeatSplitFactor);
    }
    //pairs prepared
    break;
  }

  return (result, measureBeatSplitFactor, measure, measureDirty);
}
