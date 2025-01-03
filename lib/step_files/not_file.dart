import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ucsconvertertool/helpers/byte_helpers.dart';
import 'package:ucsconvertertool/step_files/andamiro_common.dart';

const int maxChanges = 10;
const int maxChangesNOT4 = 3;
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

const List<int> not4Key = [
  0xd2,
  0x67,
  0xfc,
  0x91,
  0x26,
  0xbb,
  0x50,
  0xe5,
  0x7a,
  0x0f,
  0xa4,
  0x39,
  0xce,
  0x63,
  0xf8,
  0x8d,
  0x22,
  0xb7,
  0x4c,
  0xe1,
  0x76,
  0x0b,
  0xa0,
  0x35,
  0xca,
  0x5f,
  0xf4,
  0x89,
  0x1e,
  0xb3,
  0x48,
  0xdd,
  0x72,
  0x07,
  0x9c,
  0x31,
  0xc6,
  0x5b,
  0xf0,
  0x85,
  0x1a,
  0xaf,
  0x44,
  0xd9,
  0x6e,
  0x03,
  0x98,
  0x2d,
  0xc2,
  0x57,
  0xec,
  0x81,
  0x16,
  0xab,
  0x40,
  0xd5,
  0x6a,
  0xff,
  0x94,
  0x29,
  0xbe,
  0x53,
  0xe8,
  0x7d,
  0x12,
  0xa7,
  0x3c,
  0xd1,
  0x66,
  0xfb,
  0x90,
  0x25,
  0xba,
  0x4f,
  0xe4,
  0x79,
  0x0e,
  0xa3,
  0x38,
  0xcd,
  0x62,
  0xf7,
  0x8c,
  0x21,
  0xb6,
  0x4b,
  0xe0,
  0x75,
  0x0a,
  0x9f,
  0x34,
  0xc9,
  0x5e,
  0xf3,
  0x88,
  0x1d,
  0xb2,
  0x47,
  0xdc,
  0x71,
  0x06,
  0x9b,
  0x30,
  0xc5,
  0x5a,
  0xef,
  0x84,
  0x19,
  0xae,
  0x43,
  0xd8,
  0x6d,
  0x02,
  0x97,
  0x2c,
  0xc1,
  0x56,
  0xeb,
  0x80,
  0x15,
  0xaa,
  0x3f,
  0xd4,
  0x69,
  0xfe,
  0x93,
  0x28,
  0xbd,
  0x52,
  0xe7,
  0x7c,
  0x11,
  0xa6,
  0x3b,
  0xd0,
  0x65,
  0xfa,
  0x8f,
  0x24,
  0xb9,
  0x4e,
  0xe3,
  0x78,
  0x0d,
  0xa2,
  0x37,
  0xcc,
  0x61,
  0xf6,
  0x8b,
  0x20,
  0xb5,
  0x4a,
  0xdf,
  0x74,
  0x09,
  0x9e,
  0x33,
  0xc8,
  0x5d,
  0xf2,
  0x87,
  0x1c,
  0xb1,
  0x46,
  0xdb,
  0x70,
  0x05,
  0x9a,
  0x2f,
  0xc4,
  0x59,
  0xee,
  0x83,
  0x18,
  0xad,
  0x42,
  0xd7,
  0x6c,
  0x01,
  0x96,
  0x2b,
  0xc0,
  0x55,
  0xea,
  0x7f,
  0x14,
  0xa9,
  0x3e,
  0xd3,
  0x68,
  0xfd,
  0x92,
  0x27,
  0xbc,
  0x51,
  0xe6,
  0x7b,
  0x10,
  0xa5,
  0x3a,
  0xcf,
  0x64,
  0xf9,
  0x8e,
  0x23,
  0xb8,
  0x4d,
  0xe2,
  0x77,
  0x0c,
  0xa1,
  0x36,
  0xcb,
  0x60,
  0xf5,
  0x8a,
  0x1f,
  0xb4,
  0x49,
  0xde,
  0x73,
  0x08,
  0x9d,
  0x32,
  0xc7,
  0x5c,
  0xf1,
  0x86,
  0x1b,
  0xb0,
  0x45,
  0xda,
  0x6f,
  0x04,
  0x99,
  0x2e,
  0xc3,
  0x58,
  0xed,
  0x82,
  0x17,
  0xac,
  0x41,
  0xd6,
  0x6b,
  0x00,
  0x95,
  0x2a,
  0xbf,
  0x54,
  0xe9,
  0x7e,
  0x13,
  0xa8,
  0x3d,
];

class NotFile {
  final String _filename;
  final List<double> _bpms = List.filled(maxChanges, 0);
  final List<int> _startTimes = List.filled(maxChanges, 0);
  final List<int> _bunkis = List.filled(maxChanges, 0);
  int _beatSplit = 0;
  int _beatsPerMeasure = -1;
  final List<AndamiroStepLine> _lines = [];
  bool _isNot5 = true;

  String get getFilename {
    return _filename;
  }

  List<double> get getBpms {
    return _bpms;
  }

  List<int> get getStartTimes {
    return _startTimes;
  }

  List<int> get getBunkis {
    return _bunkis;
  }

  int get getBeatSplit {
    return _beatSplit;
  }

  int get getBeatsPerMeasure {
    return _beatsPerMeasure;
  }

  List<AndamiroStepLine> get getLines {
    return _lines;
  }

  bool get isNot5 {
    return _isNot5;
  }

  NotFile(this._filename);

  Future<void> intialize() async {
    var notFile = File(_filename);

    try {
      var contents = await notFile.readAsBytes();

      //Check header
      assert(contents.length > 8,
          'Header invalid because file is smaller than header!');

      if (!listEquals(not5Begin, contents.sublist(0, 8))) {
        _intializeNOT4(contents);
      } else {
        _intializeNOT5(contents);
      }
    } catch (e) {
      String message = 'Error $e when trying to convert $_filename!';
      log(message);
    }
  }

  Future<void> _intializeNOT4(Uint8List contents) async {
    try {
      _isNot5 = false;

      int fileIndex = 0;

      //Skip number of steps
      fileIndex = 4;

      //Jump to bpm, starttime, and bunki section
      fileIndex += 4;

      for (int i = 0; i < maxChangesNOT4; i++) {
        double bpm;
        (fileIndex, bpm) = readFloat32BytesFromByteList(fileIndex, contents);
        _bpms[i] = bpm;
      }

      //Go to start time section
      fileIndex += 4;

      for (int i = 0; i < maxChangesNOT4; i++) {
        int startTime;
        (fileIndex, startTime) =
            readUint32BytesFromByteList(fileIndex, contents);
        _startTimes[i] = startTime;
      }

      //Jump to bunki section
      fileIndex += 4;

      //Only 2 bunkis allowed
      for (int i = 0; i < maxChangesNOT4 - 1; i++) {
        int bunki;
        (fileIndex, bunki) = readUint32BytesFromByteList(fileIndex, contents);
        _bunkis[i] = bunki;
      }

      //Go to beat split
      fileIndex += 8;

      int beatsplit;
      (fileIndex, beatsplit) = readUint32BytesFromByteList(fileIndex, contents);
      _beatSplit = beatsplit;

      int beatsPerMeasure;
      (fileIndex, beatsPerMeasure) =
          readUint32BytesFromByteList(fileIndex, contents);
      if (beatsPerMeasure == 0) {
        beatsPerMeasure = 4; //Default to 4 if nothing is specified
      }
      _beatsPerMeasure = beatsPerMeasure;

      //Skip track number because it is irrelevant
      fileIndex += 4;

      //Skip title
      fileIndex += 4;

      //Go to this index, since that is where the step data actually begins
      fileIndex = 0x84;

      int lineCount;
      //The line count is repeated 2x for doubles charts within the next 4 bytesd, we need only 1 of the numbers, so erase the second count
      var lineCountList = contents.sublist(fileIndex, fileIndex + 4);
      //make second set of integers 0 to ensure the read int function works properly
      lineCountList[2] = lineCountList[3] = 0;
      fileIndex += 4;

      (_, lineCount) = readUint32BytesFromByteList(0, lineCountList);

      //We need to get the decoded step data, we use the line count to fill in the very end of the chart
      //Since the decrypted data only goes to the very last step/lightmap

      //Get the decrypted data
      var stepArray = decrypt(contents.sublist(fileIndex));

      //var tempFile = File('$_filename.bin');
      //await tempFile.writeAsBytes(stepArray);

      int stepArrayIndex = 0;

      while (true) {
        //Sanity check
        if (stepArrayIndex + 4 > stepArray.length) {
          //stop here, because this last step is broken and incomplete so don't add it
          break;
        }

        //Get first and second byte to get the step index of this step
        //Set it up so our reader function will give correct result
        List<int> indexBytesList = List<int>.filled(4, 0);
        indexBytesList[0] = stepArray[stepArrayIndex];
        indexBytesList[1] = stepArray[stepArrayIndex + 1];

        int stepIndex;
        (_, stepIndex) = readUint32BytesFromByteList(0, indexBytesList);

        stepArrayIndex += 2;

        int currentNumberOfLines = _lines.length;
        int paddingLinesNeeded = stepIndex - currentNumberOfLines - 1;

        addPaddingLines(paddingLinesNeeded);

        //Now we look at the step data
        //Let's look at the two bytes that tell us what the step actually is
        AndamiroStepLine notLine = AndamiroStepLine();
        var stepLowerByte = stepArray[stepArrayIndex + 1];
        var stepHigherByte = stepArray[stepArrayIndex];

        //You need to do an operation to get a byte that shows if there is a step in each slot (looks like 111111111111100)
        var stepByte = (stepLowerByte << 8 | stepHigherByte);

        //Now we need to go through each bit for eachs tep of this step byte to mark if a step is in that position
        //We go from the right step of 2P all the way to left step of 1P, ignoring lightmap steps and the 3 bit padding on the right
        for (int j = 0; j < 10; j++) {
          int mask = 1 << (j + 6);
          bool stepPresent = (mask & stepByte) != 0;
          if (stepPresent) {
            //Since we are going right to left, insert in front of vector rather than adding to back
            notLine.notes.insert(0, AMNoteType.regular);
          } else {
            //Nothing here
            notLine.notes.insert(0, AMNoteType.none);
          }
        }

        _lines.add(notLine);
        stepArrayIndex += 2;
      }

      //Add padding lines to the end of the chart
      int paddingLinesNeeded = lineCount - _lines.length;
      addPaddingLines(paddingLinesNeeded);
    } catch (e) {
      String message = 'Error $e when trying to convert $_filename!';
      log(message);
    }
  }

  Future<void> _intializeNOT5(Uint8List contents) async {
    try {
      int fileIndex = 0;

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
      if (beatsPerMeasure == 0) {
        beatsPerMeasure = 4; //Default to 4 if nothing is specified
      }
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
        AndamiroStepLine notLine = AndamiroStepLine();
        var stepLowerByte = stepArray[i * 2 + 1];
        var stepHigherByte = stepArray[i * 2];
        var holdBeginLowerByte = holdBeginArray[i * 2 + 1];
        var holdBeginHigherByte = holdBeginArray[i * 2];
        var holdEndLowerByte = holdEndArray[i * 2 + 1];
        var holdEndHigherByte = holdEndArray[i * 2];

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
          if (stepPresent) {
            bool holdBeginPresent = (mask & holdBeginByte) != 0;
            bool holdEndPresent = (mask & holdEndByte) != 0;

            //Sanity check, exception if more than one of these conditions is true since that means chart is malformed
            if (holdBeginPresent && holdEndPresent) {
              throw ("A step cannot be a hold begin or a hold end at the same time. Chart is malformed!");
            }

            //Since we are going right to left, insert in front of vector rather than adding to back
            if (holdBeginPresent) {
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
              //Just a regular note
              notLine.notes.insert(0, AMNoteType.regular);
            }
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

  List<int> decrypt(Uint8List stepData) {
    List<int> decryptedData = List.filled(stepData.length, 0);

    for (int i = 0; i < stepData.length; i++) {
      var dataByte = stepData[i];
      var decryptedByte = dataByte ^ not4Key[i % not4Key.length];

      decryptedData[i] = decryptedByte;
    }

    return decryptedData;
  }

  void addPaddingLines(int paddingLinesNeeded) {
    for (int i = 0; i < paddingLinesNeeded; i++) {
      AndamiroStepLine notLine = AndamiroStepLine();

      //Add 10 empty steps because lines are always of length 10 for NOT files
      for (int j = 0; j < 10; j++) {
        notLine.notes.add(AMNoteType.none);
      }
      _lines.add(notLine);
    }
  }
}
