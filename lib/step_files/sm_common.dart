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

enum SMChartType { single, double, halfDouble, routine, invalid }

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
      String valueStr =
          tagValueString.substring(startIndex, endingIndex);
      pair.value = double.parse(valueStr);
      result.add(pair);
      //There are no more values left, end here
      break;
    } else {
      //More values, so continue
      String valueStr =
          tagValueString.substring(startIndex, indexOfComma);
      pair.value = double.parse(valueStr);
      result.add(pair);
      startIndex = indexOfComma + 1;
    }
  }

  return result;
}

List<SMMeasureLine> setMeasureLineCount(
    List<SMMeasureLine> measureLines, int count) {
  //To do this operation, you need to get lcm of current measure line count and input count
  int resultLineCount = lcm(measureLines.length, count);

  int numLinesToInsert = (resultLineCount ~/ measureLines.length) - 1;
  List<SMMeasureLine> resultMeasureLines = [];

  for (int i = 0; i < measureLines.length; i++) {
    SMMeasureLine line = measureLines[i];
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

  return resultMeasureLines;
}

SMMeasure combineRoutineMeasures(SMMeasure measure1, SMMeasure measure2) {
  //Compare line counts
  int measure1LineCount = measure1.measureLines.length;
  int measure2LineCount = measure2.measureLines.length;

  if (measure1LineCount != measure2LineCount) {
    //Need to make measures exactly the same size
    int newLineCount = lcm(measure1LineCount, measure2LineCount);

    measure1.measureLines =
        setMeasureLineCount(measure1.measureLines, newLineCount);
    measure2.measureLines =
        setMeasureLineCount(measure2.measureLines, newLineCount);
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
  for (int i = 0; i < arrayOfChars.length; ++i) {
    SMNoteType noteType;
    var currentChar = arrayOfChars.elementAt(i);
    if (currentChar == '/') {
      //Found comment, stop
      break;
    } else if (currentChar == '{') {
      //Found quest related line, stop because UCS doesn't support it
      break;
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
  late SMFileProcessingMode currentProcessingMode;
  late int measureIndex;
  late SMMeasure measure;

  ProcessRoutineChartLineResult(this.measureDidEnd, this.chartDidEnd,
      this.currentProcessingMode, this.measureIndex, this.measure);
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
  for (int i = 0; i < arrayOfChars.length; ++i) {
    SMNoteType noteType;
    var currentChar = arrayOfChars.elementAt(i);
    if (currentChar == '/') {
      //Found comment, stop
      break;
    } else if (currentChar == '{') {
      //Found quest related line, stop because UCS doesn't support it
      break;
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

  if (tempLine.lineNotes.isNotEmpty) {
    //Only add non empty lines
    currentProcessingMeasure.measureLines.add(tempLine);
  }

  if (endOfMeasure) {
    return ProcessRoutineChartLineResult(
        true,
        false,
        SMFileProcessingMode.routineChartRead,
        currentMeasureIndex + 1,
        combineRoutineMeasures(existingChartMeasure, currentProcessingMeasure));
  } else if (endOfChart) {
    //End chart, so put in looking for NOTES mode
    return ProcessRoutineChartLineResult(
        true,
        true,
        SMFileProcessingMode.tagRead,
        0,
        combineRoutineMeasures(existingChartMeasure, currentProcessingMeasure));
  } else if (endOfRoutineChart) {
    //Stay in routine chart reading mode, just reset index
    return ProcessRoutineChartLineResult(
        true,
        false,
        SMFileProcessingMode.routineChartRead,
        0,
        combineRoutineMeasures(existingChartMeasure, currentProcessingMeasure));
  }

  //Still more lines to read, continue staying in measure
  return ProcessRoutineChartLineResult(
      false,
      false,
      SMFileProcessingMode.routineChartRead,
      currentMeasureIndex,
      currentProcessingMeasure);
}
