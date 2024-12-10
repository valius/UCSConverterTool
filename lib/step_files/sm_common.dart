import 'package:flutter/material.dart';
import 'package:ucsconvertertool/helpers/math_helpers.dart';
import 'package:ucsconvertertool/helpers/string_helpers.dart';

enum SMNoteType { none, normal, freezeBegin, rollBegin, freezeOrRollEnd }

class SMValuePair {
  double value = -1;
  double chartLocation = -1;
}

class SMMeasureLine {
  List<SMNoteType> lineNotes = [];
}

class SMMeasure {
  List<SMMeasureLine> measureLines = [];
}

enum SMFileProcessingMode {
  tagRead,
  chartTagRead,
  chartRead,
  routineChartRead,
  done,
  failed
}

enum SMChartType { single, double, halfDouble, routine, couple, invalid }

abstract class ISMChart {
  SMChartType get getChartType;
  set setChartType(SMChartType chartType);
  List<SMMeasure> get getMeasureData;
}

List<SMValuePair> processTagValueString(String tagValueString) {
  if (tagValueString.isEmpty) {
    return [];
  }

  int startIndex = 0;
  int indexOfEqual;
  List<SMValuePair> result = [];

  tagValueString = tagValueString.replaceAll('\n', '');

  while (true) {
    indexOfEqual = tagValueString.indexOf('=', startIndex);
    if (indexOfEqual < 0) {
      break;
    }

    SMValuePair pair = SMValuePair();

    String chartLocationStr =
        tagValueString.substring(startIndex, indexOfEqual);
    pair.chartLocation = double.parse(chartLocationStr);

    startIndex = indexOfEqual + 1;
    int endingIndex = tagValueString.length;
    int indexOfComma = tagValueString.indexOf(',', startIndex);
    if (indexOfComma < 0) {
      String valueStr = tagValueString.substring(startIndex, endingIndex);
      pair.value = double.parse(valueStr);
      result.add(pair);
      //There are no more values left, end here
      break;
    } else {
      //More values, so continue
      String valueStr = tagValueString.substring(startIndex, indexOfComma);
      pair.value = double.parse(valueStr);
      result.add(pair);
      startIndex = indexOfComma + 1;
    }
  }

  return result;
}

void setMeasureLineCount(SMMeasure measure, int count) {
  //To do this operation, you need to get lcm of current measure line count and input count
  int resultLineCount = lcm(measure.measureLines.length, count);

  int numLinesToInsert = (resultLineCount ~/ measure.measureLines.length) - 1;
  List<SMMeasureLine> resultMeasureLines = [];

  for (int i = 0; i < measure.measureLines.length; i++) {
    SMMeasureLine line = measure.measureLines[i];
    resultMeasureLines.add(line);

    //Finished adding the line, so add padding lines
    for (int k = 0; k < numLinesToInsert; k++) {
      SMMeasureLine paddingLine = SMMeasureLine();

      int numberOfNotesPerLine = line.lineNotes.length;

      for (int l = 0; l < numberOfNotesPerLine; l++) {
        paddingLine.lineNotes.add(SMNoteType.none);
      }

      resultMeasureLines.add(paddingLine);
    }
  }

  measure.measureLines = resultMeasureLines;
}

SMMeasure combineRoutineMeasures(SMMeasure measure1, SMMeasure measure2) {
  //Compare line counts
  int measure1LineCount = measure1.measureLines.length;
  int measure2LineCount = measure2.measureLines.length;

  if (measure1LineCount != measure2LineCount) {
    //Need to make measures exactly the same size
    int newLineCount = lcm(measure1LineCount, measure2LineCount);

    setMeasureLineCount(measure1, newLineCount);
    setMeasureLineCount(measure2, newLineCount);
  }

  //Go through each line and place any valid notes in measure 2 into measure 1
  for (int i = 0; i < measure1.measureLines.length; i++) {
    SMMeasureLine measure1Line = measure1.measureLines[i];
    SMMeasureLine measure2Line = measure2.measureLines[i];
    for (int j = 0; j < measure2Line.lineNotes.length; j++) {
      SMNoteType note = measure2Line.lineNotes[j];
      if (note != SMNoteType.none) {
        measure1Line.lineNotes[j] = note;
      }
    }
  }

  return measure1;
}

({
  bool shouldChangeMode,
  bool isLookingForTagValue,
  String tagString,
  String valueString
}) processTag(
    String line,
    String tagString,
    String valueString,
    bool isLookingForTagValue,
    String tagToChangeMode,
    Function(String, String) tagProcessFunction) {
  int indexOfPound = line.indexOf(
      '#'); //First instance of pound (check if a tag begins with this line)
  if (isLookingForTagValue && indexOfPound == 0) {
    //Tag begin, but we hadn't stopped looking for value of previous tag
    //End tag value seeking here, and just process as if we ran into a semicolon
    tagProcessFunction(tagString, valueString);
    tagString = "";
    valueString = "";
    isLookingForTagValue = false;
  }

  if (isLookingForTagValue) {
    int indexOfSemicolon = line.indexOf(';');

    if (indexOfSemicolon >= 0) {
      valueString += line.substring(0, indexOfSemicolon);

      //Process tag and value
      tagProcessFunction(tagString, valueString);

      //Reset to initial state
      //Reset tag string and value
      isLookingForTagValue = false;
      tagString = "";
      valueString = "";
    } else {
      valueString += line;
    }
  } else {
    //Find if line contains a : character
    int indexOfColon = line.indexOf(':');
    int indexOfSemicolon = line.indexOf(';');

    if (indexOfColon >= 0) {
      tagString += line.substring(0, indexOfColon);

      if (tagString.contains(tagToChangeMode)) {
        //Switch mode means we ignore the rest of the line
        return (
          shouldChangeMode: true,
          isLookingForTagValue: false,
          tagString: "",
          valueString: ""
        );
      } else if (indexOfSemicolon >= 0) {
        valueString += line.substring(indexOfColon + 1, indexOfSemicolon);

        //Process tag and value
        tagProcessFunction(tagString, valueString);

        //Reset to initial state
        isLookingForTagValue = false;
        tagString = "";
        valueString = "";
      } else {
        //value is rest of line, but no semicolon so we keep adding on to the value string
        valueString += line.substring(indexOfColon + 1);
        isLookingForTagValue = true;
      }
    } else {
      tagString += line;
    }
  }

  return (
    shouldChangeMode: false,
    isLookingForTagValue: isLookingForTagValue,
    tagString: tagString,
    valueString: valueString
  );
}

class ProcessChartLineResult {
  late bool measureDidEnd;
  late bool chartDidEnd;
  late SMFileProcessingMode currentProcessingMode;
  late SMMeasure measure;

  ProcessChartLineResult(this.measureDidEnd, this.chartDidEnd,
      this.currentProcessingMode, this.measure);
}

//is end of measure, is end of chart, processing mode, measure
ProcessChartLineResult processChartLine(
    String inLine, SMMeasure currentProcessingMeasure) {
  String trimmedLine = inLine.trim();

  SMMeasureLine tempLine = SMMeasureLine();

  bool endOfMeasure = trimmedLine.contains(',');
  bool endOfChart = trimmedLine.contains(';');
  bool endOfRoutineChart = trimmedLine.contains('&');

  Set<String> charsToTrim = {'\r', '\n', ' ', ',', ';', '&'};
  trimmedLine = trimmedLine.trimUsingCharacterSet(charsToTrim);
  Characters arrayOfChars = Characters(trimmedLine);
  bool isReadingQuestNote = false;
  for (int i = 0; i < arrayOfChars.length; ++i) {
    SMNoteType noteType;
    var currentChar = arrayOfChars.elementAt(i);
    if (isReadingQuestNote) {
      if (currentChar == '}') {
        //Add empty note to replace the quest note because UCS doesn't support it
        tempLine.lineNotes.add(SMNoteType.none);
        isReadingQuestNote = false;
      } else {
        continue;
      }
    } else {
      if (currentChar == '/') {
        //Found comment, stop
        break;
      } else if (currentChar == '{') {
        //Found quest related note, just read to the end and treat it as an empty note because UCS doesn't support it
        isReadingQuestNote = true;
        continue;
      }

      switch (currentChar) {
        case '1':
          noteType = SMNoteType.normal;
          break;
        case '2':
          noteType = SMNoteType.freezeBegin;
          break;
        case '3':
          noteType = SMNoteType.freezeOrRollEnd;
          break;
        case '4':
          noteType = SMNoteType.rollBegin;
          break;
        default:
          noteType = SMNoteType.none; //0 or unknown/unsupported in PIU arcade
          break;
      }
      tempLine.lineNotes.add(noteType);
    }
  }

  if (tempLine.lineNotes.isNotEmpty) {
    //Only add non empty lines
    currentProcessingMeasure.measureLines.add(tempLine);
  }

  if (endOfMeasure) {
    return ProcessChartLineResult(
        true, false, SMFileProcessingMode.chartRead, currentProcessingMeasure);
  } else if (endOfChart) {
    //End chart, so put in looking for NOTES mode
    return ProcessChartLineResult(
        true, true, SMFileProcessingMode.tagRead, currentProcessingMeasure);
  } else if (endOfRoutineChart) {
    //End of first routine chart, so put into looking for non-first routine chart
    return ProcessChartLineResult(true, true,
        SMFileProcessingMode.routineChartRead, currentProcessingMeasure);
  }

  return ProcessChartLineResult(
      false, false, SMFileProcessingMode.chartRead, currentProcessingMeasure);
}

class ProcessRoutineChartLineResult {
  late bool measureDidEnd;
  late bool chartDidEnd;
  late bool routineChartDidEnd;
  late SMFileProcessingMode currentProcessingMode;
  late SMMeasure measure;

  ProcessRoutineChartLineResult(this.measureDidEnd, this.chartDidEnd,
      this.routineChartDidEnd, this.currentProcessingMode, this.measure);
}

ProcessRoutineChartLineResult processSecondRoutineChartLine(
    String inLine,
    int currentMeasureIndex,
    SMMeasure currentProcessingMeasure,
    SMMeasure existingChartMeasure) {
  String trimmedLine = inLine.trim();

  SMMeasureLine tempLine = SMMeasureLine();

  bool endOfMeasure = trimmedLine.contains(',');
  bool endOfChart = trimmedLine.contains(';');
  bool endOfRoutineChart = trimmedLine.contains('&');

  Set<String> charsToTrim = {'\r', '\n', ' ', ',', ';', '&'};
  trimmedLine = trimmedLine.trimUsingCharacterSet(charsToTrim);
  Characters arrayOfChars = Characters(trimmedLine);
  bool isReadingQuestNote = false;
  for (int i = 0; i < arrayOfChars.length; ++i) {
    SMNoteType noteType;
    var currentChar = arrayOfChars.elementAt(i);
    if (isReadingQuestNote) {
      if (currentChar == '}') {
        //Add empty note to replace the quest note because UCS doesn't support it
        tempLine.lineNotes.add(SMNoteType.none);
        isReadingQuestNote = false;
      } else {
        continue;
      }
    } else {
      if (currentChar == '/') {
        //Found comment, stop
        break;
      } else if (currentChar == '{') {
        //Found quest related note, just read to the end and treat it as an empty note because UCS doesn't support it
        isReadingQuestNote = true;
      }

      switch (currentChar) {
        case '1':
          noteType = SMNoteType.normal;
          break;
        case '2':
          noteType = SMNoteType.freezeBegin;
          break;
        case '3':
          noteType = SMNoteType.freezeOrRollEnd;
          break;
        case '4':
          noteType = SMNoteType.rollBegin;
          break;
        default:
          noteType = SMNoteType.none; //0 or unknown/unsupported in PIU arcade
          break;
      }
      tempLine.lineNotes.add(noteType);
    }
  }

  if (tempLine.lineNotes.isNotEmpty) {
    //Only add non empty lines
    currentProcessingMeasure.measureLines.add(tempLine);
  }

  if (endOfMeasure) {
    return ProcessRoutineChartLineResult(
        true,
        false,
        false,
        SMFileProcessingMode.routineChartRead,
        combineRoutineMeasures(existingChartMeasure, currentProcessingMeasure));
  } else if (endOfChart) {
    //End chart, so put in looking for NOTES mode
    return ProcessRoutineChartLineResult(
        true,
        true,
        false,
        SMFileProcessingMode.tagRead,
        combineRoutineMeasures(existingChartMeasure, currentProcessingMeasure));
  } else if (endOfRoutineChart) {
    //Stay in routine chart reading mode
    return ProcessRoutineChartLineResult(
        true,
        false,
        true,
        SMFileProcessingMode.routineChartRead,
        combineRoutineMeasures(existingChartMeasure, currentProcessingMeasure));
  }

  //Still more lines to read, continue staying in measure
  return ProcessRoutineChartLineResult(false, false, false,
      SMFileProcessingMode.routineChartRead, currentProcessingMeasure);
}
