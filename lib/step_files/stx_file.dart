import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ucsconvertertool/helpers/byte_helpers.dart';

import 'andamiro_common.dart';

final List<int> stxHeaderBegin = [0X53, 0X54, 0X46, 0X34]; //string value "STF4"
const int maxBlocks = 50;

// Chart indices within file
enum ChartIndex {
  practice,
  normal,
  hard,
  nightmare,
  crazy,
  freestyle,
  halfDouble,
  division,
  lightmap,
  chartCount,
}

class STXDivisionLine {
  List<AMNoteType> notes = [];
}

class STXDivision {
  double bpm = 0;
  int delay = 0;
  int beatPerMeasure = 4; //Default
  int beatSplit = 0;
  List<STXDivisionLine> lines = [];
  int speedFactor = 1000; //Default speed
}

class STXBlock {
  List<STXDivision> divisions = [];
}

class STXChart {
  final List<STXBlock> _blocks = [];

  final ChartIndex index;
  int difficulty = -1;

  List<STXBlock> get getBlocks {
    return _blocks;
  }

  STXChart(this.index);
}

class STXFile {
  final String _filename;
  final List<STXChart> _charts = [];
  //String _title = "";
  //String _artist = "";
  //String _author = "";

  String get getFilename {
    return _filename;
  }

  List<STXChart> get getCharts {
    return _charts;
  }

  STXFile(this._filename);

  void _readChart(Uint8List chartBytes, ChartIndex index) {
    if (index == ChartIndex.lightmap) {
      //Ignore light map chart, since it is useless for UCS Conversion
      return;
    }

    int stepsPerBeat;

    switch (index) {
      case ChartIndex.normal:
      case ChartIndex.hard:
      case ChartIndex.crazy:
      case ChartIndex.practice:
      case ChartIndex.division:
        stepsPerBeat = 5;
        break;
      case ChartIndex.freestyle:
      case ChartIndex.nightmare:
      case ChartIndex
            .halfDouble: //Even though half double is only 6 steps in actuality, it is set up as a 10 step chart in data
        stepsPerBeat = 10;
        break;
      default:
        throw const FormatException(
            'Trying to read a chart for an unknown level!');
    }

    int i = 0;
    int difficulty;
    STXChart currentChart = STXChart(index);
    (i, difficulty) = readUint32BytesFromByteList(i, chartBytes);
    currentChart.difficulty = difficulty;

    List<int> divisionCounts = List<int>.filled(maxBlocks, 0);
    for (int blockIndex = 0; blockIndex < maxBlocks; blockIndex++) {
      int divisionCount;
      (i, divisionCount) = readUint32BytesFromByteList(i, chartBytes);
      divisionCounts[blockIndex] = divisionCount;
    }

    for (int blockIndex = 0; blockIndex < maxBlocks; blockIndex++) {
      int divisionCount = divisionCounts[blockIndex];
      if (divisionCount == 0) {
        //Division count 0 means that this block is past the end of the chart so we stop
        break;
      }

      STXBlock block = STXBlock();

      for (int divisionIndex = 0;
          divisionIndex < divisionCount;
          divisionIndex++) {
        STXDivision division = STXDivision();

        int compressedDataLength;
        (i, compressedDataLength) =
            readUint32BytesFromByteList(i, chartBytes);

        var decodedData =
            zlib.decode(chartBytes.sublist(i, i + compressedDataLength));

        i += compressedDataLength;

        int decodedIndex = 0;
        double bpm;
        (decodedIndex, bpm) =
            readFloat32BytesFromByteList(decodedIndex, decodedData);
        division.bpm = bpm;
        int beatPerMeasure;
        (decodedIndex, beatPerMeasure) =
            readUint32BytesFromByteList(decodedIndex, decodedData);
        division.beatPerMeasure = beatPerMeasure;
        int beatSplit;
        (decodedIndex, beatSplit) =
            readUint32BytesFromByteList(decodedIndex, decodedData);
        division.beatSplit = beatSplit;
        int delay;
        (decodedIndex, delay) =
            readUint32BytesFromByteList(decodedIndex, decodedData);
        division.delay = delay;

        //The next 20 integers will be skipped since they are the division sets and are specific to Division Mode
        //e.g. Perfect 0 - 0, Great 1 - 1, etc.
        decodedIndex += 80;

        int speedFactor;
        (decodedIndex, speedFactor) =
            readUint32BytesFromByteList(decodedIndex, decodedData);
        division.speedFactor = speedFactor;

        //Skip padding
        decodedIndex += 28;

        int lineCount;
        (decodedIndex, lineCount) =
            readUint32BytesFromByteList(decodedIndex, decodedData);

        for (int i = 0; i < lineCount; i++) {
          STXDivisionLine line = STXDivisionLine();

          var steps = decodedData.sublist(decodedIndex, decodedIndex + 13);
          decodedIndex += 13;

          for (int stepIndex = 0; stepIndex < stepsPerBeat; stepIndex++) {
            var currentStep = steps[stepIndex];

            switch (currentStep) {
              case 1:
                line.notes.add(AMNoteType.regular);
                break;
              case 10:
                line.notes.add(AMNoteType.holdBegin);
                break;
              case 11:
                line.notes.add(AMNoteType.hold);
                break;
              case 12:
                line.notes.add(AMNoteType.holdEnd);
                break;
              case 2:
                line.notes.add(AMNoteType.groove);
                break;
              case 3:
                line.notes.add(AMNoteType.wild);
                break;
              case 4:
                line.notes.add(AMNoteType.aStep);
                break;
              case 5:
                line.notes.add(AMNoteType.bStep);
                break;
              case 6:
                line.notes.add(AMNoteType.cStep);
                break;
              default:
                line.notes.add(AMNoteType.none); //unknown or 0 is an empty step
                break;
            }
          }

          division.lines.add(line);
        }

        block.divisions.add(division);
      }

      currentChart.getBlocks.add(block);
    }

    _charts.add(currentChart);
  }

  Future<void> intialize() async {
    var stxFile = File(_filename);

    try {
      var contents = await stxFile.readAsBytes();

      //Check header
      assert(contents.length > 4,
          'Header invalid because file is smaller than header!');

      if (!listEquals(stxHeaderBegin, contents.sublist(0, 4))) {
        throw const FormatException('STX Header mismatch!');
      }

      int i = 4;

      //Jump 56 bytes to title, next 64 is title
      i += 56;
      //_title = utf8.decode(contents.sublist(i, i + 64));

      i += 64;
      //next 64 is artist
      //_artist = utf8.decode(contents.sublist(i, i + 64));

      i += 64;
      //next 64 is author of chart
      //_author = utf8.decode(contents.sublist(i, i + 64));

      i += 64;

      //Gather the addresses of each chart in the STX file (always a fixed amount of charts per STX)
      List<int> addresses = [];
      for (int j = 0; j < ChartIndex.chartCount.index; j++) {
        //Read uint32 equivalent of bytes
        int value;
        (i, value) = readUint32BytesFromByteList(i, contents);
        addresses.add(value);
      }

      int endOfFile = contents.length;
      for (int j = 0; j < addresses.length; j++) {
        int dataStart = addresses[j];
        int dataEnd = endOfFile;
        if (j != addresses.length - 1) {
          dataEnd = addresses[j + 1];
        }

        _readChart(contents.sublist(dataStart, dataEnd), ChartIndex.values[j]);
      }
    } catch (e) {
      String message = 'Error $e when trying to convert $_filename!';
      log(message);
    }
  }
}
