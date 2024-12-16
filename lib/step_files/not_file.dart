import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ucsconvertertool/helpers/byte_helpers.dart';
import 'package:ucsconvertertool/step_files/andamiro_common.dart';

const int maxChanges = 10;
const List<int> not5Begin = [
  0X70,
  0X75,
  0X6D,
  0X70,
  0X20,
  0X35,
  0X2E,
  0X30
]; //"pump 5.0"

class NotLine {
  List<AMNoteType> notes = [];
}

class Not5File {
  final String _filename;
  final List<double> _bpms = List.filled(maxChanges, -1);
  final List<int> _startTimes = List.filled(maxChanges, -1);
  final List<int> _bunkis = List.filled(maxChanges, -1);
  int _beatSplit = 0;
  int _beatsPerMeasure = -1;
  List<NotLine> _lines = [];

  String get getFilename {
    return _filename;
  }

  Not5File(this._filename);

  Future<void> intialize() async {
    var notFile = File(_filename);

    try {
      var contents = await notFile.readAsBytes();

      //Check header
      assert(contents.length > 8,
          'Header invalid because file is smaller than header!');

      int fileIndex = 0;

      if (!listEquals(not5Begin, contents.sublist(0, 8))) {
        throw const FormatException('STX Header mismatch!');
      }

      fileIndex = 8;

      //Jump to line count
      fileIndex += 2;

      int lineCount;
      (fileIndex, lineCount) = readUint32BytesFromByteList(fileIndex, contents);

      //Jump to bpm, starttime, and bunki section
      fileIndex += 2;

      for (int i = 0; i < maxChanges; i++) {
        double bpm;
        (fileIndex, bpm) = readFloat32BytesFromByteList(fileIndex, contents);
        _bpms[i] = bpm;
      }

      for (int i = 0; i < maxChanges; i++) {
        int startTime;
        (fileIndex, startTime) =
            readUint32BytesFromByteList(fileIndex, contents);
        _startTimes[i] = startTime;
      }

      for (int i = 0; i < maxChanges; i++) {
        int bunki;
        (fileIndex, bunki) = readUint32BytesFromByteList(fileIndex, contents);
        _bunkis[i] = bunki;
      }

      int beatsplit;
      (fileIndex, beatsplit) = readUint32BytesFromByteList(fileIndex, contents);
      _beatSplit = beatsplit;

      int beatsPerMeasure;
      (fileIndex, beatsPerMeasure) =
          readUint32BytesFromByteList(fileIndex, contents);
      _beatsPerMeasure = beatsPerMeasure;

      //Go to this index, since that is where the step data actually begins
      fileIndex = 0xD8;

      //Used to keep track of what is holding and what is not
      List<bool> isHolding = List.filled(10, false);

      //There are 3 step data areas (one for regular steps, one for hold begins, one for hold ends)
      //We need go through all of them to fill in the line of each NOT
      //The step data consists of 2 bytes per line
      var stepArray = contents.sublist(fileIndex, fileIndex + (lineCount * 2));
      fileIndex += lineCount * 2;
      var holdBeginArray =
          contents.sublist(fileIndex, fileIndex + (lineCount * 2));
      fileIndex += lineCount * 2;
      var holdEndArray =
          contents.sublist(fileIndex, fileIndex + (lineCount * 2));
      fileIndex += lineCount * 2;

      for (int i = 0; i < lineCount; i++) {
        NotLine notLine = NotLine();
        var stepLowerByte = stepArray[i * 2];
        var stepHigherByte = stepArray[i * 2 + 1];
        var holdBeginLowerByte = holdBeginArray[i * 2];
        var holdBeginHigherByte = holdBeginArray[i * 2 + 1];
        var holdEndLowerByte = holdEndArray[i * 2];
        var holdEndHigherByte = holdEndArray[i * 2 + 1];

        //You need to do an operation to get a byte that shows if there is a step in each slot (looks like 1111111111)
        var stepByte = ((stepLowerByte & 3) << 8 | stepHigherByte);
        var holdBeginByte =
            ((holdBeginLowerByte & 3) << 8 | holdBeginHigherByte);
        var holdEndByte = ((holdEndLowerByte & 3) << 8 | holdEndHigherByte);

        //Now we need to go through each bit of this step byte to mark if it is a regular note
        //We go from the right step of 2P all the way to left step of 1P
        for (int j = 0; j < 10; j++) {
          int mask = 1 << j;
          bool stepPresent = (mask & stepByte) != 0;
          bool holdBeginPresent = (mask & holdBeginByte) != 0;
          bool holdEndPresent = (mask & holdEndByte) != 0;

          //Sanity check, exception if more than one of these conditions is true since that means chart is malformed
          int typesPresent = 0;
          if (stepPresent) {
            typesPresent++;
          }
          if (holdBeginPresent) {
            typesPresent++;
          }
          if (holdEndPresent) {
            typesPresent++;
          }

          if (typesPresent > 1) {
            throw ("A step cannot be a regular step, a hold begin, or a hold end or a combination of any of these at the same time. Chart is malformed!");
          }

          //Since we are going right to left, insert in front of vector rather than adding to back
          if (stepPresent) {
            if (isHolding[9 - j]) {
              throw ("Regular note in the middle of a hold, chart is malformed!");
            }
            //There is a step present, insert regular note
            notLine.notes.insert(0, AMNoteType.regular);
          } else if (holdBeginPresent) {
            if (isHolding[9 - j]) {
              throw ("A hold begin note is attempted to be added when the hold hasn't ended, chart is malformed!");
            }
            isHolding[9 - j] = true;
            notLine.notes.insert(0, AMNoteType.holdBegin);
          } else if (holdEndPresent) {
            if (!isHolding[9 - j]) {
              throw ("A hold end note is attempted to be added when there is no hold, chart is malformed!");
            }
            isHolding[9 - j] = false;
            notLine.notes.insert(0, AMNoteType.holdEnd);
          } else if (isHolding[9 - j]) {
            //We are in middle of hold
            notLine.notes.insert(0, AMNoteType.hold);
          } else {
            //Nothing here
            notLine.notes.insert(0, AMNoteType.none);
          }
        }

        _lines.add(notLine);
      }
    } catch (e) {
      String message = 'Error $e when trying to convert $_filename!';
      log(message);
    }
  }
}
